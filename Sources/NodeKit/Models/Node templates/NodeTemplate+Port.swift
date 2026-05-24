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
    /// Ports carry an identity, a direction (``Kind``), a *reference* to a
    /// ``PortType`` by its ``typeIdentifier``, and a localized display name
    /// shown alongside the port in the node body. Identities are
    /// template-scoped — see ``NodeTemplate`` — so edges always pair a port
    /// id with a ``Node`` id via ``Node/PortReference``.
    ///
    /// `Port` references its type by id rather than embedding a ``PortType``
    /// value so multiple templates can share one registered type. The
    /// editor resolves ``typeIdentifier`` through ``PortTypeRegistry`` at
    /// render time for visual hints; connection compatibility compares
    /// identifiers directly without a registry round-trip, so an unresolved
    /// type still wires up correctly to its matching counterpart.
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

        /// Identifier of the ``PortType`` this port carries. Resolved
        /// against ``PortTypeRegistry`` at render time for display hints.
        public let typeIdentifier: String

        /// Localized label shown next to the port in the node body.
        public let localizedDisplayName: String

        /// Create a port description.
        public init(id: UUID, kind: Kind, typeIdentifier: String, localizedDisplayName: String) {
            self.id = id
            self.kind = kind
            self.typeIdentifier = typeIdentifier
            self.localizedDisplayName = localizedDisplayName
        }
    }
}

public extension NodeTemplate.Port {
    /// Convenience that mints a port from an in-hand ``PortType`` value.
    /// Equivalent to passing the type's ``PortType/id`` to the designated
    /// init, but keeps call sites readable when the type is built-in or
    /// otherwise available as a value.
    init(id: UUID, kind: Kind, type: PortType, localizedDisplayName: String) {
        self.init(id: id, kind: kind, typeIdentifier: type.id, localizedDisplayName: localizedDisplayName)
    }
}
