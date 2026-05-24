//
//  TemplateRegistry.swift
//  NodeKit
//
//  Created by Jamie on 05/05/2026.
//

import Foundation

/// Owns the canonical set of node templates and exposes them as paginated
/// windows for browser UIs. Pagination is offset-based over a snapshot sorted
/// by `localizedDisplayName`; page indices are *not* stable across mutations,
/// only template identity (`kind.id`) is.
///
/// ## Behavior when the displayed pages change
///
/// `register` / `unregister` re-derive the ordering under the most recent
/// predicate and re-project every loaded page onto the new snapshot
/// (`refreshLoadedPagesAfterMutation`). Both ``totalCount`` and
/// ``loadedTemplates`` are `@Observable`, so any SwiftUI view that reads them
/// re-renders automatically — there is no separate "something changed" signal
/// to subscribe to. `ForEach` keys each cell by `kind.id`, so cells that
/// shifted position move, new ones fade in, removed ones fade out.
///
/// Page indices are positional, not durable: if a template registers that
/// sorts before the visible window, "page 5" now contains different items.
/// The view shows whatever is at the current visual position rather than
/// trying to track a content anchor — a future improvement could pin a
/// scroll-anchor `kind.id` and restore its visual position after mutations.
///
/// ## Concurrency and ordering
///
/// The registry is `@Observable` and isolated to `@MainActor`. `register`
/// and `unregister` are synchronous and, called from MainActor code, take
/// effect in call order — a synchronous loop produces deterministic,
/// sequential state.
///
/// Called from outside MainActor they need to be treated as asynchronous
/// (the call hops across actor isolation). If you issue registrations from
/// multiple async tasks, the MainActor schedules them but doesn't order
/// them by call site — await each call before issuing the next if you
/// need a specific sequence.
///
/// ## Path to a remote-backed registry
///
/// Today everything lives in memory. To back this with a remote source:
///
/// 1. **`loadTemplates(matching:pages:)` becomes a real I/O call.** The single
///    `await Task.yield()` is the seam — replace with the actual fetch and
///    respect `Task.isCancelled` so fast scrolling doesn't queue wasted work.
///
/// 2. **Switch from offset to cursor pagination.** Offset paging is cheap in
///    memory but expensive server-side (count + skip). Each `Page` would gain
///    `nextCursor`/`previousCursor`, and the load API keys off cursors instead
///    of integer page indices.
///
/// 3. **`totalCount` may be unknown or approximate.** Large remote stores
///    often won't report exact totals. The view then can't compute
///    `totalPages` upfront — switch to a "has-more" flag and append a sentinel
///    placeholder section that's swapped for real content as it loads.
///
/// 4. **`register` / `unregister` likely retire.** Local registration only
///    makes sense for tests or in-process plugins; with a server source the
///    canonical list lives upstream.
///
/// 5. **Multi-source coalescing.** `TemplatePredicate.Scope.Store` already
///    enumerates `project` / `installed` / `global` — each is a separate
///    paginated source. The registry merges them into one ordering at load
///    time, holding per-source cursors. This is the "expensive but
///    unavoidable" coalescing cost.
///
/// 6. **Server-side filtering.** `TemplatePredicate` should be sent as a
///    query parameter so we don't transfer non-matching items. Requires a
///    wire format (currently the enum is `Codable`-eligible but never
///    serialised).
///
/// 7. **First-class errors.** `loadTemplates` becomes `throws` (or grows a
///    `lastLoadFailure: Error?` property), and the view renders a retryable
///    error state instead of an indefinite spinner.
///
/// 8. **Long-lived change subscriptions.** For remote, subscribe to server
///    change events (websocket / SSE / etag polling) and mutate
///    ``loadedTemplates`` / ``totalCount`` when items are added or removed
///    upstream — the existing `@Observable` propagation picks it up in views.
@Observable
@MainActor
public class TemplateRegistry {
    public let pageSize: Int

    /// Total templates matching the most recently loaded predicate. `0` until
    /// `loadTemplates` has been called at least once. Observable: views that
    /// read this re-render when it changes (e.g. when `register` adds an item
    /// that passes the active predicate).
    public private(set) var totalCount: Int = 0

    /// The pages the registry is currently holding in memory. Mutated by
    /// `loadTemplates(matching:pages:)` *and* by `register` / `unregister`
    /// (which re-project the held window in place). Observable: views that
    /// read this re-render when it changes.
    public private(set) var loadedTemplates: [Page<NodeTemplate>] = []

    public var totalPages: Int {
        guard pageSize > 0 else { return 0 }
        return (totalCount + pageSize - 1) / pageSize
    }

    /// How many items the page at `index` would contain if loaded — useful for
    /// reserving placeholder space without instantiating the page.
    public func itemCount(inPageAt index: Int) -> Int {
        let start = index * pageSize
        let end = min(start + pageSize, totalCount)
        return max(0, end - start)
    }

    private var store: [UUID: NodeTemplate] = [:]
    private var orderedIDs: [UUID] = []
    private var lastPredicate: TemplatePredicate?

    public init(pageSize: Int = 12) {
        precondition(pageSize > 0, "pageSize must be positive")
        self.pageSize = pageSize
    }

    /// Add or replace a template. Re-derives the active ordering under the most
    /// recent predicate so ``totalCount`` and any currently-loaded pages stay
    /// consistent — observers re-render via `@Observable`.
    public func register(template: NodeTemplate) {
        store[template.kind.id] = template
        rebuildUnderLastPredicateIfPossible()
        refreshLoadedPagesAfterMutation()
    }

    /// Remove a template. Currently-loaded pages have the deleted entry pruned
    /// in place — observers re-render via `@Observable`.
    public func unregister(templateKindID: UUID) {
        guard store.removeValue(forKey: templateKindID) != nil else { return }
        rebuildUnderLastPredicateIfPossible()
        refreshLoadedPagesAfterMutation()
    }

    func download(remoteTemplateIdentifier: UUID) async {}

    /// Lookup by identity. Always works against the full store regardless of
    /// which pages are currently loaded — the editor uses this to resolve
    /// `Node.templateIdentifier` even when the browser has evicted the page
    /// containing that template.
    public func registeredNodeTemplate(with identifier: UUID) -> NodeTemplate? {
        store[identifier]
    }

    /// Ensure exactly the pages with indices in `range` are held in
    /// `loadedTemplates`. Pages outside `range` are evicted. If the predicate
    /// changed since the last call, the ordering snapshot is rebuilt first.
    ///
    /// The single `await Task.yield()` is the seam where a future remote-store
    /// implementation would actually wait on I/O.
    func loadTemplates(
        matching predicate: TemplatePredicate,
        pages range: ClosedRange<Int>
    ) async {
        rebuildOrderIfNeeded(matching: predicate)
        await Task.yield()
        // Bail if a newer reload superseded us across the yield, so an older
        // task's stale window can't briefly overwrite the newer task's freshly
        // loaded one.
        if Task.isCancelled { return }
        loadedTemplates = pages(in: range)
    }

    /// Convenience: load only page 0.
    func loadTemplates(matching predicate: TemplatePredicate) async {
        await loadTemplates(matching: predicate, pages: 0...0)
    }

    /// Drop a single page from `loadedTemplates`. Largely subsumed by
    /// `loadTemplates(matching:pages:)`; kept for explicit eviction.
    func evictPage(index: Int) {
        loadedTemplates.removeAll { $0.index == index }
    }

    // MARK: - Ordering

    private func rebuildOrderIfNeeded(matching predicate: TemplatePredicate) {
        if lastPredicate == predicate { return }
        rebuildOrder(matching: predicate)
    }

    private func rebuildUnderLastPredicateIfPossible() {
        guard let predicate = lastPredicate else { return }
        rebuildOrder(matching: predicate)
    }

    private func rebuildOrder(matching predicate: TemplatePredicate) {
        orderedIDs = store.values
            .filter { predicate.matches($0) }
            .sorted { lhs, rhs in
                let order = lhs.kind.localizedDisplayName.localizedCaseInsensitiveCompare(rhs.kind.localizedDisplayName)
                if order != .orderedSame { return order == .orderedAscending }
                return lhs.kind.id.uuidString < rhs.kind.id.uuidString
            }
            .map(\.kind.id)
        lastPredicate = predicate
        totalCount = orderedIDs.count
    }

    /// Re-project currently-loaded pages onto the (possibly mutated) snapshot.
    /// Keeps page indices the same — the same window of positions, with whatever
    /// templates currently occupy them. Empty windows are dropped.
    ///
    /// If no window is currently held *and* an initial `loadTemplates` has
    /// already established a predicate, adopt page 0 as the default window.
    /// Without this, a register that follows an empty initial load (the common
    /// shape: a view mounts, runs its initial load against an empty registry,
    /// then templates get registered) would leave `loadedTemplates` empty —
    /// the view would only refill it after a debounced reload triggered by
    /// the placeholder appearing, costing ~40ms during which the user sees
    /// "No templates".
    private func refreshLoadedPagesAfterMutation() {
        if loadedTemplates.isEmpty {
            guard lastPredicate != nil, let firstPage = page(at: 0) else { return }
            loadedTemplates = [firstPage]
            return
        }
        let indices = loadedTemplates.map(\.index)
        loadedTemplates = indices.compactMap { page(at: $0) }
    }

    private func pages(in range: ClosedRange<Int>) -> [Page<NodeTemplate>] {
        guard totalPages > 0 else { return [] }
        let lower = max(0, range.lowerBound)
        let upper = min(totalPages - 1, range.upperBound)
        guard lower <= upper else { return [] }
        return (lower...upper).compactMap { page(at: $0) }
    }

    private func page(at index: Int) -> Page<NodeTemplate>? {
        let start = index * pageSize
        guard start < orderedIDs.count else { return nil }
        let end = min(start + pageSize, orderedIDs.count)
        let items = orderedIDs[start..<end].compactMap { store[$0] }
        guard !items.isEmpty else { return nil }
        return Page(items: items, index: index, total: orderedIDs.count)
    }
}
