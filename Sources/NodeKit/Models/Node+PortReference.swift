//
//  Node+PortReference.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

import Foundation

extension Node {
    /// A globally-unique reference to a port in a graph: a `(node, port)` pair.
    ///
    /// Port identifiers live on ``NodeTemplate/Port`` and are therefore
    /// *template-scoped*, not instance-scoped — two ``Node``s of the same
    /// template share the same port ids. Edges and anchors must key by this
    /// pair to stay unambiguous when the same template is instantiated more
    /// than once.
    public struct PortReference: Hashable, Codable, Sendable {
        /// The owning node's ``Node/id``.
        public let nodeIdentifier: UUID

        /// The port's ``NodeTemplate/Port/id`` within that node's template.
        public let portIdentifier: UUID

        /// Create a port reference.
        public init(nodeIdentifier: UUID, portIdentifier: UUID) {
            self.nodeIdentifier = nodeIdentifier
            self.portIdentifier = portIdentifier
        }
    }
}
