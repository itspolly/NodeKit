# SwiftUI `.draggable` → `.dropDestination` drops are replayed after the fact on macOS 26

## Summary

On macOS 26, a SwiftUI drop landed via `.dropDestination(for: Transferable.self)`
is delivered correctly once, then *re-fired* on any subsequent mouse-up
inside the same drop-target view — with the cached drop's Y coordinate and a
freshly-sampled cursor X. The drop callback runs again, the `Transferable`
items are the same as the previous real drop, and the host app sees a
phantom duplicate of whatever the user most-recently dragged. The user did
not initiate a new drag.

This does not reproduce on iPadOS 26 with the same SwiftUI source.

## Environment

- macOS 26.0
- Xcode 26.0
- Swift 6.3
- Reproduces in SwiftUI on the macOS target only. iPadOS / iOS / visionOS
  builds of the same SwiftUI code are unaffected.

## Steps to reproduce

1. Build and run the minimal reproducer (below) on macOS 26.
2. Drag the "Source" row from the left sidebar onto the gray canvas. A
   green node appears at the drop location — this is correct.
3. Without dragging anything, **click anywhere else on the canvas**.
4. A duplicate of "Source" appears at the click location.

Repeated clicks on the canvas keep producing duplicate "Source" nodes
indefinitely. The cached payload is never released. The duplicates'
**Y coordinates match the original drop's Y to seven decimal places** —
this is the distinguishing signature; the X is the cursor's current X at
the time of the spurious click.

If a second real drag-and-drop is performed (e.g. drag "Sink"), subsequent
canvas clicks then produce duplicates of "Sink" instead. The most-recent
real drag's payload is the one that gets replayed.

## Expected behavior

After `.dropDestination`'s action closure returns `true`, the drag session
should be considered concluded by AppKit (`concludeDragOperation`). A
subsequent unrelated `mouseUp` on the destination view should not invoke
the drop callback.

## Actual behavior

`.dropDestination`'s action closure is invoked on the spurious `mouseUp`,
receiving the previously-dropped `Transferable` payload(s) again, with
the cached drop location's Y and the live cursor X. The host has no way
to tell a real drop from a replayed one from the closure alone — both
arrive with `items` populated and a valid `CGPoint location`.

## Identifying signature for verification

The Y coordinate of the spurious drop matches the Y of the *most recent
real* drop bit-for-bit (verified to seven decimal places of
`CGFloat`/`Double` print precision):

```
real:    location=(159.00390625, 135.421875)
replay:  location=(158.5390625,  135.421875)
                                ^^^^^^^^^^ identical
```

Real human-initiated drops at "the same Y" have at least sub-pixel
floating-point jitter on both axes; identical-to-the-bit Y between two
events is a reliable diagnostic that the second is a replay.

## Investigations that did *not* fix it

For Apple's reference — we ruled these out in the field before resorting
to the AppKit-direct workaround:

| Hypothesis | What was tried | Result |
| --- | --- | --- |
| Drag-preview snapshot failing | Replaced custom preview view with a minimal opaque `Text` on `Color.blue` + `.fixedSize().compositingGroup()` (no materials, no `.opacity()`, no `Color.accentColor`) | Bug persists |
| Async Transferable resolution race | Replaced `CodableRepresentation` with `ProxyRepresentation` (synchronous in-process) | Bug persists |
| Drag-source cell identity churn | Extracted cell into a stable `View` struct keyed on the (`Equatable`) model | Bug persists |
| State mutation during the drop callback | Wrapped the `Transferable`-driven mutation in `Task { @MainActor in … }`, returning `true` from the action immediately so AppKit can run `concludeDragOperation` cleanly first | Bug persists |
| Drop-target view invalidating during the drag-image animation | Replaced a hover-tracked `@State CGPoint` (written by `.onContinuousHover` on every mouse-move) with a reference-type holder so the writes don't trigger SwiftUI view rebuilds | Bug persists |
| Bridge layer of `.dropDestination` specifically | Switched the destination to the older `.onDrop(of: [.utType], isTargeted: nil) { providers, location in … }` API | Bug persists (same bridge) |
| Destination bridge generally | Replaced `.dropDestination` with `NSViewRepresentable` over `NSView.draggingDestination` (own `performDragOperation` / `concludeDragOperation`) | Bug persists |

The bug rides through both bridges and through the bare `NSView` drop
destination, which strongly suggests it lives upstream of the destination
side — i.e. in how `.draggable`'s drag session is registered or torn down
on the source side.

## Confirmed mitigation

Replacing the *source* side as well — `.draggable` swapped for an
`NSViewRepresentable` hosting the SwiftUI cell inside an `NSView` that
owns `mouseDown` → `mouseDragged` → `beginDraggingSession(with:event:source:)`
directly — eliminates the replay completely. Both source and destination
must come off SwiftUI's drag bridge on macOS for the issue to disappear.

That is not a viable fix for most apps. It involves manually managing
`NSDraggingItem`, drawing a drag image in Core Graphics (SwiftUI snapshots
in the isolated drag-preview context are their own ongoing source of
trouble — materials snapshot blank, layouts don't complete in time), and
forking the entire drag pipeline per-platform.

## Minimal reproducer

Single-file SwiftUI macOS app. Drop into a fresh Xcode project's `App`
file and run on macOS 26.

```swift
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag payload

extension UTType {
    static let dragdropbugItem = UTType(exportedAs: "com.example.dragdropbug.item")
}

struct Item: Codable, Transferable, Hashable {
    let id: UUID
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .dragdropbugItem)
    }
}

// MARK: - App

@main
struct DragDropBugApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 500)
        }
    }
}

// MARK: - View

struct ContentView: View {
    @State private var drops: [(item: Item, location: CGPoint)] = []
    private let palette: [Item] = [
        Item(id: UUID(), name: "Source"),
        Item(id: UUID(), name: "Process"),
        Item(id: UUID(), name: "Sink"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .background(.background.tertiary)
            canvas
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drag onto the canvas →")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(palette, id: \.id) { item in
                Text(item.name)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 6))
                    .draggable(item)
            }
            Spacer()
        }
        .padding()
    }

    private var canvas: some View {
        ZStack {
            Color.gray.opacity(0.08)
            ForEach(Array(drops.enumerated()), id: \.offset) { _, drop in
                Text(drop.item.name)
                    .padding(8)
                    .background(Color.green.opacity(0.7),
                                in: RoundedRectangle(cornerRadius: 6))
                    .position(drop.location)
            }
        }
        .dropDestination(for: Item.self) { items, location in
            for item in items {
                drops.append((item, location))
                print("drop \(item.name) @ \(location)")
            }
            return true
        }
    }
}
```

**Expected console output** when the user performs one real drag of
"Source" and then clicks the canvas three times:

```
drop Source @ (245.0, 137.0)        ← real
```

(no further output)

**Actual console output:**

```
drop Source @ (245.0, 137.0)        ← real
drop Source @ (312.5, 137.0)        ← replay (note identical Y)
drop Source @ (98.7,  137.0)        ← replay (note identical Y)
drop Source @ (411.2, 137.0)        ← replay (note identical Y)
```

The Y coordinate of every replayed drop matches the real drop bit-for-bit.

## Notes

- The pattern survives across multiple real drags: a second real drag
  resets the cached payload to the newer one, after which canvas clicks
  produce duplicates of the *newer* payload at the newer drag's Y.
- The replay is not user-triggerable in any deliberate sense; users
  discover it by clicking on the canvas to interact with what they
  already dropped.
- This impacts any SwiftUI app that uses `.draggable` →
  `.dropDestination` on macOS where the drop target is also a normal
  interactive surface (canvases, editors, document workspaces). The
  workaround cost (full `NSView` source + destination) is high enough
  that we expect most affected apps to ship with the bug.
