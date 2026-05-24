//
//  GraphGeometry.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import CoreGraphics
import SwiftUI

extension Point {
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    init(_ p: CGPoint) { self.init(x: Double(p.x), y: Double(p.y)) }
}

/// Visual constants shared between `NodeView` and `TemplateThumbnail`. Anything
/// that needs to vary with content (height, exact width) is left to SwiftUI's
/// natural layout — this just pins the minimum width so small nodes don't look
/// scrawny and matches port hit-target sizes across the two surfaces.
enum NodeStyle {
    static let minWidth: CGFloat = 220
    static let portCircleSize: CGFloat = 14
    static let portHitInset: CGFloat = 8
    static let cornerRadius: CGFloat = 18
}

extension NodeTemplate.Port.Kind {
    var isInput: Bool { self == .input }
    var isOutput: Bool { self == .output }
}

/// A coordinate space name shared between gestures and rendering inside the canvas content.
let canvasCoordinateSpace = "NodeKit.canvas"
