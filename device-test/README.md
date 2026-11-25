# Collapse RPG device test (Godot 4.7.2)

The "week-one stress scene" from `design/chapters/tech.md` and `art.md`. It is a performance test, not game content: the art is gray-box placeholder drawn at the planned sizes, counts and texture format, so the phone does the same work the real art would ask of it.

## Install on the Pixel (about 5 minutes)

There are two apps. They install side by side and differ only in the graphics path.

- `collapse-device-test-opengl.apk` shows as **Collapse Test GL**. This is the plan's default (Compatibility renderer, OpenGL ES 3).
- `collapse-device-test-vulkan.apk` shows as **Collapse Test Vulkan**. This is the plan's fallback (Mobile renderer, Vulkan).

1. On the Pixel, download both APK files from the project's Library (or copy them over USB into Downloads).
2. Open the **Files** app, go to **Downloads**, and tap the first APK.
3. If Android says installs from this source are not allowed, tap **Settings**, turn on **Allow from this source**, and go back.
4. Tap **Install**. If Google Play Protect warns that the app is unknown, tap **More details** and then **Install anyway** (it is a debug build signed with a throwaway test key).
5. Repeat for the second APK.

To remove them later: long-press the icon and choose **Uninstall**.

## Run the test (about 3 minutes per app)

1. Charge the phone to at least 50%, then **unplug it**. Close other apps. Set it flat on a table at room temperature, not in your hand or a case pocket.
2. Open **Collapse Test GL** and turn the phone sideways.
3. Tap **Run 3-min test** (top right) and do not touch the screen. It runs five stages: the plan scene (12 characters, 4 of them layered family sprites, 12 lights, rain, night), the same at 0.67 render scale, a heavy version (24 characters, 24 lights), uncapped frame rate, and the battle screen.
4. When the report appears, tap **Copy report** and paste it into the project thread.
5. Do the same with **Collapse Test Vulkan**.

Optional, after the two quick runs: in the better of the two apps, open **Settings > 60-min soak test**, leave the phone unplugged and on the table for an hour, then copy that report too. This is the plan's heat and battery check.

While you are in there, it also helps to say in a sentence whether dragging, pinch zoom, the Battle button and tapping to move or shoot all worked, and whether anything looked broken.

## What the numbers mean

Pass lines come from `tech.md` (the RAM, texture and battery lines are still labelled hypotheses there):

| Reading | Pass |
|---|---|
| Stage A fps | 30 or more; 60 is the target |
| Stage A "slow>33ms %" | under 25% |
| RAM | 1,500 MB or less |
| Textures | 384 MB or less |
| Heat | stays "none" or "light"; no "SEVERE" |
| Battery (soak) | under 10% per hour |

If the report cannot be copied, the key numbers are stage A's fps, p99 ms, slow>33ms %, RAM, textures, heat and battery %/h.

## What it covers and what it does not

Covered: 64x64 diamond tile map of 128x64 tiles, about 370 props, 160 px characters with 8 facings and colour plus normal sheets, stacked family layers with a skin-ramp shader, normal-mapped point lights with flicker, night grade, 1,600 rain particles, ASTC textures, the 0.67 world render scale, a turn-based battle mock (AP, move range, hit chance, enemy turns, muzzle-flash lights), the interface at 48 dp targets and 16 sp text, save and load of a mid-game-sized state (compressed binary and JSON), autosave when the app is paused, and on-screen FPS, frame-time, memory, battery and thermal readouts.

Not covered: real art (overdraw and atlas count will change), audio, dialogue, pathfinding for many actors at once, and the 8 GB laptop floor (a Windows or Linux build of this scene is a quick follow-up).

## Rebuild

`tools/export_android.sh` regenerates the art, imports and exports both APKs. It needs Godot 4.7.2 with Android export templates, Java, `apksigner`, and a debug keystore in Godot's editor settings. The `.import` files beside the art set ASTC compression and mark the `_n` sheets as normal maps.

Agent check without a phone: `godot --path . -- --fast-bench` runs every stage for 6 seconds and writes the report to the user data folder; `-- --shot=/path.png` and `-- --battle` take screenshots.
