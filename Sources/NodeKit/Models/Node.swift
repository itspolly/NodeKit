//
//  Node.swift
//  NodeKit
//
//  Created by Jamie on 05/05/2026.
//

import Foundation

/// A single placed instance of a ``NodeTemplate`` inside a ``Graph``.
///
/// A node carries everything that varies *per instance*: its identity, its
/// position on the canvas, the outgoing connections leaving its output ports,
/// and any inline values typed into its input ports. The node's *shape* — its
/// display name and the list of input/output ports — comes from the template
/// referenced by ``templateIdentifier``.
///
/// `Node` is `Sendable` and `Codable`. Two nodes that share the same
/// ``templateIdentifier`` share the same set of ``NodeTemplate/Port``
/// identifiers, which is why edges target ``PortReference`` (a `(node, port)`
/// pair) rather than a bare port id.
public struct Node: Sendable, Codable {
    /// Stable identity for this node within its graph.
    public let id: UUID

    /// Identifier of the ``NodeTemplate/Kind`` this node was instantiated
    /// from. Resolve via ``TemplateRegistry/registeredNodeTemplate(with:)``.
    ///
    /// If the template isn't currently registered (e.g. a plugin wasn't
    /// loaded for this session), the node still exists in the graph and is
    /// persisted across saves — the editor renders a dimmed "Missing
    /// template" placeholder for it that the user can still select, move,
    /// and delete. Registering a template with this identifier later
    /// restores normal rendering and any edges to its ports.
    public let templateIdentifier: UUID

    /// The node's top-left position on the canvas, in editor coordinates.
    /// Size is derived at layout time from the template, so it is not stored
    /// here.
    public var position: Point

    /// Outgoing edges, keyed by one of *this* node's output port ids.
    /// Each value is the list of inputs (on possibly different nodes) that the
    /// output drives. The owning node is implicit (`self.id`) so it isn't
    /// stored on the source side.
    ///
    /// Port ids are template-scoped — two nodes of the same template share the
    /// same ``NodeTemplate/Port`` identifiers — which is why targets are
    /// ``PortReference`` (a `(node, port)` pair) rather than bare `UUID`.
    public var outgoingConnectionsByPortIdentifier: [NodeTemplate.Port.ID: [Node.PortReference]]

    /// Inline values for input data ports without an incoming connection. The
    /// editor's value editors write here; an executor reads here when no edge
    /// drives a port. Ports not present in the map fall back to the type
    /// default registered with ``PortEditorRegistry``.
    public var portValues: [NodeTemplate.Port.ID: PortValue]

    /// Create a node.
    ///
    /// - Parameters:
    ///   - id: Stable per-node identity.
    ///   - templateIdentifier: ``NodeTemplate/Kind/id`` of the template this
    ///     node instantiates.
    ///   - position: Top-left canvas position.
    ///   - outgoingConnectionsByPortIdentifier: Edges leaving this node's
    ///     outputs. Keys are this node's output ``NodeTemplate/Port`` ids.
    ///   - portValues: Inline values for input ports without an incoming
    ///     connection. Defaults to empty.
    public init(
        id: UUID,
        templateIdentifier: UUID,
        position: Point,
        outgoingConnectionsByPortIdentifier: [NodeTemplate.Port.ID: [Node.PortReference]],
        portValues: [NodeTemplate.Port.ID: PortValue] = [:]
    ) {
        self.id = id
        self.templateIdentifier = templateIdentifier
        self.position = position
        self.outgoingConnectionsByPortIdentifier = outgoingConnectionsByPortIdentifier
        self.portValues = portValues
    }
}
