//
//  TemplateRegistryView.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

/// Beautiful template browser backed by `TemplateRegistry`. Pages are rendered
/// as discrete sections in a `LazyVStack`; each section publishes its visibility
/// via `.onAppear` / `.onDisappear`, and the view keeps the registry's loaded
/// window pinned to whichever pages are currently on screen. Scrolling beyond
/// the loaded edge reveals a placeholder section with a `ProgressView` while
/// the next page streams in; scrolling back up evicts what's no longer visible
/// and re-loads from the top with the same indicator.
public struct TemplateRegistryView: View {
    var templateRegistry: TemplateRegistry
    @Binding var predicate: TemplatePredicate

    @State private var visiblePages: Set<Int> = []
    @State private var loadTask: Task<Void, Never>?
    @State private var loading = false
    @State private var dirty = false

    public init(
        templateRegistry: TemplateRegistry,
        predicate: Binding<TemplatePredicate>
    ) {
        self.templateRegistry = templateRegistry
        self._predicate = predicate
    }

    public var body: some View {
        scroll
            .background(.background.tertiary)
            .task { await loadCurrentWindow() }
            .onChange(of: visiblePages) { _, _ in scheduleReload() }
            .onChange(of: predicate) { _, _ in scheduleReload() }
            .onDisappear { cancelLoad() }
    }

    private var scroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var content: some View {
        if templateRegistry.totalPages == 0 {
            emptyState
        } else {
            ForEach(0..<templateRegistry.totalPages, id: \.self) { index in
                pageSection(index: index)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func pageSection(index: Int) -> some View {
        let page = templateRegistry.loadedTemplates.first { $0.index == index }
        Group {
            if let page {
                // Column min matches `NodeStyle.minWidth` so thumbnails never
                // overflow their cell. Inter-column spacing of 28 (rather than
                // 14) leaves room for the port circles that hang ~13pt outside
                // the thumbnail's layout bounds on each side.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: NodeStyle.minWidth), spacing: 28)],
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(page.items, id: \.kind.id) { template in
                        TemplateCell(template: template)
                    }
                }
            } else {
                placeholder(itemCount: templateRegistry.itemCount(inPageAt: index))
            }
        }
        .onAppear { visiblePages.insert(index) }
        .onDisappear { visiblePages.remove(index) }
    }


    @ViewBuilder
    private func placeholder(itemCount: Int) -> some View {
        // Reserve roughly the height the loaded grid will occupy so the
        // LazyVStack's content size — and therefore scroll position — stays
        // stable as pages stream in and out. Two-column estimate matches the
        // narrowest typical layout; on wider screens the actual height is
        // slightly less and the surrounding sections take up the slack.
        let cellHeight: CGFloat = 110
        let spacing: CGFloat = 14
        let estimatedColumns = 2
        let rows = max(1, (itemCount + estimatedColumns - 1) / estimatedColumns)
        let height = CGFloat(rows) * cellHeight + CGFloat(max(0, rows - 1)) * spacing
        ZStack {
            Color.clear
            ProgressView()
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .glassEffect(.regular.tint(.clear),
                     in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(0.6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No templates")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    // MARK: - Loading

    /// Schedule a debounced reload. Called from every trigger that might
    /// require new templates to be fetched: the visible-pages set flapping
    /// during a fast scroll, the predicate changing, or the registry's store
    /// mutating (e.g. plugins registering a batch of templates).
    ///
    /// Using a single debounced funnel instead of `.task(id:)` on a composite
    /// key matters: SwiftUI's `.task(id:)` cancels and re-launches on every
    /// key change, so a synchronous batch of `register` calls would re-key the
    /// task N times — the in-flight body gets cancelled before `loadTemplates`
    /// can set `totalCount`, and the view sticks on its empty state. A
    /// debounced trailing call collapses the burst into one real load.
    private func scheduleReload() {
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(for: .milliseconds(40))
            if Task.isCancelled { return }
            await loadCurrentWindow()
        }
    }

    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func loadCurrentWindow() async {
        guard !loading else {
            dirty = true
            return
        }
        
        loading = true
        
        if let lower = visiblePages.min(), let upper = visiblePages.max() {
            await templateRegistry.loadTemplates(matching: predicate, pages: lower...upper)
        } else {
            await templateRegistry.loadTemplates(matching: predicate, pages: 0...0)
        }
        
        loading = false
        
        if dirty {
            dirty = false
            await loadCurrentWindow()
        }
    }
}

#if DEBUG
@MainActor
private enum TemplateBrowserPreviewSeed {
    // Split into chunks: the previews compiler wraps every literal in a
    // `__designTimeString(...)` macro for hot-reload, and a single 18-element
    // string-literal array overwhelms the type checker.
    private static let nameChunks: [[String]] = [
        ["Source", "Filter", "Map"],
        ["Reduce", "Window", "Sink"],
        ["Branch", "Join", "Throttle"],
        ["Debounce", "Buffer", "Tap"],
        ["Merge", "Split", "Delay"],
        ["Replay", "Zip", "Combine"],
    ]

    static func make() -> TemplateRegistry {
        let registry = TemplateRegistry(pageSize: 6)
        for chunk in nameChunks {
            for name in chunk {
                registry.register(template: makeTemplate(named: name))
            }
        }
        return registry
    }

    private static func makeTemplate(named name: String) -> NodeTemplate {
        let inputs: [NodeTemplate.Port] = (name == "Source")
            ? []
            : [.init(id: UUID(), kind: .input, type: .double, localizedDisplayName: "in")]
        let outputs: [NodeTemplate.Port] = (name == "Sink")
            ? []
            : [.init(id: UUID(), kind: .output, type: .double, localizedDisplayName: "out")]
        return NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: name),
            inputs: inputs,
            outputs: outputs
        )
    }
}

private struct TemplateBrowserPreviewHost: View {
    @State private var predicate: TemplatePredicate = .filter(name: nil, scope: nil)
    private let registry: TemplateRegistry

    init() {
        registry = TemplateBrowserPreviewSeed.make()
    }

    var body: some View {
        TemplateRegistryView(templateRegistry: registry, predicate: $predicate)
    }
}

#Preview("Template Browser") {
    TemplateBrowserPreviewHost()
        .frame(width: 600, height: 560)
}
#endif
