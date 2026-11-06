# City Systems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or executing-plans. Track progress in /workspace/scratch/city-systems-update/progress.md.

**Goal:** Complete all3 approved native gameplay/feedback steps in one tested APK.
**Architecture:** Independent deterministic transport/report/progression helpers;
CityWorld owns monthly lifecycle/persistence. A standalone report panel/plot presents
read-only derived data through existing responsive dialogs. No external engine/code.
**Tech Stack:** Godot4.6.3 GDScript, existing retained renderer and Android workflow.
**Spec:** docs/superpowers/specs/2026-11-06-city-systems.md

## Global Constraints
-52x52,three zones,automatic growth,free Terraform,-5..40,existing graphics unchanged.
-Legacy saves through13 supported; validated optional data in save14.
-Visual agents capped70cars/9trains and independent of authoritative traffic/employment.
-No Micropolis source copying,external dependencies,signing changes or oldrelease overwrite.
-New0.3.19/code20,final download provided as GitHub release PAGE.

## Review Focus
-Grade-separated adjacent roads and far-member parcel entrances.
-Allocation cannot invent jobs or depend on vehicle count/render steps.
-Construction/report/reload cannot create monthly samples or challenge progress.
-Malformed history/scenario payload cannot crash,allocate unbounded storage or alter city.
-Report/layout readable at854x394; charts support flat/negative series and no history.

### Task1 — analytical transport and road-aware services
Files:model/commute_system.gd,city_world.gd transport/population/service functions;
tests/test_commuting.gd,test_service_access.gd.
Interface:static CommuteSystem.calculate(world)->Dictionary; store world._commute_result
derived-only and set trafficHeat/stats via _traffic_prepare. New derived stats commuteUnserved,
avgCommute,commuters. Civil.road_link is mandatory for graph edges. Parent owns later
save/history lifecycle integration; do not alter serialize/from_dict in this task.
- [x] RED independent-of-cars,capacities,disconnected roads,whole-parcel and illegalgrade cases.
- [x] Implement deterministic weighted routes and bounded graph coverage,verify GREEN.
- [x] Check existing model/growth/native tests and report measured costs/regressions.

### Task2 — reports,history and challenge helpers
Files:model/city_report.gd,city_history.gd,scenario_system.gd and focusedtests.
Interfaces:CityReport.evaluate(world,index=-1)->Dictionary(approval,headline,issues,growth);
CityHistory.sample(world)->Dictionary; record(history:Array,point:Dictionary)->Array;
validate(value)->bool; ScenarioSystem.definitions()->Array; start(world,id)->Dictionary;
update(world,state)->Dictionary; validate(state)->bool. No helpers preload CityWorld.
- [x] RED reportread-only/emptycity/rankedconcerns and growthdiagnostic fixtures.
- [x] RED monthly bounded chronology and saved challenge win/deadline/corruption tests.
- [x] Implement pure helpers,all3challenge types and explicitstatus handling; GREEN.

### Task3 — lifecycle,save14 and responsive report UI
Parentfiles:city_world.gd,ui/main.gd,newui/city_report_panel.gd,ui/history_plot.gd,
persistence/city_store.gd onlyifneeded,tests/test_city_progression.gd,test_city_report_ui.gd.
- [x] Integrate CityWorld.cityHistory/scenario,record only end-of-step; legacybootstrapping,
  strictoptionaldata validation,save14 and derivedapproval.
- [x] Add Report to scrollablefooter; Overview/Growth/History/Challenges, readable axes,
  overlay jumps and explicit start/abandon actions using existing modal boundaries.
- [x] Run save roundtrip/monthly/sandbox integration and all native suites; fix regressions.
- [x] Capture real phone-layout native screens and exact model neutrality; compare performance.
- [x] Fresh independent review; resolve important findings and validate fixes.
- [x] Version0.3.19/code20,freshrelease path,CI/APK/source/signature/alignment checks,
  publish separatepreview and verify public download; final release-page link.

Completed in code commit `92162de13932f246927f0eb9d90cb6b879b91269`.
CI run `42202245540` passed all 48 suites and export verification. Release assets
were independently downloaded and checked for source receipts, signatures and
16 KB alignment. Public page and full anonymous APK download verified:
https://github.com/narmanb/citysim/releases/tag/v0.3.19-terraform-preview
