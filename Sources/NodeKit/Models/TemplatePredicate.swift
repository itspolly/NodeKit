//
//  TemplatePredicate.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

/// A composable filter over ``NodeTemplate``s, used by ``TemplateRegistry`` to
/// narrow the set of templates a browser displays.
///
/// Predicates compose with ``not(_:)``, ``and(_:)`` and ``or(_:)``; the leaf
/// case ``filter(name:scope:)`` matches by display-name substring and/or by
/// where the template "lives" (project, installed plug-in, global catalog).
///
/// `TemplatePredicate` is value-type, `Sendable`, `Hashable` and `Equatable`
/// so it works well as a `Binding` driving `TemplateRegistryView`, as a
/// `.task(id:)` key, or as a parameter to a future server-backed registry.
///
/// ```swift
/// // Templates whose name contains "filter", anywhere they live.
/// let p: TemplatePredicate = .filter(name: "filter", scope: nil)
///
/// // Project-only node templates, excluding any whose name contains "old".
/// let q: TemplatePredicate = .and([
///     .filter(name: nil, scope: .init(store: .project, kind: .nodeTemplates)),
///     .not(.filter(name: "old", scope: nil))
/// ])
/// ```
public indirect enum TemplatePredicate: Sendable, Equatable, Hashable {
    /// Where a template comes from and what shape it has.
    public struct Scope: Sendable, Equatable, Hashable {
        /// The catalog a template lives in.
        public enum Store: Sendable, Equatable, Hashable {
            /// Defined in the current document.
            case project
            /// Provided by an installed plug-in.
            case installed
            /// Provided by NodeKit (or whichever global catalog the host wires up).
            case global
        }

        /// What a template represents in the editor.
        public enum Kind: Sendable, Equatable, Hashable {
            /// A port-only template (e.g. an input or output marker). `input`
            /// is `true` for input ports, `false` for output ports.
            case ports(input: Bool)
            /// A regular node template that produces a node when dragged.
            case nodeTemplates
        }

        /// The catalog to match, or `nil` to match any catalog.
        public let store: Store?

        /// The kind of template to match, or `nil` to match any kind.
        public let kind: Kind?

        /// Create a scope. Pass `nil` for either field to match any value.
        public init(store: Store?, kind: Kind?) {
            self.store = store
            self.kind = kind
        }
    }

    /// Match by display-name substring and/or by scope. Both arguments are
    /// optional; `nil` means "don't filter on this dimension". A `.filter`
    /// with both arguments `nil` matches everything.
    case filter(name: String?, scope: Scope?)

    /// Logical negation of the wrapped predicate.
    case not(TemplatePredicate)

    /// Match if *all* sub-predicates match. An empty array matches everything.
    case and([TemplatePredicate])

    /// Match if *any* sub-predicate matches. An empty array matches nothing.
    case or([TemplatePredicate])
}
