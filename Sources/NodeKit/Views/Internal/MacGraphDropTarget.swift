//
//  MacGraphDropTarget.swift
//  NodeKit
//
//  Created by Jamie on 24/05/2026.
//

#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// macOS drop target for the graph canvas, used in place of SwiftUI's
/// `.dropDestination(for:)` Transferable bridge.
///
/// Why: on macOS the SwiftUI drop bridge — and the underlying `.onDrop`
/// path — exhibits a drop-replay bug where, after a real drop, AppKit
/// re-fires the drop event with the cached drop location and a freshly
/// sampled cursor X (identical-Y-to-seven-decimals signature), producing
/// a phantom duplicate node. We've ruled out every clean SwiftUI-level
/// workaround (deferred state mutation, stable cell identity, minimal
/// preview snapshot, `ProxyRepresentation`, removing hover-triggered
/// view invalidation). Going direct to `NSView.draggingDestination` lets
/// us own `performDragOperation` / `concludeDragOperation`, which is the
/// point at which AppKit decides whether to replay — and our explicit
/// teardown puts a stop to it.
///
/// The view is intentionally transparent to mouse events (`hitTest`
/// returns `nil`); only drag dispatch reaches it, via
/// `registerForDraggedTypes`.
struct MacGraphDropTarget: NSViewRepresentable {
    let onDrop: ([TemplateDragPayload], CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = DropView()
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? DropView)?.onDrop = onDrop
    }

    final class DropView: NSView {
        var onDrop: (([TemplateDragPayload], CGPoint) -> Void)?

        // Flip to SwiftUI's top-left origin so we can pass cursor points
        // straight into `GraphEditorState.canvasPoint(fromScreen:)` without
        // a manual flip per drop.
        override var isFlipped: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            registerForDraggedTypes([
                NSPasteboard.PasteboardType(UTType.nodeKitTemplate.identifier)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("not implemented")
        }

        // Transparent to mouse events — `nil` from `hitTest` lets clicks fall
        // through to the SwiftUI canvas beneath. Drag dispatch uses
        // `registerForDraggedTypes` and is unaffected by `hitTest`.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            .copy
        }

        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            .copy
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            let payloads = Self.decodePayloads(from: sender.draggingPasteboard)
            guard !payloads.isEmpty else { return false }
            let local = convert(sender.draggingLocation, from: nil)
            onDrop?(payloads, local)
            return true
        }

        private static func decodePayloads(from pasteboard: NSPasteboard) -> [TemplateDragPayload] {
            let typeID = NSPasteboard.PasteboardType(UTType.nodeKitTemplate.identifier)
            guard let items = pasteboard.pasteboardItems else { return [] }
            return items.compactMap { item in
                guard let data = item.data(forType: typeID),
                      let payload = try? JSONDecoder().decode(TemplateDragPayload.self, from: data)
                else { return nil }
                return payload
            }
        }
    }
}
#endif
