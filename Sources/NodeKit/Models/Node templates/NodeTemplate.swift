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

    /// Whether this template can be instantiated more than once in the same
    /// ``Graph``. When `false`, the editor's drop handler refuses to create a
    /// second ``Node`` for this template's ``Kind/id`` — useful for
    /// singletons (e.g. a "Document Properties" or "Output" node that only
    /// makes sense once per graph).
    ///
    /// Mutable so consumers can flip the flag without rebuilding the template
    /// — e.g. a registry could opt all globally-installed templates into
    /// reusability while marking project-local templates as singletons.
    public var reusable: Bool

    /// Create a node template.
    ///
    /// - Parameters:
    ///   - kind: Identity + display name.
    ///   - inputs: Input ports.
    ///   - outputs: Output ports.
    ///   - reusable: Whether this template can be instantiated more than once
    ///     in a graph. Defaults to `true`.
    public init(kind: Kind, inputs: [Port], outputs: [Port], reusable: Bool = true) {
        self.kind = kind
        self.inputs = inputs
        self.outputs = outputs
        self.reusable = reusable
    }
}
