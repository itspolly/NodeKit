//
//  ScrollWheelCatcher.swift
//  NodeKit
//
//  Created by Jamie on 23/05/2026.
//

#if os(macOS)
import AppKit
import SwiftUI

/// Captures `NSEvent.scrollWheel` events while the cursor is over our view so
/// the canvas can pan (two-finger trackpad gestures) and zoom (discrete scroll
/// wheels) without depending on SwiftUI gestures, which never see these events.
///
/// Uses `NSEvent.addLocalMonitorForEvents` rather than overriding `scrollWheel`
/// on an NSView subclass: a subclass needs the cursor to hit-test directly to
/// it, but SwiftUI's hosting view consumes hit-tests for everything above it,
/// so the subclass never ran. A monitor sees every scroll event the app
/// receives and lets us claim the ones that geometrically land on our frame.
struct ScrollWheelCatcher: NSViewRepresentable {
    let onEvent: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.bind(to: view, onEvent: onEvent)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onEvent = onEvent
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        // Tear the monitor down on main while the coordinator is still around
        // — relying on `deinit` would either need `nonisolated(unsafe)` (racey
        // against a re-entrant `bind`) or `isolated deinit` (newer Swift).
        // `dismantleNSView` is `@MainActor` so this is straightforwardly safe.
        coordinator.tearDown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var onEvent: (NSEvent) -> Void = { _ in }
        private var monitor: Any?
        private weak var view: NSView?

        func bind(to view: NSView, onEvent: @escaping (NSEvent) -> Void) {
            self.view = view
            self.onEvent = onEvent
            self.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                // AppKit delivers local monitor callbacks on the main thread,
                // so the @MainActor view/window access here is safe — assert
                // isolation so the compiler agrees. We can't return NSEvent
                // from `assumeIsolated` (it's not Sendable), so use a flag and
                // decide whether to consume back in the nonisolated context.
                var consume = false
                MainActor.assumeIsolated {
                    guard
                        let self,
                        let v = self.view,
                        let window = v.window,
                        event.window === window
                    else { return }
                    let local = v.convert(event.locationInWindow, from: nil)
                    guard v.bounds.contains(local) else { return }
                    self.onEvent(event)
                    consume = true
                }
                return consume ? nil : event
            }
        }

        func tearDown() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
            view = nil
        }
    }
}
#endif
