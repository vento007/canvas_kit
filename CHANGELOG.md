## 0.5.3 - 2025-12-12

Performance and rendering improvements:
- Reduce rebuilds during drag by rebuilding only on transform changes (`CanvasKitController.transformRevision`)
- World-space culling (avoid per-item world→screen math/allocs)
- Render world-anchored items under a single world `Transform` for fewer per-item transforms
- Bounds grid background draws only visible grid lines (big savings for large bounds)

API additions:
- `CanvasKit.onRenderStats` callback with `CanvasKitRenderStats` for culling/viewport visibility stats

## 0.5.2 - 2025-09-14

Metadata updates:
- pubspec: add topics (flutter, canvas, pan-and-zoom, infinite-canvas, graphics) for better pub.dev discoverability
- chore: bump patch version to 0.5.2

## 0.5.1+1 - 2025-09-08

Docs and publishing fixes:
- README: switch logo and demo GIF to raw GitHub URLs so they render on pub.dev
- README: add "Quick Demo" section and badges/header tweaks

## 0.5.1 - 2025-09-07

Initial public preview of Canvas Kit.

- New widget: `CanvasKit` (formerly InfiniteCanvas)
- Controller: `CanvasKitController` with programmatic pan/zoom helpers
- Items: `CanvasItem` with world and viewport anchoring, `lockZoom`, `estimatedSize`
- Layers: `backgroundBuilder` and `foregroundLayers` receive live `Matrix4` transform
- Modes: `InteractionMode.interactive` and `InteractionMode.programmatic` (with `gestureOverlayBuilder`)
- Optional world `bounds` with auto-fit and boundary constraints
- Example app with multiple demos (interactive, programmatic, bounds, node editor, snake, parallax)
