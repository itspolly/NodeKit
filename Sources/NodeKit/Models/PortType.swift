//
//  PortType.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

/// Opaque value describing what kind of data a port carries.
///
/// `PortType` is identity + display hints — NodeKit does not interpret what a
/// type *means* at runtime. Consumers register their own types with a
/// ``PortTypeRegistry`` and define semantics there. Built-in primitives
/// (``bool``, ``int``, ``double``, ``string``) ship so simple data graphs
/// work without any extra setup.
///
/// ## Identity, not embedding
///
/// `NodeTemplate.Port` references its type by ``id`` (a `String`), not by
/// embedding a `PortType` value. The editor resolves the id through a
/// ``PortTypeRegistry`` at render time to get colour and display name. This
/// lets a plugin register one `PortType` that's shared by many templates,
/// and lets the registry serve as the single source of truth for what types
/// exist in the editor.
///
/// Connection compatibility on the editor's drag/hover hot path compares
/// ids directly — no registry round-trip — so a port whose id isn't (yet,
/// or no longer) registered can still be wired up against ports with the
/// same id. The registry's role is purely visual.
public struct PortType: Sendable, Hashable, Equatable, Codable, Identifiable {
    /// Stable string id (e.g. `"nodekit.bool"`, `"myapp.color"`). Strings,
    /// not UUIDs, so saved graphs survive plugin reinstalls and remain
    /// debuggable in serialised form. Keep stable across releases — port
    /// references on templates and graphs persist this exact string.
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
    ///   - id: Stable string identifier. Persisted in graphs — keep stable
    ///     across releases.
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
public struct ColorComponents: Sendable, Hashable, Equatable, Codable {
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

public extension PortType {
    /// Built-in boolean port type. Pre-registered by ``PortTypeRegistry``.
    static let bool = PortType(
        id: "nodekit.bool",
        localizedDisplayName: "Bool",
        color: .init(red: 0.85, green: 0.30, blue: 0.30)
    )

    /// Built-in integer port type. Pre-registered by ``PortTypeRegistry``.
    static let int = PortType(
        id: "nodekit.int",
        localizedDisplayName: "Int",
        color: .init(red: 0.30, green: 0.55, blue: 0.95)
    )

    /// Built-in double-precision floating-point port type. Pre-registered by
    /// ``PortTypeRegistry``.
    static let double = PortType(
        id: "nodekit.double",
        localizedDisplayName: "Double",
        color: .init(red: 0.30, green: 0.80, blue: 0.65)
    )

    /// Built-in string port type. Pre-registered by ``PortTypeRegistry``.
    static let string = PortType(
        id: "nodekit.string",
        localizedDisplayName: "String",
        color: .init(red: 0.95, green: 0.70, blue: 0.30)
    )
}
