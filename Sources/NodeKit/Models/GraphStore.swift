//
//  GraphStore.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

/// Marker protocol reserved for a future persistence hook — e.g. an in-memory
/// store for tests or a database-backed store for documents on disk.
///
/// - Important: This protocol has no requirements today. Conforming to it gets
///   you nothing yet, and the requirements that land here may be source
///   breaking. Don't build against it until it has a real shape.
public protocol GraphStore: Sendable {}
