//
//  EdgeRef.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import CoreGraphics
import Foundation

/// Stable identity for a single connection — both endpoints as `Node.PortReference`
/// so the edge survives the same template being instantiated more than once.
struct EdgeRef: Hashable, Sendable {
    let source: Node.PortReference
    let target: Node.PortReference
}

/// An edge resolved to canvas-space endpoints, ready to render or hit-test.
struct ResolvedEdge {
    let ref: EdgeRef
    let source: CGPoint
    let target: CGPoint
}

extension Graph {
    /// Walk every node's outgoing entries and project them onto live port anchors.
    /// Anchors come from `PortAnchorPreferenceKey`, so an edge is only resolvable
    /// once both endpoints have laid out at least once.
    func resolvedEdges(anchors: [Node.PortReference: PortAnchor]) -> [ResolvedEdge] {
        var out: [ResolvedEdge] = []
        for node in nodes {
            for (sourcePortID, targets) in node.outgoingConnectionsByPortIdentifier {
                let sourceRef = Node.PortReference(nodeIdentifier: node.id, portIdentifier: sourcePortID)
                guard let sourceAnchor = anchors[sourceRef], sourceAnchor.kind.isOutput else { continue }
                for target in targets {
                    guard let targetAnchor = anchors[target] else { continue }
                    out.append(ResolvedEdge(
                        ref: EdgeRef(source: sourceRef, target: target),
                        source: sourceAnchor.center,
                        target: targetAnchor.center
                    ))
                }
            }
        }
        return out
    }
}
