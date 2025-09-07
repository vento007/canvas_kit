## 0.5.1 - 2025-09-07

Initial public preview of Canvas Kit.

- New widget: `CanvasKit` (formerly InfiniteCanvas)
- Controller: `CanvasKitController` with programmatic pan/zoom helpers
- Items: `CanvasItem` with world and viewport anchoring, `lockZoom`, `estimatedSize`
- Layers: `backgroundBuilder` and `foregroundLayers` receive live `Matrix4` transform
- Modes: `InteractionMode.interactive` and `InteractionMode.programmatic` (with `gestureOverlayBuilder`)
- Optional world `bounds` with auto-fit and boundary constraints
- Example app with multiple demos (interactive, programmatic, bounds, node editor, snake, parallax)
