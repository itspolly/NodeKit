//
//  PointerLocationStore.swift
//  NodeKit
//
//  Created by Jamie on 24/05/2026.
//

import CoreFoundation

/// Holds the latest hovered cursor point as plain mutable state. Used by
/// ``GraphCanvas`` so the high-frequency `.onContinuousHover` writes don't
/// invalidate the view (which a bare `@State CGPoint` would). The hover point
/// is write-only from SwiftUI's perspective — only the scroll-wheel zoom
/// handler reads it — so observation-driven view rebuilds add nothing but
/// cost and (importantly) destabilise the `.dropDestination`'s view identity
/// during the drag-image animation, triggering an AppKit drop-replay.
final class PointerLocationStore {
    var location: CGPoint = .zero
}
