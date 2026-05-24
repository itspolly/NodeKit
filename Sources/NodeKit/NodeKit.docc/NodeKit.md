# ``NodeKit``

A SwiftUI node-graph editor for iOS, iPadOS, macOS and visionOS.

## Overview

NodeKit gives you a pannable, zoomable canvas of glassy nodes connected by
bezier wires, a paginated template browser for dragging new nodes onto the
canvas, and a registry-driven plug-in surface for adding your own port types
and inline value editors. It is intentionally headless of any execution model:
NodeKit owns the editing experience, your app owns what the graph *means*.

![A graph with three connected nodes on a dot-grid canvas.](graph-editor)

## Topics

### Essentials

- <doc:GettingStarted>
- ``GraphEditor``
- ``TemplateRegistryView``

### The graph model

- ``Graph``
- ``Node``
- ``Point``
- ``PortValue``

### Describing nodes

- ``NodeTemplate``
- ``TemplatePredicate``
- ``Page``

### Registries

- ``TemplateRegistry``
- ``PortTypeRegistry``
- ``PortEditorRegistry``

### Extending NodeKit

- <doc:CustomPortTypes>
- ``GraphStore``
