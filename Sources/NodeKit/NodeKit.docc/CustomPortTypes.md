# Adding custom port types

Teach NodeKit about a new value type and how the user should edit it inline.

## Overview

NodeKit ships with four primitive port types (``NodeTemplate/Port/PortType/bool``,
``NodeTemplate/Port/PortType/int``, ``NodeTemplate/Port/PortType/double``,
``NodeTemplate/Port/PortType/string``) and their matching inline editors.
Anything richer comes through two places:

1. ``PortTypeRegistry`` — the catalog of known port types, looked up by id.
2. ``PortEditorRegistry`` — the per-type default value plus a SwiftUI editor
   for inline values.

Compatibility between an output and an input port is decided by
``NodeTemplate/Port/PortType/canConnect(to:)``, which today is identity (same
``NodeTemplate/Port/PortType/id``). Keep your ids stable across releases:
they are written into saved graphs.

## Define the type

```swift
import NodeKit

extension NodeTemplate.Port.PortType {
    static let color = NodeTemplate.Port.PortType(
        id: "myapp.color",
        localizedDisplayName: "Color",
        color: .init(red: 0.95, green: 0.40, blue: 0.55)
    )
}

let portTypes = PortTypeRegistry()
await portTypes.register(.color)
```

The optional ``NodeTemplate/Port/ColorComponents`` is a display hint — it
colors the port circle in the editor.

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
    for: NodeTemplate.Port.PortType.color.id,
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

## Hand the editors to the canvas

Pass your `PortEditorRegistry` to ``GraphEditor`` and any node with a `.color`
input port will offer your color picker inline.

```swift
GraphEditor(
    graph: $graph,
    templateRegistry: templates,
    portEditorRegistry: editors
)
```

## Persistence

Custom values round-trip as ``PortValue/custom(typeIdentifier:data:)`` blobs.
NodeKit never inspects the blob — it stores `typeIdentifier` + opaque `Data`
and lets your editor decode it on the way back in. Tag the data with the same
identifier you used at registration time.
