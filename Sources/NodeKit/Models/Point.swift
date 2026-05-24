//
//  Point.swift
//  NodeKit
//
//  Created by Jamie on 05/05/2026.
//

/// A two-dimensional point in editor coordinates.
///
/// Used as a `Codable` value type so positions round-trip with the rest of the
/// graph. Equivalent in shape to `CGPoint` but available on every platform
/// NodeKit supports and free of `CoreGraphics`-driven `Sendable` caveats.
public struct Point: Sendable, Codable {
    /// Horizontal coordinate, in editor points. Increases to the right.
    public let x: Double

    /// Vertical coordinate, in editor points. Increases downward, matching the
    /// SwiftUI coordinate space.
    public let y: Double

    /// Create a point.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
