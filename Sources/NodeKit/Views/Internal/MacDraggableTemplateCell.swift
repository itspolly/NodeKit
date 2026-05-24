//
//  MacDraggableTemplateCell.swift
//  NodeKit
//
//  Created by Jamie on 24/05/2026.
//

#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// macOS-only template-browser cell. Hosts the SwiftUI `TemplateThumbnail`
/// inside an `NSView` that owns `mouseDown` → `mouseDragged` →
/// `beginDraggingSession`, completely bypassing SwiftUI's `.draggable`
/// bridge into AppKit.
///
/// Why: the SwiftUI drag bridge on macOS 26 produces a drop-replay bug
/// (identical-Y-to-seven-decimals phantom-duplicate-drop on the canvas).
/// Going direct on the *destination* side (see ``MacGraphDropTarget``)
/// didn't fix it — the bug rides through any code path that originates a
/// drag from a `.draggable`, so the source has to come off the bridge too.
/// Together, source + destination going `NSView`-direct give us
/// `beginDraggingSession`, `performDragOperation`, and `concludeDragOperation`
/// all in our hands, with no SwiftUI translation layer between them.
///
/// The drag image is drawn in Core Graphics rather than snapshotted from a
/// SwiftUI view — SwiftUI snapshots in isolated drag-preview contexts have
/// been a separate source of trouble (materials snapshot blank, async
/// layout, etc.).
struct MacDraggableTemplateCell: NSViewRepresentable {
    let template: NodeTemplate

    func makeNSView(context: Context) -> NSView {
        let container = DragSourceView()
        container.template = template

        let hosting = NSHostingView(rootView: TemplateThumbnail(template: template))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? DragSourceView else { return }
        container.template = template
        if let hosting = container.subviews.first as? NSHostingView<TemplateThumbnail> {
            hosting.rootView = TemplateThumbnail(template: template)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? {
        // Defer to the hosted SwiftUI view's preferred size so the cell still
        // sits naturally in the surrounding LazyVGrid.
        guard let hosting = nsView.subviews.first as? NSHostingView<TemplateThumbnail> else { return nil }
        return hosting.intrinsicContentSize
    }

    final class DragSourceView: NSView, NSDraggingSource {
        var template: NodeTemplate?
        /// The mouseDown that started the potential drag. Cleared on
        /// `mouseUp` (it was a tap, not a drag) or when the drag actually
        /// begins.
        private var mouseDownEvent: NSEvent?
        /// Minimum cursor travel before a `mouseDragged` is treated as a
        /// drag start. AppKit's `NSEvent.shouldDraggingClass` and similar
        /// give roughly this default; pinning it explicitly avoids spurious
        /// drags from a jittery click.
        private static let dragSlop: CGFloat = 3

        override var isFlipped: Bool { true }
        override var intrinsicContentSize: NSSize {
            subviews.first?.intrinsicContentSize ??
                NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = mouseDownEvent, let template else { return }
            let dx = abs(event.locationInWindow.x - start.locationInWindow.x)
            let dy = abs(event.locationInWindow.y - start.locationInWindow.y)
            guard max(dx, dy) >= Self.dragSlop else { return }
            mouseDownEvent = nil
            beginDrag(template: template, downEvent: start)
        }

        override func mouseUp(with event: NSEvent) {
            mouseDownEvent = nil
        }

        // MARK: - Drag initiation

        private func beginDrag(template: NodeTemplate, downEvent: NSEvent) {
            guard let data = try? JSONEncoder().encode(TemplateDragPayload(templateKindID: template.kind.id)) else { return }

            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setData(
                data,
                forType: NSPasteboard.PasteboardType(UTType.nodeKitTemplate.identifier)
            )

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let image = Self.makeDragImage(for: template)
            // Position the image so the cursor sits roughly in its middle —
            // matches how `.draggable`'s default preview hovers under the
            // cursor.
            let origin = NSPoint(
                x: convert(downEvent.locationInWindow, from: nil).x - image.size.width / 2,
                y: convert(downEvent.locationInWindow, from: nil).y - image.size.height / 2
            )
            draggingItem.setDraggingFrame(
                NSRect(origin: origin, size: image.size),
                contents: image
            )

            beginDraggingSession(with: [draggingItem], event: downEvent, source: self)
        }

        private static func makeDragImage(for template: NodeTemplate) -> NSImage {
            let label = template.kind.localizedDisplayName
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let text = NSAttributedString(string: label, attributes: textAttrs)
            let textSize = text.size()
            let padding = NSSize(width: 28, height: 18)
            let imageSize = NSSize(
                width: ceil(textSize.width + padding.width * 2),
                height: ceil(textSize.height + padding.height)
            )

            let image = NSImage(size: imageSize)
            image.lockFocus()
            defer { image.unlockFocus() }

            NSColor.controlAccentColor.setFill()
            let path = NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: imageSize),
                xRadius: 10,
                yRadius: 10
            )
            path.fill()

            text.draw(at: NSPoint(
                x: padding.width,
                y: (imageSize.height - textSize.height) / 2
            ))
            return image
        }

        // MARK: - NSDraggingSource

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            .copy
        }
    }
}
#endif
