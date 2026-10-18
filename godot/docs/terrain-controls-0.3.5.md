# MetroForge 0.3.5: persistent terrain controls

Terrain settings moved out of the Terraform submenu into a compact map panel
on the right. Select Raise, Lower, Flatten or Shape terrain to show it. Closing
the submenu, changing placement mode or browsing another category leaves the
active terrain settings available. Selecting Pan or another tool hides them.

The panel shows only relevant controls: height step for Raise/Lower; brush;
shape and optional slope direction/strength; or Flatten target and explicit
height. Brush size is a dropdown to keep the panel narrow. Changes use the
existing transaction/preview settings, with no cost or map edit until actual
construction. Terrain rules, saves, growth and simulation are unchanged.

The 156-pixel logical panel overlays the map above FPS and camera controls.
The tool palette adjusts its columns to fit beside it, including 640×360.
It never reserves additional map height. Flat settings shrink automatically
when slope controls are hidden.

Verification: all 19 native suites passed with
`python godot/tools/check_project.py`. Terrain controls include 93 checks,
covering persistence after menu closure, live dropdown/height updates,
actual GUI button clicks without painting behind them, menu/panel separation,
map bounds, narrow-screen layout and existing gesture/Undo behavior.

`tools/preview_terrain_shapes.gd` produces actual native captures of the open
menu, closed-menu settings, Raise controls and narrow landscape layout.
Cached/full terrain pixels match; the volatile FPS label is suspended only
while making that deterministic raster comparison. These desktop captures do
not measure Android FPS. No source artwork changed.

Phone checks:

1. Select Raise terrain. Close Terraform; change Step, Brush and Shape from
   the right-side panel, then place terrain and Undo/Redo it.
2. Select Sloped and change High edge/Strength without opening the menu.
3. Select Flatten and switch between First tile and Set height.
4. Open Terraform while settings are visible; all tools and settings should
   stay accessible side by side. Pan or a construction tool hides settings.
5. Confirm touching settings never edits the map, and FPS/zoom remain clear.

The separate 0.3.5 Terrain Controls test APK preserves the package name,
uses versionCode6, and does not overwrite earlier releases. Export your city
before changing installations: the unchanged CI test-signing fallback can
generate a different certificate, requiring uninstall/reinstall on Android.
