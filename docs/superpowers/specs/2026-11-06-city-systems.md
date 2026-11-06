# Native city systems expansion

User approved the three-step recommendation: (1) commuting/traffic and road-aware
services, (2) City Report with approval/problems/growth explanations, (3) persistent
history graphs and playable scenario challenges. Implement all three, then deliver
one new native Android preview via a GitHub RELEASE PAGE link. Implement independently
in GDScript: no Micropolis source or GPL-derived port is admitted.

## Preserve

Godot4.6.3/native Android,52x52 geometry,three zone buttons,automatic growth,existing
art/palettes,retained rendering,free Terraform,height bounds-5..40 and landscape rotation.
Read valid legacy saves including current13. Save14 may add bounded historical and
challenge data. Do not rewrite old releases or signing configuration. Persistent key
setup remains deferred. Keep random sampling of visible cars capped70 and trains9;
traffic and employment must not depend on visible-agent counts or viewport/FPS.

## 1. Commuting and services

Build a deterministic road graph respecting Civil.road_link (including grade edges).
Assign occupied residential demand to reachable occupied commercial/industrial job
capacity via bounded graph searches per property, never per citizen or visual car.
Account for whole parcel entrances, not just the root cell. Deduct assigned job
capacity; disconnected neighborhoods cannot share jobs. Deposit weighted assigned
commuter flow onto actual paths; expose trafficHeat,employed,unemployment,commuters,
commuteUnserved,avgCommute,congestion. A rendering/animation step must never change
these analytical results. Preserve train count limits and existing rail behavior;
no detailed multi-modal trip model is claimed in this batch.

Police/fire/school/hospital require utility supply and adjacent accessible roads;
coverage follows the legal road network with bounded local spill to buildings.
Funding still affects reach/strength. A nearby island or disconnected road loop
must not receive coverage through an intervening river just from radial distance.
Keep tools/model UI-independent. Measure recalculate/monthly work on supplied cities.

## 2. City Report

A compact Report dialog provides Overview,Growth,History,Challenges sections.
Compute deterministic approval0..100 and ranked actionable concerns from actual
city conditions: utilities,employment,traffic,crime,pollution,taxes,services and
finances. Use resident-weighted conditions where appropriate; empty unused land
must not dominate citizen feedback. An empty city receives a useful starting hint,
not fabricated resident complaints. Selected-property growth reasons must agree
with actual access,utilities,demand,services,lot suitability and existing promotion
rules. Report viewing is read-only and does not consume RNG or advance simulation.

## 3. History and challenges

Record one monthly sample after each real step; no sample on pan,recalculate,report
view or construction. Keep240 samples (20years); show12/60/240month windows for
population,jobs,cash,monthly budget,crime,pollution,traffic,approval. Start legacy
history at import/current date rather than inventing the past. Preserve exact valid
history through export/import; validate finite numbers,bounds and monotonic dates.

Sandbox remains default. Three optional current-city challenges:
- Growing Community:60months,population1000,utilities supplied,positive monthly budget.
- Clearer Commutes:36months,reduce baseline congestion35% (target floor20),retain90%
  of starting population (minimum100),unemployment<=15%.
- Cleaner Neighborhoods:48months,reduce resident pollution35% (target floor10),retain90%
  population (minimum100),utilities supplied,unemployment<=20%.
Goals must hold3consecutive real months; store baseline/targets,elapsed progress,
streak and active/won/lost status. Commute/clean challenges require100residents.
Deadline and winning progress survive reload. Viewing or editing cannot age or win
it. Abandon is explicit; after win/loss the city remains playable. No forced disaster
or map replacement. Persist/validate challenge IDs and state with save14.

## Verification and delivery

Meaningful RED/GREEN tests for commute quantities/road disconnection/parcel access,
agent-independence,grade edges,road-aware service boundaries,report stability and
empty-city behavior,history cadence/import corruption/deadlines and real monthly wins.
Run all existing native suites,save/import/undo/layout checks. Native screenshots of
Report/Growth/History/Challenges at phone aspect; retain terrain/placement performance.
Measure old/candidate populated-city model/render probes; disclose desktop limits.
New0.3.19/code20 release,official ARM runtimes,signature/alignment and anonymous
public download verification. Final link must be the release PAGE, per user preference.
