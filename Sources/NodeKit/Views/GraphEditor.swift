//
//  GraphEditor.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

/// A SwiftUI node-graph editor with pan/zoom, glassy nodes, port-drag-to-connect,
/// bezier connections, dot-grid background, selection and delete. Multiplatform
/// across iOS, iPadOS, macOS and visionOS.
public struct GraphEditor: View {
    @Binding var graph: Graph
    var templateRegistry: TemplateRegistry

    @State private var state: GraphEditorState

    public init(
        graph: Binding<Graph>,
        templateRegistry: TemplateRegistry,
        portTypeRegistry: PortTypeRegistry = PortTypeRegistry(),
        portEditorRegistry: PortEditorRegistry = PortEditorRegistry()
    ) {
        self._graph = graph
        self.templateRegistry = templateRegistry
        self._state = State(initialValue: GraphEditorState(
            portTypeRegistry: portTypeRegistry,
            portEditorRegistry: portEditorRegistry
        ))
    }

    public var body: some View {
        GraphCanvas(graph: $graph, templateRegistry: templateRegistry, state: state)
            .overlay(alignment: .bottomTrailing) { editorToolbar }
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.zoom = max(0.2, state.zoom / 1.2)
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.pan = .zero
                    state.zoom = 1.0
                }
            } label: {
                Text("\(Int(state.effectiveZoom * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 44)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    state.zoom = min(3.0, state.zoom * 1.2)
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
        }
        .buttonStyle(.glass)
        .padding(10)
        .glassEffect(.regular, in: Capsule())
        .padding(16)
    }
}

#if DEBUG
@MainActor
private enum GraphEditorPreviewSeed {
    static func make() -> (Graph, TemplateRegistry) {
        let inA = NodeTemplate.Port(id: UUID(), kind: .input, type: .bool, localizedDisplayName: "Trigger")
        let inB = NodeTemplate.Port(id: UUID(), kind: .input, type: .string, localizedDisplayName: "Payload")
        let outA = NodeTemplate.Port(id: UUID(), kind: .output, type: .string, localizedDisplayName: "Result")

        let sourceTick = NodeTemplate.Port(id: UUID(), kind: .output, type: .bool, localizedDisplayName: "Tick")
        let sourceOut = NodeTemplate.Port(id: UUID(), kind: .output, type: .string, localizedDisplayName: "Stream")
        let sinkIn = NodeTemplate.Port(id: UUID(), kind: .input, type: .string, localizedDisplayName: "Sink")

        let process = NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: "Process"),
            inputs: [inA, inB],
            outputs: [outA]
        )
        let source = NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: "Source"),
            inputs: [],
            outputs: [sourceTick, sourceOut]
        )
        let sink = NodeTemplate(
            kind: .init(id: UUID(), localizedDisplayName: "Sink"),
            inputs: [sinkIn],
            outputs: []
        )

        let registry = TemplateRegistry()
        registry.register(template: source)
        registry.register(template: process)
        registry.register(template: sink)

        let sourceNodeID = UUID()
        let processNodeID = UUID()
        let sinkNodeID = UUID()

        let sourceNode = Node(
            id: sourceNodeID,
            templateIdentifier: source.kind.id,
            position: Point(x: 160, y: 220),
            outgoingConnectionsByPortIdentifier: [
                sourceTick.id: [Node.PortReference(nodeIdentifier: processNodeID, portIdentifier: inA.id)],
                sourceOut.id: [Node.PortReference(nodeIdentifier: processNodeID, portIdentifier: inB.id)],
            ]
        )
        let processNode = Node(
            id: processNodeID,
            templateIdentifier: process.kind.id,
            position: Point(x: 430, y: 320),
            outgoingConnectionsByPortIdentifier: [
                outA.id: [Node.PortReference(nodeIdentifier: sinkNodeID, portIdentifier: sinkIn.id)],
            ]
        )
        let sinkNode = Node(
            id: sinkNodeID,
            templateIdentifier: sink.kind.id,
            position: Point(x: 700, y: 420),
            outgoingConnectionsByPortIdentifier: [:]
        )

        return (Graph(nodes: [sourceNode, processNode, sinkNode]), registry)
    }
}

private struct GraphEditorPreviewHost: View {
    @State private var graph: Graph
    private let registry: TemplateRegistry

    init() {
        let seed = GraphEditorPreviewSeed.make()
        _graph = State(initialValue: seed.0)
        registry = seed.1
    }

    var body: some View {
        GraphEditor(graph: $graph, templateRegistry: registry)
    }
}

#Preview("Graph Editor") {
    GraphEditorPreviewHost()
        .frame(minWidth: 700, minHeight: 500)
}
#endif
