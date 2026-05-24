//
//  GraphMutations.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import Foundation

extension Graph {
    mutating func move(nodeID: UUID, to position: Point) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        nodes[index].position = position
    }

    mutating func translate(nodeIDs: Set<UUID>, by delta: CGSize) {
        guard delta != .zero else { return }
        for index in nodes.indices where nodeIDs.contains(nodes[index].id) {
            let p = nodes[index].position
            nodes[index].position = Point(x: p.x + Double(delta.width),
                                          y: p.y + Double(delta.height))
        }
    }

    /// Connect `source` (an output port on some node) to `target` (an input
    /// port on a node — possibly the same or a different one). Stored on the
    /// source node so each edge has a single source-of-truth.
    mutating func connect(source: Node.PortReference, target: Node.PortReference) {
        guard let index = nodes.firstIndex(where: { $0.id == source.nodeIdentifier }) else { return }
        var entry = nodes[index].outgoingConnectionsByPortIdentifier[source.portIdentifier] ?? []
        if !entry.contains(target) {
            entry.append(target)
        }
        nodes[index].outgoingConnectionsByPortIdentifier[source.portIdentifier] = entry
    }

    mutating func disconnect(source: Node.PortReference, target: Node.PortReference) {
        guard let index = nodes.firstIndex(where: { $0.id == source.nodeIdentifier }) else { return }
        var entry = nodes[index].outgoingConnectionsByPortIdentifier[source.portIdentifier] ?? []
        entry.removeAll { $0 == target }
        if entry.isEmpty {
            nodes[index].outgoingConnectionsByPortIdentifier.removeValue(forKey: source.portIdentifier)
        } else {
            nodes[index].outgoingConnectionsByPortIdentifier[source.portIdentifier] = entry
        }
    }

    mutating func setPortValue(nodeID: UUID, portID: UUID, value: PortValue) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        nodes[index].portValues[portID] = value
    }

    mutating func removePortValue(nodeID: UUID, portID: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        nodes[index].portValues.removeValue(forKey: portID)
    }

    /// True if any node's outgoing list contains `target`. Targets are stored
    /// as `Node.PortReference` so this is a flat scan; cheap at current graph sizes
    /// and avoids maintaining a reverse index.
    func hasIncomingConnection(to target: Node.PortReference) -> Bool {
        for node in nodes {
            for refs in node.outgoingConnectionsByPortIdentifier.values {
                if refs.contains(target) { return true }
            }
        }
        return false
    }

    /// Delete the given nodes and prune any edges that referenced them. Since
    /// edges store the target node id directly, no caller-side port-id
    /// collection is needed.
    mutating func delete(nodeIDs deletedIDs: Set<UUID>) {
        nodes.removeAll { deletedIDs.contains($0.id) }
        for index in nodes.indices {
            var dict = nodes[index].outgoingConnectionsByPortIdentifier
            for (key, refs) in dict {
                let pruned = refs.filter { !deletedIDs.contains($0.nodeIdentifier) }
                if pruned.isEmpty {
                    dict.removeValue(forKey: key)
                } else if pruned.count != refs.count {
                    dict[key] = pruned
                }
            }
            nodes[index].outgoingConnectionsByPortIdentifier = dict
        }
    }
}
