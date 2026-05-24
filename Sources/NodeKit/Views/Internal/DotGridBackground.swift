//
//  DotGridBackground.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

struct DotGridBackground: View {
    let pan: CGSize
    let zoom: CGFloat

    private let baseSpacing: CGFloat = 24

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            // Pick a spacing that stays visually pleasant as the user zooms in or out.
            // We hop in powers of two so the grid never gets too dense / sparse.
            var spacing = baseSpacing * zoom
            while spacing < 16 { spacing *= 2 }
            while spacing > 64 { spacing /= 2 }

            let dotRadius: CGFloat = max(0.6, min(2.0, 1.1 * zoom))
            let phaseX = pan.width.truncatingRemainder(dividingBy: spacing)
            let phaseY = pan.height.truncatingRemainder(dividingBy: spacing)

            let color = Color.primary.opacity(0.18)
            var x = phaseX - spacing
            while x < size.width + spacing {
                var y = phaseY - spacing
                while y < size.height + spacing {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                      width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
