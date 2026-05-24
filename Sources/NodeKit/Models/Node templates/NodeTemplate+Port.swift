//
//  Node+Port.swift
//  NodeKit
//
//  Created by Jamie on 05/05/2026.
//

import Foundation

public extension NodeTemplate {
    /// A single input or output declared by a ``NodeTemplate``.
    ///
    /// Ports carry an identity, a direction (``Kind``), a value type
    /// (``PortType``), and a localized display name shown alongside the
    /// port in the node body. Identities are template-scoped — see
    /// ``NodeTemplate`` — so edges always pair a port id with a
    /// ``Node`` id via ``Node/PortReference``.
    struct Port: Sendable, Identifiable, Equatable, Codable {
        /// Whether a port accepts incoming connections (`input`) or drives
        /// outgoing ones (`output`).
        public enum Kind: Sendable, Codable {
            /// Accepts an incoming connection or an inline value.
            case input
            /// Drives one or more outgoing connections.
            case output
        }

        /// Stable per-template identity for this port. Two ``Node``s built
        /// from the same template share the same port ids.
        public let id: UUID

        /// Direction of the port.
        public let kind: Kind

        /// The kind of value this port carries. Compatibility between two
        /// ports is decided by ``PortType/canConnect(to:)``.
        public let type: PortType

        /// Localized label shown next to the port in the node body.
        public let localizedDisplayName: String

        /// Create a port description.
        public init(id: UUID, kind: Kind, type: PortType, localizedDisplayName: String) {
            self.id = id
            self.kind = kind
            self.type = type
            self.localizedDisplayName = localizedDisplayName
        }
    }
}
