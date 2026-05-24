//
//  ConnectionsLayer.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

struct ConnectionsLayer: View {
    let graph: Graph
    let anchors: [Node.PortReference: PortAnchor]
    let pending: GraphEditorState.PendingConnection?
    let selectedEdges: Set<EdgeRef>

    var body: some View {
        Canvas { context, _ in
            for edge in graph.resolvedEdges(anchors: anchors) {
                let isSelected = selectedEdges.contains(edge.ref)
                let path = ConnectionPath.path(from: edge.source, to: edge.target)
                if isSelected {
                    // Soft halo behind the selected edge for a clear "this is the one" cue.
                    context.stroke(
                        path,
                        with: .color(.accentColor.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    context.stroke(
                        path,
                        with: .color(.accentColor),
                        style: StrokeStyle(lineWidth: 3.25, lineCap: .round)
                    )
                } else {
                    context.stroke(path, with: .linearGradient(
                        Gradient(colors: [.accentColor.opacity(0.85),
                                          .accentColor.opacity(0.55)]),
                        startPoint: edge.source,
                        endPoint: edge.target
                    ), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }

            if let pending = pending {
                let from: CGPoint
                let to: CGPoint
                if pending.sourceKind.isOutput {
                    from = pending.sourceCanvas
                    to = pending.hover?.center ?? pending.pointerCanvas
                } else {
                    from = pending.hover?.center ?? pending.pointerCanvas
                    to = pending.sourceCanvas
                }
                let path = ConnectionPath.path(from: from, to: to)
                let dashed = StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 6])
                let valid = pending.hover != nil
                context.stroke(
                    path,
                    with: .color(valid ? .accentColor : .accentColor.opacity(0.55)),
                    style: valid ? StrokeStyle(lineWidth: 2.5, lineCap: .round) : dashed
                )
            }
        }
        .allowsHitTesting(false)
    }
}
