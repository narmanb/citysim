# 0.3.16 — Peak picker and shared height40

Hill/Mountain's Peak control is now a button showing the current value. It opens
a modal popup with ten numbered choices:1,4,8,12,16,20,25,30,35,40. Tap one to
apply and close. Custom numeric input is staged until Apply custom; Cancel,
closing or dismissal leaves the previous value intact. Hill and Mountain retain
independent values. The right settings dock remains compact and persistent.
Peak remains absolute elevation, not added height. The separate Flatten height
control retains its existing direct numeric entry.

All terrain uses the shared maximum40, minimum-5: Raise/Lower, Flatten, presets,
Smooth edges, geometry samples, foundations, camera Fit, picking and save validation.
Invalid structural values or heights above40 reject imports. Existing valid
v6–13 saves remain readable and retain their terrain. The schema stays13 because
no new tile fields were added. Older APKs reject saves containing heights above30;
keep exports before installing/downgrading. Existing mountains do not grow merely
by installing. New rounded presets retain the visible summit correction from0.3.15.

Verification: new picker test initially failed for missing button and old limit.
It now passes preset/custom/dismissal, independent tool choices, two viewport
sizes, visible summit40, Undo/Redo and save import. Full35 native suites and
source-art/license receipts pass. Bounds tests cover every integer -5..40,
including legacy saves, invalid imports, map-edge picking and high-building Fit.
Actual native OpenGL captures verify real GUI clicks for the opening button,
preset40 and Apply custom, plus layout at640×360. An initial capture harness
used child-window coordinates incorrectly; forwarding clicks through the root
at the embedded-window offset passes. No product fix was needed for that harness.
Desktop rendering does not establish phone FPS or Android keyboard behavior.

Phone checks: open Peak, choose40, reopen and enter23, apply; reopen and cancel
another entry. Check Hill/Mountain retain separate choices. Create a new peak40
on empty land, Undo/Redo, save/reopen. Raise/Flatten ground to40 and verify no
further Raise charge. Export your current city before replacing the APK:
stable signing remains deferred, so temporary test signing may require reinstall.
Sprites are outside this update; discuss them after phone testing.
