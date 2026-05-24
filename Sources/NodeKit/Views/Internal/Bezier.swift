//
//  Bezier.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

enum ConnectionPath {
    /// Returns a horizontal-tangent cubic bezier between two points.
    /// The control offset grows with distance so long links arc gracefully and
    /// short links stay tight.
    static func path(from start: CGPoint, to end: CGPoint) -> Path {
        let (c1, c2) = controlPoints(from: start, to: end)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: c1, control2: c2)
        return path
    }

    /// Approximate minimum distance from `point` to the bezier between `start`
    /// and `end`. Samples the curve into 32 segments and walks point-to-segment
    /// distance — enough resolution for a 14pt finger target without the
    /// overlap pathology of fat invisible hit shapes.
    static func distance(from point: CGPoint, toCurveFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let (c1, c2) = controlPoints(from: start, to: end)
        let segments = 32
        var prev = start
        var minDist = CGFloat.infinity
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let next = bezierPoint(t: t, p0: start, c1: c1, c2: c2, p3: end)
            let d = pointToSegmentDistance(point, prev, next)
            if d < minDist { minDist = d }
            prev = next
        }
        return minDist
    }

    private static func controlPoints(from start: CGPoint, to end: CGPoint) -> (CGPoint, CGPoint) {
        let dx = max(40, abs(end.x - start.x) * 0.5)
        return (
            CGPoint(x: start.x + dx, y: start.y),
            CGPoint(x: end.x - dx, y: end.y)
        )
    }

    private static func bezierPoint(t: CGFloat, p0: CGPoint, c1: CGPoint, c2: CGPoint, p3: CGPoint) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let t2 = t * t
        let x = mt2 * mt * p0.x + 3 * mt2 * t * c1.x + 3 * mt * t2 * c2.x + t2 * t * p3.x
        let y = mt2 * mt * p0.y + 3 * mt2 * t * c1.y + 3 * mt * t2 * c2.y + t2 * t * p3.y
        return CGPoint(x: x, y: y)
    }

    private static func pointToSegmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let len2 = abx * abx + aby * aby
        if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2
        t = max(0, min(1, t))
        let cx = a.x + abx * t
        let cy = a.y + aby * t
        return hypot(p.x - cx, p.y - cy)
    }
}
