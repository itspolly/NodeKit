//
//  NodeTemplate.swift
//  NodeKit
//
//  Created by Jamie on 05/05/2026.
//

/// The shape of a node — its display identity (``Kind``) plus its input and
/// output ports.
///
/// Templates are the catalog from which the editor instantiates ``Node``s.
/// They are registered with a ``TemplateRegistry`` so the browser can list
/// them and the editor can resolve a ``Node/templateIdentifier`` back to its
/// ports for rendering. Templates are pure data: `Sendable`, `Codable`, and
/// safe to share across actors.
///
/// Port identifiers (``Port/id``) are template-scoped: two ``Node``s built
/// from the same template share the same set of port ids. Edges therefore
/// target ``Node/PortReference`` rather than a bare port id.
public struct NodeTemplate: Sendable, Equatable, Codable {
    /// Identity and display name for this template.
    public let kind: Kind

    /// Ports that accept incoming connections or inline values.
    public let inputs: [Port]

    /// Ports that drive outgoing connections.
    public let outputs: [Port]

    /// Create a node template.
    public init(kind: Kind, inputs: [Port], outputs: [Port]) {
        self.kind = kind
        self.inputs = inputs
        self.outputs = outputs
    }
}
