//
//  PortTypeRegistry.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

import Foundation

/// Catalogues the known ``NodeTemplate/Port/PortType`` values. Used for lookup
/// by id and enumeration; consumers (e.g. MissionKit) register their own
/// types alongside the built-in primitives.
///
/// **Compatibility checks live on ``NodeTemplate/Port/PortType`` itself** so the
/// editor's drag/hover hot path stays synchronous. The registry is an `actor`
/// because mutation can come from any concurrency context (plugin loaders,
/// startup tasks); reading the catalogue and registering new types both go
/// through `await`.
public actor PortTypeRegistry {
    private var typesByID: [String: NodeTemplate.Port.PortType] = [:]

    public init() {
        for type in PortTypeRegistry.builtIns {
            typesByID[type.id] = type
        }
    }

    public func register(_ type: NodeTemplate.Port.PortType) {
        typesByID[type.id] = type
    }

    public func portType(for id: String) -> NodeTemplate.Port.PortType? {
        typesByID[id]
    }

    public func allTypes() -> [NodeTemplate.Port.PortType] {
        Array(typesByID.values)
    }

    public static let builtIns: [NodeTemplate.Port.PortType] = [
        .bool, .int, .double, .string,
    ]
}
