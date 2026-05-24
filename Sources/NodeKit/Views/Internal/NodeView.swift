//
//  NodeView.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

struct NodeView: View {
    let node: Node
    let template: NodeTemplate
    let isSelected: Bool
    let state: GraphEditorState
    @Binding var graph: Graph
    let onTap: () -> Void

    var body: some View {
        nodeContent
            .frame(minWidth: NodeStyle.minWidth, alignment: .leading)
            .fixedSize(horizontal: true, vertical: true)
            .background(framePublisher)
            .position(x: node.position.cgPoint.x, y: node.position.cgPoint.y)
    }

    /// Reads our actual laid-out frame in canvas coordinates and publishes it
    /// up to the preference machinery. Replaces the old NodeMetrics-based
    /// fixed-size calculation — the node now sizes to its content.
    private var framePublisher: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named(canvasCoordinateSpace))
            Color.clear.preference(
                key: NodeFramePreferenceKey.self,
                value: [node.id: frame]
            )
        }
    }

    private var nodeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(alignment: .top, spacing: 16) {
                portsColumn(template.inputs, alignment: .leading)
                Spacer(minLength: 24)
                portsColumn(template.outputs, alignment: .trailing)
            }
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
        .glassEffect(
            .regular.tint(isSelected ? Color.accentColor.opacity(0.18) : .clear),
            in: RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.18),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.28 : 0.18),
                radius: isSelected ? 18 : 12,
                x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
        .onTapGesture { onTap() }
        .gesture(moveGesture)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .shadow(color: .accentColor.opacity(0.7), radius: 4)
            Text(template.kind.localizedDisplayName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.55),
                         Color.accentColor.opacity(0.25)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    @ViewBuilder
    private func portsColumn(
        _ ports: [NodeTemplate.Port],
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            ForEach(ports) { port in
                portRow(port: port, alignment: alignment)
            }
        }
    }

    @ViewBuilder
    private func portRow(
        port: NodeTemplate.Port,
        alignment: HorizontalAlignment
    ) -> some View {
        let isLeft = (alignment == .leading)
        let isInput = (port.kind == .input)
        let inlineValue = isInput ? node.portValues[port.id] : nil
        let hasIncoming = isInput && graph.hasIncomingConnection(
            to: Node.PortReference(nodeIdentifier: node.id, portIdentifier: port.id)
        )
        let canInline = isInput
            && state.portEditorRegistry.hasInlineEditor(for: port.type.id)

        HStack(spacing: 8) {
            if !isLeft {
                Text(port.localizedDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            PortView(
                nodeID: node.id,
                port: port,
                state: state,
                graph: $graph,
                isDisabled: inlineValue != nil
            )
            if isLeft {
                Text(port.localizedDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if inlineValue != nil,
                   let editor = state.portEditorRegistry.editor(
                       for: port.type.id,
                       value: portValueBinding(for: port.id)
                   )
                {
                    editor
                    Button {
                        graph.removePortValue(nodeID: node.id, portID: port.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else if canInline {
                    Button {
                        if let initial = state.portEditorRegistry.defaultValue(for: port.type.id) {
                            graph.setPortValue(nodeID: node.id, portID: port.id, value: initial)
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(hasIncoming)
                    .opacity(hasIncoming ? 0.4 : 1)
                }
            }
        }
        .padding(.horizontal, 6)
        // Pin port circles so they hang half-outside the node edge.
        .offset(x: isLeft ? -NodeStyle.portCircleSize / 2 - 6
                          : NodeStyle.portCircleSize / 2 + 6)
    }

    /// Wraps `node.portValues[portID]` as a `Binding<PortValue>` for the
    /// registry's editor builder to write into. The `set` always routes
    /// through `setPortValue` so the graph stays the single source of truth.
    private func portValueBinding(for portID: UUID) -> Binding<PortValue> {
        Binding<PortValue>(
            get: { node.portValues[portID] ?? .bool(false) },
            set: { newValue in
                graph.setPortValue(nodeID: node.id, portID: portID, value: newValue)
            }
        )
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(canvasCoordinateSpace))
            .onChanged { value in
                if !state.nodeDragInProgress {
                    // Begin a node-move drag. If this node isn't selected, make it the
                    // sole selection so the drag affects exactly one node.
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

struct NodeFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
