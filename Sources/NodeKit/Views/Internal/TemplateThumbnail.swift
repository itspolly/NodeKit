//
//  TemplateThumbnail.swift
//  NodeKit
//
//  Created by Jamie on 06/05/2026.
//

import SwiftUI

/// Compact, non-interactive preview of a `NodeTemplate` for the template
/// browser. Visual hierarchy intentionally matches `NodeView` (same min-width,
/// fonts, port-circle size, corner radius, padding) so dragging a thumbnail
/// onto the canvas doesn't visibly resize on landing.
struct TemplateThumbnail: View {
    let template: NodeTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(alignment: .top, spacing: 16) {
                portsColumn(template.inputs, alignment: .leading)
                Spacer(minLength: 24)
                portsColumn(template.outputs, alignment: .trailing)
            }
            .padding(.vertical, 8)
        }
        .frame(minWidth: NodeStyle.minWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NodeStyle.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .shadow(color: .accentColor.opacity(0.7), radius: 4)
            Text(template.kind.localizedDisplayName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.55),
                         Color.accentColor.opacity(0.25)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    @ViewBuilder
    private func portsColumn(
        _ ports: [NodeTemplate.Port],
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            ForEach(ports) { port in
                portRow(port: port, alignment: alignment)
            }
        }
    }

    @ViewBuilder
    private func portRow(
        port: NodeTemplate.Port,
        alignment: HorizontalAlignment
    ) -> some View {
        let isLeft = (alignment == .leading)
        HStack(spacing: 8) {
            if !isLeft {
                Text(port.localizedDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            Circle()
                .fill(.background.opacity(0.6))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
                .frame(width: NodeStyle.portCircleSize, height: NodeStyle.portCircleSize)
            if isLeft {
                Text(port.localizedDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 6)
        .offset(x: isLeft ? -NodeStyle.portCircleSize / 2 - 6
                          : NodeStyle.portCircleSize / 2 + 6)
    }
}
