//
//  Graph.swift
//  NodeKit
//
//  Created by Jamie on 05/05/2026.
//

/// The persistent state of a node graph: an ordered collection of ``Node``s
/// and the edges between them.
///
/// `Graph` is intentionally the smallest possible model — there is no
/// "connections" array, because edges live on the source ``Node`` (see
/// ``Node/outgoingConnectionsByPortIdentifier``). This keeps the document
/// self-contained: deleting a node also removes its outgoing edges, and the
/// JSON shape stays close to the structure a human would draw.
///
/// `Graph` is `Sendable` and `Codable`, so you can hold it in `@State`, ship
/// it across actor boundaries, or round-trip it to disk with `JSONEncoder` /
/// `JSONDecoder`.
public struct Graph: Sendable, Codable {
    /// The nodes that make up the graph. Order has no semantic meaning; the
    /// editor renders nodes by their ``Node/position`` and uses the array as a
    /// stable identity list.
    public var nodes: [Node]

    /// Create a graph that starts with the given nodes.
    public init(nodes: [Node]) {
        self.nodes = nodes
    }
}
