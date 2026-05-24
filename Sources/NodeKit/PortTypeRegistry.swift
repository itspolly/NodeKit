//
//  PortTypeRegistry.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

import Foundation

/// Catalogues the known ``PortType`` values and resolves identifiers back to
/// their display hints (colour, localized name). Plugins register the types
/// they introduce so multiple templates can share one canonical
/// ``PortType``; the editor reads from here when rendering ports.
///
/// ## Identity vs visuals
///
/// Connection compatibility on the editor's drag/hover hot path compares
/// ``NodeTemplate/Port/typeIdentifier`` strings directly — no registry
/// round-trip — so a port whose type isn't registered still wires up
/// against ports with the same id. The registry's role is purely visual:
/// when a port's ``NodeTemplate/Port/typeIdentifier`` doesn't resolve here,
/// the editor falls back to a neutral grey rendering and that's the only
/// downside.
///
/// ## Observation
///
/// `PortTypeRegistry` is `@Observable` and isolated to `@MainActor`. Views
/// that read ``portType(for:)`` from their body re-render automatically
/// when types are registered or unregistered — pre-loading or lazy plugin
/// loading both light up the editor without further wiring.
///
/// ## Ordering of mutations
///
/// `register` and `unregister` are synchronous and, called from MainActor
/// code, take effect in call order. Called from outside MainActor they
/// need to be treated as asynchronous (the call hops across actor
/// isolation). If you issue calls from multiple async tasks, the MainActor
/// schedules them but doesn't order them by call site — await each call
/// before issuing the next if you need a specific sequence.
@Observable
@MainActor
public final class PortTypeRegistry {
    /// Built-in port types pre-registered on `init`.
    public static let builtIns: [PortType] = [
        .bool, .int, .double, .string,
    ]

    private var typesByID: [String: PortType]

    public init() {
        var byID: [String: PortType] = [:]
        for type in PortTypeRegistry.builtIns {
            byID[type.id] = type
        }
        self.typesByID = byID
    }

    /// Add or replace a port type. Views that read this registry re-render
    /// via `@Observable`.
    public func register(_ type: PortType) {
        typesByID[type.id] = type
    }

    /// Remove a port type by id. Ports referencing the removed identifier
    /// remain in their templates and graphs — the editor falls back to a
    /// neutral rendering for them and warns nobody. Re-registering the same
    /// id restores the display hints.
    public func unregister(typeIdentifier: String) {
        typesByID.removeValue(forKey: typeIdentifier)
    }

    /// Resolve an identifier to its registered ``PortType``, or `nil` if
    /// nothing is registered for that id.
    public func portType(for typeIdentifier: String) -> PortType? {
        typesByID[typeIdentifier]
    }

    /// Snapshot of every currently-registered port type, in arbitrary order.
    public var allTypes: [PortType] {
        Array(typesByID.values)
    }
}
