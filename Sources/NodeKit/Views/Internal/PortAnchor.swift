//
//  PortAnchor.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

struct PortAnchor: Equatable, Sendable {
    let nodeID: UUID
    let portID: UUID
    let kind: NodeTemplate.Port.Kind
    /// The port's ``PortType`` identifier. Stored as the bare string so the
    /// drag/hover hot path can do compatibility checks without a
    /// ``PortTypeRegistry`` round-trip — `canConnect` is just
    /// `lhs.typeIdentifier == rhs.typeIdentifier`.
    let typeIdentifier: String
    /// Center of the port hit-circle, in canvas coordinates.
    let center: CGPoint
    /// Ports with an inline value are excluded from hover-snapping and don't
    /// accept new edges. The owning view publishes this flag so callers don't
    /// need to peek into the graph to figure it out.
    let disabled: Bool

    var reference: Node.PortReference {
        Node.PortReference(nodeIdentifier: nodeID, portIdentifier: portID)
    }
}

struct PortAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [PortAnchor] = []
    static func reduce(value: inout [PortAnchor], nextValue: () -> [PortAnchor]) {
        value.append(contentsOf: nextValue())
    }
}
