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

Remaining before closing P0:

- Apply and restore a test wallpaper in a desktop session where changing the
  current wallpaper is authorized. Confirm the image visually and verify the
  previous wallpaper returns. The live smoke check left the wallpaper in place.
- With snow on, confirm flakes are visible, desktop clicks reach items beneath
  them, windows stay above them, a different Space behaves correctly, and a
  fullscreen app covers them. The smoke check confirmed the renderer's running
  state, not visual compositor ordering.
- Lock/unlock and sleep/wake. Verify rendering stops during lock/sleep and comes
  back only if Snow was enabled. The prototype uses the public workspace
  notifications plus a macOS lock notification whose delivery needs testing.
