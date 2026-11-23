# Stillroom P0

Native macOS prototype for FE-03 and FE-05 in the [product specs](../docs/SPECS.md).
Run from the project root with Xcode or its command-line tools installed:

```sh
P0/build.sh
open 'P0/build/Stillroom P0.app'
```

Use **Apply wallpaper** to set the bundled, original Salt Marsh image on the
primary display. **Restore previous** can undo the change during the same run
when macOS provided the previous image URL and the desktop still uses Salt Marsh.
Keep the built app in place while using its bundled image as wallpaper.
**Snow** controls a separate, click-through desktop window. Closing the
prototype window or using Cmd-Q stops rendering and exits.

## P0 verification

Verified on macOS 26.7.3, Apple silicon:

- Swift 6 build, local code signature, and bundled 1920 × 1080 image.
- The native control window opens with an image preview. Snow reports Off on
  launch and Running on the built-in Retina display when enabled. Repeating
  Off → On updates the runtime state.
- Closing the control window while snow is running exits the process. The first
  test caught the overlay keeping the app alive; the fix was retested.

Manual P0 acceptance was reported as passing by the project owner on
23 November 2026: apply/restore wallpaper, visible and click-through snow
across Spaces and fullscreen, and lock/unlock plus sleep/wake. The automated
smoke check above covered startup, toggle state, and teardown.
