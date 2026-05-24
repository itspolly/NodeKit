//
//  TemplateCell.swift
//  NodeKit
//
//  Created by Jamie on 24/05/2026.
//

import SwiftUI

/// One cell in the ``TemplateRegistryView`` browser.
///
/// On iOS / iPadOS / visionOS this is a SwiftUI `.draggable` view: the
/// platform's drag bridge works reliably there.
///
/// On macOS it routes through ``MacDraggableTemplateCell``, an
/// `NSViewRepresentable` that owns mouseDown → `beginDraggingSession`
/// directly. We had to take the source half off SwiftUI's drag bridge on
/// macOS to avoid the AppKit drop-replay bug (see
/// ``MacGraphDropTarget`` for the destination half of the same workaround).
struct TemplateCell: View {
    let template: NodeTemplate

    var body: some View {
        #if os(macOS)
        MacDraggableTemplateCell(template: template)
            .accessibilityLabel(Text(template.kind.localizedDisplayName))
        #else
        TemplateThumbnail(template: template)
            .contentShape(RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
            .draggable(TemplateDragPayload(templateKindID: template.kind.id)) {
                dragPreview
            }
            .accessibilityLabel(Text(template.kind.localizedDisplayName))
        #endif
    }

    #if !os(macOS)
    private var dragPreview: some View {
        Text(template.kind.localizedDisplayName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
            .fixedSize()
            .compositingGroup()
    }
    #endif
}
