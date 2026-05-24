//
//  NodeTemplate+PortType.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

import Foundation

public extension NodeTemplate.Port {
    /// Opaque value describing what kind of data a port carries.
    ///
    /// NodeKit treats this as identity + display hints: it does not interpret
    /// what a type *means* at runtime. Consumers register their own types with
    /// a ``PortTypeRegistry`` and define semantics there. Built-in primitives
    /// (``bool``, ``int``, ``double``, ``string``) ship so simple data graphs
    /// work without any extra setup.
    struct PortType: Sendable, Hashable, Equatable, Codable, Identifiable {
        /// Stable string id (e.g. `"nodekit.bool"`, `"myapp.color"`). Strings,
        /// not UUIDs, so saved graphs survive plugin reinstalls and remain
        /// debuggable in serialised form.
        public let id: String

        /// Localized label shown anywhere a type is named (port tooltips,
        /// browser filters).
        public let localizedDisplayName: String

        /// Display hint for port rendering. `nil` means "use the editor
        /// default colour".
        public let color: ColorComponents?

        /// Create a port type description.
        ///
        /// - Parameters:
        ///   - id: Stable string identifier. Persisted in saved graphs — keep
        ///     it stable across releases.
        ///   - localizedDisplayName: Human-readable name.
        ///   - color: Optional display colour for the port circle.
        public init(id: String, localizedDisplayName: String, color: ColorComponents? = nil) {
            self.id = id
            self.localizedDisplayName = localizedDisplayName
            self.color = color
        }
    }

    /// sRGB colour components in the range `0...1`.
    ///
    /// `ColorComponents` exists instead of `Color` / `UIColor` because the
    /// graph is `Codable` and needs to round-trip on every platform NodeKit
    /// supports without a platform-specific colour space.
    struct ColorComponents: Sendable, Hashable, Equatable, Codable {
        /// Red channel, `0...1`.
        public let red: Double
        /// Green channel, `0...1`.
        public let green: Double
        /// Blue channel, `0...1`.
        public let blue: Double
        /// Alpha channel, `0...1`. Defaults to fully opaque.
        public let alpha: Double

        /// Create a colour description.
        public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }
}

public extension NodeTemplate.Port.PortType {
    /// Whether a value flowing out of an output port of this type can be
    /// accepted by an input port of `other`.
    ///
    /// Today this is identity (same ``id``). The check is intentionally a
    /// pure function — no registry round-trip — so the editor's drag-and-hover
    /// hot path stays synchronous. Future widening rules (e.g. `Int → Double`)
    /// belong here.
    func canConnect(to other: NodeTemplate.Port.PortType) -> Bool {
        self.id == other.id
    }
}

public extension NodeTemplate.Port.PortType {
    /// Built-in boolean port type.
    static let bool = NodeTemplate.Port.PortType(
        id: "nodekit.bool",
        localizedDisplayName: "Bool",
        color: .init(red: 0.85, green: 0.30, blue: 0.30)
    )

    /// Built-in integer port type.
    static let int = NodeTemplate.Port.PortType(
        id: "nodekit.int",
        localizedDisplayName: "Int",
        color: .init(red: 0.30, green: 0.55, blue: 0.95)
    )

    /// Built-in double-precision floating-point port type.
    static let double = NodeTemplate.Port.PortType(
        id: "nodekit.double",
        localizedDisplayName: "Double",
        color: .init(red: 0.30, green: 0.80, blue: 0.65)
    )

    /// Built-in string port type.
    static let string = NodeTemplate.Port.PortType(
        id: "nodekit.string",
        localizedDisplayName: "String",
        color: .init(red: 0.95, green: 0.70, blue: 0.30)
    )
}
