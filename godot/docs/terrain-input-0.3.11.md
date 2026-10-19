# MetroForge 0.3.11 — typed terrain height controls

Mountain, Hill, Raise and Flatten use the same shared elevation range, -5 to+30.
The Mountain default stays12. The published tall preview used Size5×5, Peak30,
Rounded, Sharp and tile scale35 (a close camera zoom).

A real GUI reproduction showed that typing30 into Peak, then clicking the map
without Enter, left SpinBox.value and the placement settings at12 while its
LineEdit displayed30. Map clicks do not remove focus from that numeric field.
The same pending-input issue affected Flatten Height. Previous controls tests
assigned SpinBox.value directly, so they did not exercise this keyboard path.

TerrainSettings now propagates complete valid integer text immediately for
Peak and Flatten Height, preserving incomplete negative input until a digit
arrives. Out-of-range integers clamp both the visible text and the value.
SpinBox arrows, separate Hill/Mountain settings and native keyboard submission
continue to work. No geometry, terrain rules, shader, save or simulation code
changes. Save format11 and Alpine Lake remain supported.

Regression sends actual key events through the GUI, clicks the map while the
field retains focus, checks reference30, Undo/Redo, negative Flatten, separate
Hill settings, max30 clamping and arrow/value changes. Six original checks
failed before the fix; all pass after. Full project verification and Android
packaging use the standard workflow.

A separate diagnostic confirmed GUI Mountain geometry matches the preview
builder exactly. Rounded interpolation still changes visible height: one tiny
Rounded control can hit reference30 while making a low hump; a5×5 Raise brush
can reach a visible30. This update does not change that geometry behavior.
To reproduce the preview, choose Create mountain → Size5×5 → Peak30 → Rounded
→ Sharp and zoom in. In0.3.10, press the keyboard's Done/Enter after typing.
For Raise, choose a broad brush and step4; Flat produces terraces, Rounded
produces the smoothed surface. Both stop at reference30.

Signing setup remains deferred; export the city before installing a new test
APK because the unchanged temporary-key fallback can require reinstall.
