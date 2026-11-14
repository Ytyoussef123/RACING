# Design decisions

## View: 3D low-poly, fixed angled camera (decided Phase 1, 2026-11-14)

- 3D scene with a fixed camera about 55° above the pitch, looking along the long side and following the ball with a little lag.
- **Why not 2D isometric sprites:** the ball needs real height (lobs, chips, headers, bounces off cage walls). In 2D, height is faked and wall bounces and lobs feel wrong. Sprites also need every animation drawn for 8 directions, which is far more art than one low-poly rigged model.
- **Performance:** the court is small and flat, with 10 players, few lights and baked or blob shadows, so it stays light on mid-range phones.
- Gameplay logic runs on the ground plane (x, z), with height only for the ball. That keeps the AI simple and makes later online sync easier.

## Renderer: Compatibility (OpenGL ES 3)

- Chosen over "Mobile" (Vulkan) because it runs on the widest range of Android phones, including mid-range GPUs with weak Vulkan drivers.
- Lesson from the other game in this repository (Corniche Rush): the user's phone rejected custom shaders that emulators accepted. Keep shaders simple and test every visual change on the real phone.

## Screen

- Base resolution 1920×1080, stretch mode `canvas_items` + aspect `expand`: the UI scales to any phone and wider screens just show more.
- Orientation `sensor_landscape`: both landscape directions are allowed.

## Numbers in data

- Every tuning value is in `data/config/*.json`, loaded by the `Config` autoload (`scripts/core/config.gd`). The `FrameRate` autoload applies `performance.json`.
- The export preset includes `*.json` (Godot does not export non-resource files by default).
