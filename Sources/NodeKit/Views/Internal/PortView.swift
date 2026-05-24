//
//  PortView.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

struct PortView: View {
    let nodeID: UUID
    let port: NodeTemplate.Port
    let state: GraphEditorState
    @Binding var graph: Graph
    /// When true the port is non-interactive (no drag, dimmed). Set by the
    /// owning row when the port has an inline value driving it.
    let isDisabled: Bool

    private var reference: Node.PortReference {
        Node.PortReference(nodeIdentifier: nodeID, portIdentifier: port.id)
    }

    var body: some View {
        let isHovered = state.pendingConnection?.hover?.reference == reference
        let isSource = state.pendingConnection?.source == reference

        ZStack {
            Circle()
                .fill(.background.opacity(0.6))
                .overlay(
                    Circle().strokeBorder(
                        isHovered || isSource ? Color.accentColor : Color.primary.opacity(0.35),
                        lineWidth: isHovered || isSource ? 2.5 : 1
                    )
                )
                .overlay(
                    Circle().fill(Color.accentColor)
                        .padding(4)
                        .opacity(isHovered || isSource ? 1 : 0.0)
                )
                .frame(width: NodeStyle.portCircleSize, height: NodeStyle.portCircleSize)
                .shadow(color: .accentColor.opacity(isHovered ? 0.55 : 0), radius: 6)
                .contentShape(.circle.inset(by: -NodeStyle.portHitInset))
        }
        .opacity(isDisabled ? 0.35 : 1)
        .background(
            // Publish this port's center in canvas coordinates so the connection
            // layer and drag hit-testing can find it.
            GeometryReader { geo in
                let frame = geo.frame(in: .named(canvasCoordinateSpace))
                Color.clear.preference(
                    key: PortAnchorPreferenceKey.self,
                    value: [PortAnchor(
                        nodeID: nodeID,
                        portID: port.id,
                        kind: port.kind,
                        type: port.type,
                        center: CGPoint(x: frame.midX, y: frame.midY),
                        disabled: isDisabled
                    )]
                )
            }
        )
        .modifier(ConnectionDragModifier(
            gesture: connectionDrag(isInput: port.kind.isInput),
            enabled: !isDisabled
        ))
    }

    private func connectionDrag(isInput: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(canvasCoordinateSpace))
            .onChanged { value in
                // Port anchors publish on first layout pass so this is reliable;
                // start the drag from the pointer if for some reason the anchor
                // hasn't arrived yet (shouldn't happen in practice).
                let sourceCenter = state.portAnchors[reference]?.center ?? value.location

                if state.pendingConnection == nil {
                    state.pendingConnection = .init(
                        source: reference,
                        sourceKind: port.kind,
                        sourceCanvas: sourceCenter,
                        pointerCanvas: value.location,
                        hover: nil
                    )
                }
                state.pendingConnection?.pointerCanvas = value.location
                state.pendingConnection?.hover = nearestCompatiblePort(
                    to: value.location,
                    sourceKind: port.kind,
                    sourceType: port.type
                )
            }
            .onEnded { _ in
                guard let pending = state.pendingConnection else { return }
                if let hover = pending.hover {
                    let outputRef: Node.PortReference
                    let outputType: NodeTemplate.Port.PortType
                    let inputRef: Node.PortReference
                    let inputType: NodeTemplate.Port.PortType
                    if pending.sourceKind.isOutput {
                        outputRef = pending.source
                        outputType = port.type
                        inputRef = hover.reference
                        inputType = hover.type
                    } else {
                        outputRef = hover.reference
                        outputType = hover.type
                        inputRef = pending.source
                        inputType = port.type
                    }
                    // Belt-and-braces — hover filtering already rejects
                    // incompatible drops, but re-check on release in case
                    // anchors shifted mid-drag.
                    if outputType.canConnect(to: inputType) {
                        graph.connect(source: outputRef, target: inputRef)
                    }
                }
                state.pendingConnection = nil
            }
    }

    private func nearestCompatiblePort(
        to point: CGPoint,
        sourceKind: NodeTemplate.Port.Kind,
        sourceType: NodeTemplate.Port.PortType
    ) -> PortAnchor? {
        let needed: NodeTemplate.Port.Kind = sourceKind.isInput ? .output : .input
        let snap: CGFloat = 28
        var best: (PortAnchor, CGFloat)?
        for anchor in state.portAnchors.values
        where anchor.kind == needed && anchor.nodeID != nodeID && !anchor.disabled {
            let (outputType, inputType) = sourceKind.isOutput
                ? (sourceType, anchor.type)
                : (anchor.type, sourceType)
            guard outputType.canConnect(to: inputType) else { continue }
            let dx = anchor.center.x - point.x
            let dy = anchor.center.y - point.y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist <= snap, best.map({ dist < $0.1 }) ?? true {
                best = (anchor, dist)
            }
        }
        return best?.0
    }
}

/// Attaches the connection drag only when enabled. SwiftUI's `.gesture(_:)`
/// has no straightforward conditional form, so wrap in a modifier.
private struct ConnectionDragModifier<G: Gesture>: ViewModifier {
    let gesture: G
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(gesture)
        } else {
            content
        }
    }
}
