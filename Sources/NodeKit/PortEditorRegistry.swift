//
//  PortEditorRegistry.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

import SwiftUI

/// Owns the per-port-type bits that the editor needs to render an inline
/// value: a default value (used when the user hits the `+` button) and a
/// SwiftUI view that edits that value (rendered next to the port label).
///
/// NodeKit registers built-in editors for the four primitive port types on
/// init. Consumers register their own port types here alongside: the typed
/// `register` overload hides `Data` (de)serialization so plugin authors
/// work with their strong type and the registry deals with
/// ``PortValue/custom(typeIdentifier:data:)``.
///
/// ## Concurrency and ordering
///
/// `PortEditorRegistry` is `@Observable` and isolated to `@MainActor`.
/// `register` is synchronous and, called from MainActor code, takes effect
/// in call order — a synchronous loop produces deterministic, sequential
/// state. Views that read ``hasInlineEditor(for:)`` /
/// ``defaultValue(for:)`` / ``editor(for:value:)`` from their `body`
/// re-render automatically when the catalog changes.
///
/// Called from outside MainActor `register` needs to be treated as
/// asynchronous (the call hops across actor isolation). If you issue
/// registrations from multiple async tasks, the MainActor schedules them
/// but doesn't order them by call site — await each call before issuing
/// the next if you need a specific sequence.
@MainActor
@Observable
public final class PortEditorRegistry {
    public init() {
        registerPrimitives()
    }

    // MARK: - Registration

    /// Register a custom port type's default value + inline editor. The plugin
    /// works with its strong type `V`; the registry serializes through
    /// `JSONEncoder` / `JSONDecoder` to and from `PortValue.custom`.
    ///
    /// `defaultValue` is also used as the fallback when stored data fails to
    /// decode — useful if a plugin updates its schema across versions.
    public func register<V: Codable & Sendable, Content: View>(
        for portTypeIdentifier: String,
        defaultValue: V,
        @ViewBuilder editor: @MainActor @escaping (Binding<V>) -> Content
    ) {
        let defaultProvider: () -> PortValue = {
            // Best-effort encode. If JSON encoding ever fails for a value
            // SwiftUI is about to render — that's a programmer error worth
            // surfacing, but not a runtime crash here.
            let data = (try? JSONEncoder().encode(defaultValue)) ?? Data()
            return .custom(typeIdentifier: portTypeIdentifier, data: data)
        }
        let builder: @MainActor (Binding<PortValue>) -> AnyView = { binding in
            let typed = Binding<V>(
                get: {
                    guard case let .custom(_, data) = binding.wrappedValue,
                          let v = try? JSONDecoder().decode(V.self, from: data)
                    else { return defaultValue }
                    return v
                },
                set: { newValue in
                    let data = (try? JSONEncoder().encode(newValue)) ?? Data()
                    binding.wrappedValue = .custom(
                        typeIdentifier: portTypeIdentifier,
                        data: data
                    )
                }
            )
            return AnyView(editor(typed))
        }
        entries[portTypeIdentifier] = Entry(
            defaultValue: defaultProvider,
            editorBuilder: builder
        )
    }

    // MARK: - Lookup

    /// The seed value NodeKit writes when the user adds an inline value via
    /// the `+` button. `nil` means "this port type has no inline editor" —
    /// the `+` button is hidden.
    public func defaultValue(for portTypeIdentifier: String) -> PortValue? {
        entries[portTypeIdentifier]?.defaultValue()
    }

    /// Whether an inline editor is registered for this port type. The `+`
    /// button on an input port is gated on this — port types without a
    /// registered editor (e.g. exec) never offer inline values.
    public func hasInlineEditor(for portTypeIdentifier: String) -> Bool {
        entries[portTypeIdentifier] != nil
    }

    /// SwiftUI view that edits the inline value at the given binding. `nil`
    /// when no editor is registered for `portTypeIdentifier` (the row will
    /// fall back to showing nothing, which shouldn't happen in practice
    /// because the same condition gates the `+` button above).
    public func editor(
        for portTypeIdentifier: String,
        value: Binding<PortValue>
    ) -> AnyView? {
        entries[portTypeIdentifier]?.editorBuilder(value)
    }

    // MARK: - Internals

    private struct Entry {
        let defaultValue: () -> PortValue
        let editorBuilder: @MainActor (Binding<PortValue>) -> AnyView
    }

    private var entries: [String: Entry] = [:]

    /// Built-in registrations for the four primitive port types. These use
    /// the matching non-`custom` `PortValue` case directly (no Data round
    /// trip) so the on-disk shape stays the simple enum form.
    private func registerPrimitives() {
        let bool = PortType.bool.id
        entries[bool] = Entry(
            defaultValue: { .bool(false) },
            editorBuilder: { binding in
                AnyView(
                    Toggle("", isOn: Binding(
                        get: {
                            if case let .bool(b) = binding.wrappedValue { return b }
                            return false
                        },
                        set: { binding.wrappedValue = .bool($0) }
                    ))
                    .labelsHidden()
                    .controlSize(.mini)
                )
            }
        )

        let int = PortType.int.id
        entries[int] = Entry(
            defaultValue: { .int(0) },
            editorBuilder: { binding in
                AnyView(
                    TextField("", value: Binding(
                        get: {
                            if case let .int(i) = binding.wrappedValue { return i }
                            return 0
                        },
                        set: { binding.wrappedValue = .int($0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .font(.caption)
                )
            }
        )

        let double = PortType.double.id
        entries[double] = Entry(
            defaultValue: { .double(0) },
            editorBuilder: { binding in
                AnyView(
                    TextField("", value: Binding(
                        get: {
                            if case let .double(d) = binding.wrappedValue { return d }
                            return 0
                        },
                        set: { binding.wrappedValue = .double($0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .font(.caption)
                )
            }
        )

        let string = PortType.string.id
        entries[string] = Entry(
            defaultValue: { .string("") },
            editorBuilder: { binding in
                AnyView(
                    TextField("", text: Binding(
                        get: {
                            if case let .string(s) = binding.wrappedValue { return s }
                            return ""
                        },
                        set: { binding.wrappedValue = .string($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .font(.caption)
                )
            }
        )
    }
}
