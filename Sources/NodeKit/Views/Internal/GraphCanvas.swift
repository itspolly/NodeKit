//
//  GraphCanvas.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

struct GraphCanvas: View {
    @Binding var graph: Graph
    let templateRegistry: TemplateRegistry
    let state: GraphEditorState

    /// Mutable scratch storage for the latest hovered cursor point. Wrapped in
    /// a reference type (not `@State` directly) because the hover-cursor value
    /// is *written* by `.onContinuousHover` on every mouse movement but only
    /// *read* by the scroll-wheel zoom handler — it isn't view state. A bare
    /// `@State CGPoint` would invalidate the view on every cursor pixel of
    /// motion, including during the drag-image animation, which destabilises
    /// the `.dropDestination`'s view identity and triggers an AppKit replay
    /// of the just-completed drop (with the cached drop location and a
    /// freshly-sampled cursor X — the "identical-Y-to-seven-decimals"
    /// duplicate-node bug). Held by `@State` so a single instance is bound to
    /// the view's identity across struct rebuilds.
    @State private var pointerStore = PointerLocationStore()
    @State private var contextMenuEdge: EdgeRef?
    /// Tracks Command-key state for additive selection. SwiftUI tap gestures
    /// don't expose modifier state directly; `.onModifierKeysChanged` is the
    /// supported way to keep this in sync.
    @State private var commandIsHeld: Bool = false
    /// Drives keyboard focus for the canvas on iOS / iPadOS, where
    /// `.focusable()` alone isn't enough — SwiftUI's tap gestures don't move
    /// focus to a focusable view by themselves, so `.onKeyPress` never fires.
    /// On macOS this works too, but the bare Delete key isn't reliably caught
    /// by `.onKeyPress` even with focus; the hidden Button below handles that.
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background — establishes the screen-space hit target for pan, zoom,
                // tap-to-select-or-clear, and long-press-for-context-menu. Painted
                // with a soft material so the editor feels like part of the
                // surrounding surface.
                Rectangle()
                    .fill(.background.tertiary)
                    .overlay(DotGridBackground(pan: state.effectivePan, zoom: state.effectiveZoom))
                    .contentShape(Rectangle())
                    .gesture(panGesture)
                    .simultaneousGesture(tapGesture)
                    .simultaneousGesture(longPressGesture)
                    .background {
                        #if os(macOS)
                        // Trackpad two-finger pan / scroll-wheel arrives as
                        // NSEvent.scrollWheel which SwiftUI gestures never see.
                        // Route by `phase`: trackpad / Magic Mouse gestures
                        // (phase set) pan; discrete scroll-wheel ticks (no
                        // phase) zoom at the cursor.
                        ScrollWheelCatcher { event in
                            handleScrollWheel(event)
                        }
                        #endif
                    }

                // Transformed canvas content — connections + nodes + in-flight overlay.
                canvasContent
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .scaleEffect(state.effectiveZoom, anchor: .topLeading)
                    .offset(state.effectivePan)
                    .allowsHitTesting(true)
            }
            .clipped()
            // Magnify lives at the canvas level (rather than on the background
            // Rectangle) so a pinch over a node still zooms — node-level
            // gestures otherwise consume the pinch before the background sees
            // it. `.simultaneousGesture` lets it coexist with node drags/taps.
            .simultaneousGesture(magnifyGesture(in: geo.size))
            // Drops: on iOS/iPadOS/visionOS SwiftUI's `.dropDestination`
            // works fine; on macOS its bridge into AppKit replays drops
            // (the identical-Y-to-seven-decimals duplicate-node bug), and
            // `.onDrop` shares the same bridge. On macOS we drop down to a
            // direct `NSView` drop target via `NSViewRepresentable` (see
            // `MacGraphDropTarget`) which lets us own
            // `performDragOperation` / `concludeDragOperation` and avoids
            // the bridge entirely.
            #if os(macOS)
            .background {
                MacGraphDropTarget { payloads, location in
                    Task { @MainActor in
                        handleDrop(items: payloads, screenLocation: location)
                    }
                }
            }
            #else
            .dropDestination(for: TemplateDragPayload.self) { items, location in
                Task { @MainActor in
                    handleDrop(items: items, screenLocation: location)
                }
                return true
            }
            #endif
            .onContinuousHover { phase in
                if case let .active(point) = phase {
                    pointerStore.location = point
                }
            }
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onAppear { isFocused = true }
            #if !os(iOS) || os(iPadOS)
            .onModifierKeysChanged(mask: .command) { _, new in
                commandIsHeld = new.contains(.command)
            }
            #endif
            .onKeyPress(.delete) { deleteSelection(); return .handled }
            .onKeyPress(.deleteForward) { deleteSelection(); return .handled }
            .background {
                // macOS fallback: the bare Delete key on macOS doesn't fire
                // `.onKeyPress` reliably even when the view is focused (the
                // key has to traverse AppKit's responder chain, which the
                // focus-based path doesn't hook into). A hidden Button with
                // `.keyboardShortcut(.delete, modifiers: [])` registers with
                // the window's keyEquivalent dispatcher and fires reliably.
                //
                // Gated on "there's actually a selection" so it doesn't
                // intercept Delete while the user is editing an inline value
                // in a TextField (where Delete should erase a character).
                Button("Delete Selection") { deleteSelection() }
                    .keyboardShortcut(.delete, modifiers: [])
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .disabled(state.selection.isEmpty && state.selectedEdges.isEmpty)
            }
            .confirmationDialog(
                "Connection",
                isPresented: Binding(
                    get: { contextMenuEdge != nil },
                    set: { if !$0 { contextMenuEdge = nil } }
                ),
                presenting: contextMenuEdge
            ) { edge in
                Button("Delete connection", role: .destructive) {
                    graph.disconnect(source: edge.source, target: edge.target)
                    state.selectedEdges.remove(edge)
                }
            }
        }
    }

    // MARK: - Inner content

    @ViewBuilder
    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
            ConnectionsLayer(
                graph: graph,
                anchors: state.portAnchors,
                pending: state.pendingConnection,
                selectedEdges: state.selectedEdges
            )

            ForEach(graph.nodes, id: \.id) { node in
                if let template = templateRegistry.registeredNodeTemplate(with: node.templateIdentifier) {
                    NodeView(
                        node: node,
                        template: template,
                        isSelected: state.selection.contains(node.id),
                        state: state,
                        graph: $graph,
                        onTap: { selectNode(node.id, additive: commandIsHeld) }
                    )
                }
            }
        }
        .coordinateSpace(name: canvasCoordinateSpace)
        .onPreferenceChange(PortAnchorPreferenceKey.self) { anchors in
            Task { @MainActor in
                var dict: [Node.PortReference: PortAnchor] = [:]
                dict.reserveCapacity(anchors.count)
                for anchor in anchors {
                    dict[anchor.reference] = anchor
                }
                state.portAnchors = dict
            }
        }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                state.panGesture = value.translation
            }
            .onEnded { _ in
                state.commitPan()
            }
    }

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if state.zoomAnchorScreen == nil {
                    let a = value.startAnchor
                    state.zoomAnchorScreen = CGPoint(
                        x: a.x * size.width,
                        y: a.y * size.height
                    )
                }
                state.zoomGesture = value.magnification

                // Live anchor compensation. `scaleEffect` is anchored at
                // .topLeading; without adjusting pan in lockstep, the canvas
                // point under the cursor drifts away as we scale. Compute the
                // pan offset that keeps the canvas-under-anchor pinned, write
                // it to `zoomPanCompensation` so `effectivePan` picks it up.
                if let anchor = state.zoomAnchorScreen {
                    let newZoom = max(0.2, min(3.0, state.zoom * value.magnification))
                    let canvasUnderAnchor = CGPoint(
                        x: (anchor.x - state.pan.width) / state.zoom,
                        y: (anchor.y - state.pan.height) / state.zoom
                    )
                    state.zoomPanCompensation = CGSize(
                        width: anchor.x - canvasUnderAnchor.x * newZoom - state.pan.width,
                        height: anchor.y - canvasUnderAnchor.y * newZoom - state.pan.height
                    )
                }
            }
            .onEnded { _ in
                state.commitZoom()
            }
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture(count: 1)
            .onEnded { value in
                handleBackgroundTap(at: value.location)
            }
    }

    /// Long-press → context menu (primarily used on iOS, where there's no keyboard
    /// delete available unless an external keyboard is attached). The
    /// `LongPressGesture.sequenced(before: DragGesture)` form is the standard
    /// SwiftUI trick for getting the press *location* — vanilla `LongPressGesture`
    /// doesn't expose one.
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                if case .second(true, let drag) = value, let drag = drag {
                    handleLongPress(at: drag.location)
                }
            }
    }

    // MARK: - Tap & long-press handling

    private func handleBackgroundTap(at screenLocation: CGPoint) {
        // Reclaim focus on each canvas tap — a previous click into an inline
        // value editor (TextField) would have moved focus there, and the
        // canvas must regain focus for `.onKeyPress` to fire again on iOS.
        isFocused = true
        if let edge = nearestEdge(toScreen: screenLocation, threshold: 14) {
            if commandIsHeld {
                if state.selectedEdges.contains(edge) {
                    state.selectedEdges.remove(edge)
                } else {
                    state.selectedEdges.insert(edge)
                }
            } else {
                state.selection.removeAll()
                state.selectedEdges = [edge]
            }
        } else if !commandIsHeld {
            // Cmd-click on empty canvas preserves selection so the user can
            // build a multi-selection across several clicks without losing it.
            state.selection.removeAll()
            state.selectedEdges.removeAll()
        }
    }

    private func handleLongPress(at screenLocation: CGPoint) {
        if let edge = nearestEdge(toScreen: screenLocation, threshold: 18) {
            state.selectedEdges = [edge]
            contextMenuEdge = edge
        }
    }

    /// Sample every visible edge and return the single nearest one within `threshold`
    /// screen-space points. Distances are computed in canvas space, scaled by 1/zoom
    /// so the threshold maps to a constant on-screen target regardless of zoom.
    private func nearestEdge(toScreen screen: CGPoint, threshold: CGFloat) -> EdgeRef? {
        let canvasPoint = state.canvasPoint(fromScreen: screen)
        let canvasThreshold = threshold / state.effectiveZoom
        let edges = graph.resolvedEdges(anchors: state.portAnchors)
        var best: (EdgeRef, CGFloat)?
        for edge in edges {
            let d = ConnectionPath.distance(from: canvasPoint, toCurveFrom: edge.source, to: edge.target)
            if d <= canvasThreshold, best.map({ d < $0.1 }) ?? true {
                best = (edge.ref, d)
            }
        }
        return best?.0
    }

    // MARK: - Selection

    private func selectNode(_ id: UUID, additive: Bool) {
        state.selectedEdges.removeAll()
        if additive {
            if state.selection.contains(id) {
                state.selection.remove(id)
            } else {
                state.selection.insert(id)
            }
        } else {
            state.selection = [id]
        }
    }

    private func deleteSelection() {
        // Edges first — they're tracked independently of node selection so we
        // don't care which order, but it's nice for the disconnect to land
        // before any node delete that would otherwise prune the same edge.
        for edge in state.selectedEdges {
            graph.disconnect(source: edge.source, target: edge.target)
        }
        state.selectedEdges.removeAll()

        if !state.selection.isEmpty {
            graph.delete(nodeIDs: state.selection)
            state.selection.removeAll()
        }
    }

    // MARK: - Scroll-wheel routing (macOS)

    #if os(macOS)
    private func handleScrollWheel(_ event: NSEvent) {
        // `phase` is set for trackpad / Magic Mouse gestures and empty for
        // discrete scroll wheels; `momentumPhase` continues to fire after a
        // trackpad fling — also panning, not zooming.
        //
        // Cmd-held overrides the default — cmd+scroll zooms regardless of
        // device, the same convention as Figma / Sketch. That's how Magic
        // Mouse users get zoom (its swipes are indistinguishable from a
        // trackpad's at the NSEvent layer).
        let isGesture = !event.phase.isEmpty || !event.momentumPhase.isEmpty
        if commandIsHeld {
            applyScrollZoom(deltaY: event.scrollingDeltaY, at: pointerStore.location)
        } else if isGesture {
            state.pan.width += event.scrollingDeltaX
            state.pan.height += event.scrollingDeltaY
        } else {
            applyScrollZoom(deltaY: event.scrollingDeltaY, at: pointerStore.location)
        }
    }

    private func applyScrollZoom(deltaY: CGFloat, at cursor: CGPoint) {
        let oldZoom = state.zoom
        let factor = exp(deltaY * 0.05)
        let newZoom = max(0.2, min(3.0, oldZoom * factor))
        guard newZoom != oldZoom else { return }
        // Hold the canvas point under the cursor fixed across the zoom by
        // adjusting pan to compensate (same trick as commitZoom).
        let canvasUnderCursor = CGPoint(
            x: (cursor.x - state.pan.width) / oldZoom,
            y: (cursor.y - state.pan.height) / oldZoom
        )
        state.pan.width = cursor.x - canvasUnderCursor.x * newZoom
        state.pan.height = cursor.y - canvasUnderCursor.y * newZoom
        state.zoom = newZoom
    }
    #endif

    // MARK: - Drop

    private func handleDrop(items: [TemplateDragPayload], screenLocation: CGPoint) {
        for item in items {
            guard let template = templateRegistry.registeredNodeTemplate(with: item.templateKindID) else { continue }
            // Singleton templates (`reusable == false`) refuse a second
            // instance per graph. Drops onto an already-present singleton
            // are silently ignored; the user sees no node appear.
            if !template.reusable,
               graph.nodes.contains(where: { $0.templateIdentifier == template.kind.id }) {
                continue
            }
            let canvasPoint = state.canvasPoint(fromScreen: screenLocation)
            let newNode = Node(
                id: UUID(),
                templateIdentifier: template.kind.id,
                position: Point(canvasPoint),
                outgoingConnectionsByPortIdentifier: [:]
            )
            graph.nodes.append(newNode)
            state.selection = [newNode.id]
            state.selectedEdges.removeAll()
        }
    }
}
