//
//  GraphEditorState.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class GraphEditorState {
    // Viewport (canvas → screen): screen = canvas * zoom + pan
    var pan: CGSize = .zero
    var zoom: CGFloat = 1.0

    // Live gesture deltas — applied on top of pan/zoom while a gesture is active.
    var panGesture: CGSize = .zero
    var zoomGesture: CGFloat = 1.0
    var zoomAnchorScreen: CGPoint? = nil
    /// Live pan offset applied during a pinch so the canvas point under the
    /// anchor stays put as the canvas scales. Without this the canvas appears
    /// to drift during the gesture (scaleEffect anchored at .topLeading) and
    /// only snaps back when the gesture ends — reads as a jumpy zoom. Reset
    /// by `commitZoom` after the delta is folded into `pan`.
    var zoomPanCompensation: CGSize = .zero

    // Selection
    var selection: Set<UUID> = []
    var selectedEdges: Set<EdgeRef> = []

    // Per-node drag tracking (canvas-coord deltas applied while dragging)
    var nodeDragStart: [UUID: CGPoint] = [:]
    var nodeDragOffset: CGSize = .zero
    var nodeDragInProgress: Bool = false

    // Port positions (in canvas coordinates), published by node views via
    // preference keys. Keyed by `Node.PortReference` (not bare port id) because
    // port ids are template-scoped — two nodes of the same template would
    // otherwise share a key and one anchor would clobber the other.
    var portAnchors: [Node.PortReference: PortAnchor] = [:]

    /// Default values + inline editor views for each registered port type.
    /// Injected by `GraphEditor` at construction.
    let portEditorRegistry: PortEditorRegistry

    /// Catalogue used by the editor to resolve a port's
    /// ``NodeTemplate/Port/typeIdentifier`` back to a ``PortType`` for
    /// rendering hints (colour, display name). Injected by `GraphEditor` at
    /// construction.
    let portTypeRegistry: PortTypeRegistry

    init(
        portTypeRegistry: PortTypeRegistry,
        portEditorRegistry: PortEditorRegistry
    ) {
        self.portTypeRegistry = portTypeRegistry
        self.portEditorRegistry = portEditorRegistry
    }

    // In-flight new connection
    struct PendingConnection: Equatable {
        var source: Node.PortReference
        var sourceKind: NodeTemplate.Port.Kind
        var sourceCanvas: CGPoint
        var pointerCanvas: CGPoint
        var hover: PortAnchor?
    }
    var pendingConnection: PendingConnection?

    // Effective transform values (combining committed + live gesture)
    var effectivePan: CGSize {
        CGSize(
            width: pan.width + panGesture.width + zoomPanCompensation.width,
            height: pan.height + panGesture.height + zoomPanCompensation.height
        )
    }

    var effectiveZoom: CGFloat {
        max(0.2, min(3.0, zoom * zoomGesture))
    }

    func canvasPoint(fromScreen screen: CGPoint) -> CGPoint {
        let z = effectiveZoom
        let p = effectivePan
        return CGPoint(x: (screen.x - p.width) / z,
                       y: (screen.y - p.height) / z)
    }

    func screenPoint(fromCanvas canvas: CGPoint) -> CGPoint {
        let z = effectiveZoom
        let p = effectivePan
        return CGPoint(x: canvas.x * z + p.width,
                       y: canvas.y * z + p.height)
    }

    func commitPan() {
        pan.width += panGesture.width
        pan.height += panGesture.height
        panGesture = .zero
    }

    func commitZoom() {
        // The live `magnifyGesture` already kept the anchor pinned via
        // `zoomPanCompensation`; commit just folds the live deltas into the
        // committed pan/zoom.
        zoom = max(0.2, min(3.0, zoom * zoomGesture))
        pan.width += zoomPanCompensation.width
        pan.height += zoomPanCompensation.height
        zoomGesture = 1.0
        zoomPanCompensation = .zero
        zoomAnchorScreen = nil
    }
}
