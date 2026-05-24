//
//  MissingTemplateNodeView.swift
//  NodeKit
//
//  Created by Jamie on 24/05/2026.
//

import SwiftUI

/// Placeholder for a ``Node`` whose ``Node/templateIdentifier`` doesn't
/// resolve in the editor's ``TemplateRegistry``.
///
/// Graceful-degradation rendering: when a plugin's templates aren't loaded
/// (or have been unregistered) the affected nodes still exist in the
/// graph and shouldn't disappear from the user's view — that would leave
/// the user with no way to inspect, move, or delete them. This view shows
/// a dimmed card carrying the unresolved identifier so they're visible
/// and recoverable. The card is selectable and movable like a normal node
/// but has no ports (we don't know the template's port shape), so no new
/// edges can be drawn to or from it. Existing edges to ports on this
/// node also can't render (the connection layer needs port anchors,
/// which only normal ``NodeView`` publishes).
///
/// If the missing template is later registered with the same
/// ``NodeTemplate/Kind/id``, the node falls back into normal
/// ``NodeView`` rendering and any latent edges reappear intact.
struct MissingTemplateNodeView: View {
    let node: Node
    let state: GraphEditorState
    @Binding var graph: Graph
    let onTap: () -> Void

    private var isSelected: Bool { state.selection.contains(node.id) }

    var body: some View {
        cardContent
            .frame(minWidth: NodeStyle.minWidth, alignment: .leading)
            .fixedSize(horizontal: true, vertical: true)
            .background(framePublisher)
            .position(x: node.position.cgPoint.x, y: node.position.cgPoint.y)
    }

    private var framePublisher: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named(canvasCoordinateSpace))
            Color.clear.preference(
                key: NodeFramePreferenceKey.self,
                value: [node.id: frame]
            )
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.square.dashed")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Missing template")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(node.templateIdentifier.uuidString)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous)
                .fill(.background.tertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.18),
                    style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: [4, 3])
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .opacity(0.7)
        .contentShape(RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
        .onTapGesture { onTap() }
        .gesture(moveGesture)
    }

    // MARK: - Move gesture

    /// Mirror of `NodeView.moveGesture` so missing-template placeholders are
    /// movable the same way a real node is. Kept locally rather than
    /// shared to keep `NodeView` ignorant of the placeholder case.
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(canvasCoordinateSpace))
            .onChanged { value in
                if !state.nodeDragInProgress {
                    if !state.selection.contains(node.id) {
                        state.selection = [node.id]
                    }
                    state.nodeDragInProgress = true
                    state.nodeDragStart = Dictionary(
                        uniqueKeysWithValues: graph.nodes
                            .filter { state.selection.contains($0.id) }
                            .map { ($0.id, $0.position.cgPoint) }
                    )
                }
                state.nodeDragOffset = value.translation
                applyDragOffset()
            }
            .onEnded { _ in
                state.nodeDragInProgress = false
                state.nodeDragOffset = .zero
                state.nodeDragStart = [:]
            }
    }

    private func applyDragOffset() {
        for (id, start) in state.nodeDragStart {
            if let i = graph.nodes.firstIndex(where: { $0.id == id }) {
                graph.nodes[i].position = Point(
                    x: Double(start.x + state.nodeDragOffset.width),
                    y: Double(start.y + state.nodeDragOffset.height)
                )
            }
        }
    }
}
