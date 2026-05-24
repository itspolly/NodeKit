# Adding custom port types

Teach NodeKit about a new value type and how the user should edit it inline.

## Overview

NodeKit ships with four primitive port types (``PortType/bool``,
``PortType/int``, ``PortType/double``, ``PortType/string``) and their
matching inline editors. Anything richer plugs in through two registries:

1. ``PortTypeRegistry`` — the catalog of known ``PortType``s, looked up by
   ``PortType/id``. Drives the editor's display hints (port colour, type
   name).
2. ``PortEditorRegistry`` — the per-type default value plus a SwiftUI
   editor for inline values.

A ``NodeTemplate/Port`` references its type by ``NodeTemplate/Port/typeIdentifier``
(a `String`), not by embedding the ``PortType`` value. The editor resolves
the identifier through ``PortTypeRegistry`` at render time. This lets
multiple templates share one registered type, and lets a port wire up
correctly even when its type isn't (yet, or no longer) registered — port
compatibility compares identifier strings directly on the drag/hover hot
path, with no registry round-trip.

Keep your ``PortType/id`` strings stable across releases — they're
persisted on every port that references them.

## Define the type

```swift
import NodeKit

extension PortType {
    static let color = PortType(
        id: "myapp.color",
        localizedDisplayName: "Color",
        color: .init(red: 0.95, green: 0.40, blue: 0.55)
    )
}

let portTypes = PortTypeRegistry()
portTypes.register(.color)
```

The optional ``ColorComponents`` is a display hint — it colours the port
circle in the editor.

## Reference the type from a template

Ports take a ``NodeTemplate/Port/typeIdentifier``:

```swift
let template = NodeTemplate(
    kind: .init(id: UUID(), localizedDisplayName: "Tinter"),
    inputs: [
        .init(id: UUID(), kind: .input,
              typeIdentifier: PortType.color.id,
              localizedDisplayName: "Tint")
    ],
    outputs: []
)
```

For convenience there's an overload that takes a ``PortType`` value
directly — same effect, fewer keystrokes when the type is in scope:

```swift
.init(id: UUID(), kind: .input, type: .color, localizedDisplayName: "Tint")
```

## Register an inline editor

Inline editors run when the user adds a literal value to an input port (the
`+` button next to a port label). They get a strong-typed `Binding<V>`; the
registry handles encoding to and from ``PortValue/custom(typeIdentifier:data:)``
through `JSONEncoder`/`JSONDecoder`.

```swift
struct ColorValue: Codable, Sendable, Equatable {
    var red: Double, green: Double, blue: Double
}

let editors = PortEditorRegistry()
editors.register(
    for: PortType.color.id,
    defaultValue: ColorValue(red: 1, green: 1, blue: 1)
) { binding in
    ColorPicker(
        "",
        selection: Binding(
            get: { Color(red: binding.wrappedValue.red,
                         green: binding.wrappedValue.green,
                         blue:  binding.wrappedValue.blue) },
            set: { _ in /* decompose Color back into RGB */ }
        )
    )
    .labelsHidden()
}
```

The same `defaultValue` is used as the fallback when stored data fails to
decode — handy if you evolve the schema across releases.

## Hand the registries to the editor

Pass both registries to ``GraphEditor`` so it can resolve types for
display and surface your inline editor for the `+` button.

```swift
GraphEditor(
    graph: $graph,
    templateRegistry: templates,
    portTypeRegistry: portTypes,
    portEditorRegistry: editors
)
```

## Unresolved types

If a port references a ``NodeTemplate/Port/typeIdentifier`` that isn't
registered in ``PortTypeRegistry`` (e.g. a plugin was uninstalled), the
port still renders — just dimmer, in a neutral colour — and connections
still work via identifier matching. The editor never throws away ports it
can't fully describe.

## Persistence

Custom values round-trip as ``PortValue/custom(typeIdentifier:data:)``
blobs. NodeKit never inspects the blob — it stores `typeIdentifier` +
opaque `Data` and lets your editor decode it on the way back in. Tag the
data with the same identifier you used at registration time.
