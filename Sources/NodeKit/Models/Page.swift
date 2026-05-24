//
//  Page.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

/// A window of items inside a larger collection. Used by ``TemplateRegistry``
/// to expose paginated views over the registered template catalog so a browser
/// UI can render only what's on screen.
///
/// `Page` is generic so the same pagination shape applies to anything you want
/// to surface alongside templates (e.g. future remote catalogs). It is
/// `Sendable` whenever `T` is `Sendable`.
public struct Page<T> {
    /// The items in this page, in display order.
    public let items: [T]

    /// Zero-based position of this page in the overall sequence.
    public let index: Int

    /// Total number of items across all pages — *not* the total number of
    /// pages. Useful for "page N of M" UI and for reserving placeholder space.
    public let total: Int

    /// Create a page snapshot.
    public init(items: [T], index: Int, total: Int) {
        self.items = items
        self.index = index
        self.total = total
    }
}

extension Page: Sendable where T: Sendable {}
