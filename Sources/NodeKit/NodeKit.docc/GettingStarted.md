# Getting started

Render a node graph in a SwiftUI app and let the user build it.

## Overview

NodeKit ships two SwiftUI views — ``GraphEditor`` for the canvas and
``TemplateRegistryView`` for the template browser — backed by three registries:
``TemplateRegistry`` (the catalog of node kinds), ``PortTypeRegistry`` (the
catalog of port types), and ``PortEditorRegistry`` (per-port-type inline value
editors). For a typical setup you own a single instance of each and pass them
in alongside a ``Graph`` binding.

![Graph editor with three connected nodes.](graph-editor)

## Add the dependency

NodeKit is distributed as a Swift Package. Add it from Xcode
(*File ▸ Add Package Dependencies…*) or in `Package.swift`:

```swift
.package(url: "https://github.com/itspolly/NodeKit.git", from: "0.1.0"),
```

Then add `"NodeKit"` to your target's dependencies and `import NodeKit`.

> Tip: NodeKit requires the Swift 6.3 toolchain and targets iOS 26 / macOS 26 /
> visionOS 26 — it uses the system glass material.

## Declare the drag-and-drop UTI

NodeKit ships a custom uniform type identifier, `is.polly.nodekit.template`,
that backs the drag from the template browser to the canvas. Apple's
`CoreTransferable` requires this UTI to be **exported by the host app's
`Info.plist`** — if you skip it, the system logs:

> Type "is.polly.nodekit.template" was expected to be declared and exported
> in the Info.plist of YourApp.app, but it was not found.

and the drag will refuse to start. In Xcode, open your app target's *Info*
tab and add an entry under *Exported Type Identifiers*:

| Field             | Value                                  |
| ----------------- | -------------------------------------- |
| Description       | NodeKit Template                       |
| Identifier        | `is.polly.nodekit.template`            |
| Conforms To       | `public.data`                          |

Or paste this directly into the raw `Info.plist`:

```xml
<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>is.polly.nodekit.template</string>
        <key>UTTypeDescription</key>
        <string>NodeKit Template</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
        </array>
    </dict>
</array>
```

Only one app in the install needs to export the type. If multiple NodeKit
hosts ship on the same device, exporting the same identifier from each is
fine — UTI exports are merged.

## Build a template catalog

A ``NodeTemplate`` describes the *shape* of a node — its display name and its
input/output ports. Register templates with a ``TemplateRegistry`` so the
browser can list them and the editor can resolve nodes back to their shape.

```swift
import NodeKit

let registry = TemplateRegistry()

let source = NodeTemplate(
    kind: .init(id: UUID(), localizedDisplayName: "Source"),
    inputs: [],
    outputs: [
        .init(id: UUID(), kind: .output, type: .double, localizedDisplayName: "Value")
    ]
)
let sink = NodeTemplate(
    kind: .init(id: UUID(), localizedDisplayName: "Sink"),
    inputs: [
        .init(id: UUID(), kind: .input, type: .double, localizedDisplayName: "Input")
    ],
    outputs: []
)

registry.register(template: source)
registry.register(template: sink)
```

The four primitive ``PortType`` values — `.bool`, `.int`, `.double`,
`.string` — come pre-registered with matching inline editors.

Ports reference their ``PortType`` by ``NodeTemplate/Port/typeIdentifier``
(a `String`). For convenience there's an overload on ``NodeTemplate/Port``
that takes the type value directly — the convenience init in the snippet
above uses it (`type: .double`).

## Host the editor

``GraphEditor`` takes a `Binding<Graph>` and a ``TemplateRegistry``. Hold the
graph in `@State`, or your own model, and the editor will mutate it in place as
the user pans, zooms, drags templates in, draws connections, and types into
inline editors.

> Important: Hold the ``TemplateRegistry`` (or whatever owns it) in `@State`.
> `View`s are value types and SwiftUI reconstructs them on every parent
> re-render — a plain `let registry = TemplateRegistry()` re-runs the
> initializer each time, creating a new empty registry and orphaning the
> previous one. The view's `@State` (e.g. `visiblePages`) is keyed to view
> *identity*, which is stable, so it keeps observing the orphan and the new
> registry never gets loaded.

```swift
import SwiftUI
import NodeKit

struct ContentView: View {
    @State private var graph = Graph(nodes: [])
    @State private var browserFilter: TemplatePredicate = .filter(name: nil, scope: nil)
    @State var templates = TemplateRegistry()
    @State var portTypes = PortTypeRegistry()

    var body: some View {
        NavigationSplitView {
            TemplateRegistryView(
                templateRegistry: templates,
                predicate: $browserFilter
            )
            .frame(width: 320)
        } detail: {
            GraphEditor(
                graph: $graph,
                templateRegistry: templates,
                portTypeRegistry: portTypes
            )
        }
    }
}
```

The four primitive ``PortType``s come pre-registered in
``PortTypeRegistry``; register custom types there for any port whose
``NodeTemplate/Port/typeIdentifier`` isn't one of NodeKit's built-ins.
See <doc:CustomPortTypes> for the full pattern.

Drag templates from the browser onto the canvas to create nodes. Drag from
one node's output port to another node's compatible input to connect them.

![Template browser listing draggable node templates.](template-browser)

## Persist the graph

Both ``Graph`` and ``NodeTemplate`` are `Codable` and `Sendable`. Encode them
with `JSONEncoder` (or any other coder) for round-tripping to disk, iCloud or
a server. Port values stored inline on nodes — primitive cases plus opaque
``PortValue/custom(typeIdentifier:data:)`` blobs — round-trip with the rest of
the graph.

```swift
let data = try JSONEncoder().encode(graph)
let restored = try JSONDecoder().decode(Graph.self, from: data)
```

## Where to go next

- <doc:CustomPortTypes> — add your own port types and inline editors.
- ``TemplatePredicate`` — filter the template browser by name or scope.
- ``GraphEditor`` and ``TemplateRegistryView`` — full API reference.
