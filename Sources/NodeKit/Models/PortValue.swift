//
//  PortValue.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

import Foundation

/// An inline value stored on a node's input port. Used as the value of a data
/// port when no incoming connection drives it.
///
/// The four primitive cases (``bool(_:)``, ``int(_:)``, ``double(_:)``,
/// ``string(_:)``) are NodeKit's built-ins. Any richer type comes through
/// ``custom(typeIdentifier:data:)``: a `typeIdentifier` (matching some
/// ``PortType/id``) and an opaque `Data` blob whose encoding is the
/// responsibility of whoever registered that port type with the
/// ``PortEditorRegistry``. NodeKit itself never decodes `.custom` data — it
/// just stores it and round-trips it through `Codable`.
public enum PortValue: Sendable, Equatable, Codable {
    /// A boolean value.
    case bool(Bool)
    /// An integer value.
    case int(Int)
    /// A double-precision floating-point value.
    case double(Double)
    /// A string value.
    case string(String)
    /// An opaque value defined by a custom port type. NodeKit stores the
    /// `typeIdentifier` + `data` blob but never inspects the bytes; the
    /// owning ``PortEditorRegistry`` registration round-trips them through
    /// JSON.
    case custom(typeIdentifier: String, data: Data)

    /// Identifier of the matching ``PortType``. Useful for dispatching back
    /// to the right inline editor.
    public var typeIdentifier: String {
        switch self {
        case .bool:   return PortType.bool.id
        case .int:    return PortType.int.id
        case .double: return PortType.double.id
        case .string: return PortType.string.id
        case .custom(let typeIdentifier, _): return typeIdentifier
        }
    }
}
