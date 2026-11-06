# Commuting, City Report and Challenges —0.3.19

This completes the three approved gameplay steps in the native Godot game. The
implementation is independently authored GDScript. No Micropolis code or assets
were copied or linked. Existing graphics, three zoning buttons, automatic density
growth, free Terraform and heights-5..40 are retained.

## Transport and service access

Occupied housing properties are assigned to reachable occupied job capacity over
a deterministic road graph. Every edge uses Civil.road_link, including Gentle
grade joins. All parcel members can supply entrances. Assigned capacity is deducted
once, and one graph search per residential property replaces any per-person work.
Actual assigned flows produce road heat/congestion and a weighted average route
length. New traffic percentages will differ from the previous animation-based
scale; they are game indicators, not real engineering capacity measurements.

Animated cars sample these routes; up to70cars and9trains remain. Car count, camera,
FPS and animation cadence do not determine employment or congestion. Visual random
sampling has its own RNG so later automatic disasters are independent of animation.
Rail retains its prior station/ridership estimate; this batch does not introduce
a detailed multimodal commuter or cargo model.

Police, fire, schools and hospitals require power, water and adjacent roads.
Coverage follows connected legal roads, with short dry-land spill to buildings.
Department funding still controls strength/reach. A close but disconnected street
or island cannot gain service merely from geometric proximity. Older roadless
service sites may need a road after importing a city.

## Report

Use **Report** in the bottom action bar. Four sections fit the existing landscape
modal and scroll when needed:

- Overview: deterministic approval, employment/traffic/route summary and ranked
  concerns with links to useful overlays. Crime/pollution/service feedback uses
  occupied residential locations; unused terrain does not dominate the average.
- Growth: select a property with Pan before opening Report. Reasons cover access,
  utilities, demand, local conditions, level limits and automatic density suitability.
  Borderline conditions explain monthly variation and limited growth selection.
- History: population, jobs, treasury, monthly budget, resident crime/pollution,
  traffic and approval, over12months/5years/20years. Negative finances and small
  changes have readable axes. One point is recorded per actual simulated month.
- Challenges: optional goals in the current city. Starting never replaces the map;
  abandoning returns to sandbox, and completed/expired cities remain playable.

Reading any section does not advance time, change state or consume randomness.

## Optional challenges

| Challenge | Deadline | Goals held for3consecutive months |
|---|---:|---|
| Growing Community |60months|At least1,000residents, all developed properties supplied, positive monthly budget|
| Clearer Commutes |36months|Starting traffic reduced35%(target floor20), retain90%population(min100), unemployment<=15%|
| Cleaner Neighborhoods |48months|Starting resident pollution reduced35%(target floor10), retain90%population(min100), utilities supplied, unemployment<=20%|

Traffic/clean challenges require100residents to start. Targets are fixed from the
starting city, and progress/deadlines survive save/reload. Views, edits, repeated
updates and skipped ticks cannot fabricate a three-month streak. Winning on the
last allowed month is supported. A disaster or road failure is reflected before
that month's challenge evaluation and history, without extra occupancy aging,
water-storage consumption or a second monthly charge.

## Persistence

Save14 adds cityHistory and scenario. Existing valid saves, including13 and the
legacy fixture, still import. Historical data begins at the imported city's current
date; prior years are not invented. At most240monthly samples(20years) are kept.
New data is shape/type/finite-value/range/chronology validated; future history or
challenge progress beyond the saved city clock rejects safely. JSON uses full
floating-point precision so valid records roundtrip exactly. Construction Undo/Redo
continues to restore construction while city time/history/challenges keep running.

## Validation

48 native suites pass, including19commuting/29service checks, future-disaster
animation independence,21feedback/21challenge checks,18real-city progression checks,
Report/plot/phone-modal integration and9review regressions. Original artwork/license
receipts and existing construction, save recovery, terrain, input and UI suites pass.

Native1280x591 captures use actual Summit Bay file import,12real simulation months,
all Report sections and challenge start. History survives import, views preserve
serialized state/RNG and cannot age the challenge. Captures use desktop llvmpipe;
phone FPS remains a device test. Independent review findings were corrected:
post-disaster facts before victory/history, fractional history preservation and
monthly-variation growth explanations. Source callers do not repeat occupancy
decay or water commit during an incident refresh.

The expanded monthly simulation does more work than0.3.18. Desktop stage results
are below; they are not Android frame-rate predictions. The renderer and atlas are
unchanged. Test Fit/pan as well as a monthly tick on the phone.

| City / operation | Before ms | After ms |
|---|---:|---:|
|Harbor / recalculate|43.67|56.86|
|Harbor / monthly step|81.70|108.71|
|Harbor / traffic preparation|3.42|3.11|
|Summit / recalculate|35.50|47.77|
|Summit / monthly step|63.10|92.03|
|Summit / traffic preparation|1.98|2.28|
