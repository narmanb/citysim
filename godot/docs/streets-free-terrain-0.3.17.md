# 0.3.17 — parks, street details, vehicles and free Terraform

All 13 tools in Terraform are free: surfaces, Raise, Lower, Flatten, Shape,
Smooth, Hill, Mountain, channel, grass/desert biome, tree and forest. They work
with zero or negative cash. Height limits remain -5..40; construction, natural
water and protected terrain retain their rules. Each successful stroke is still
one reversible history action. Roads, rail, zoning, civic buildings, Parks and
Bulldoze retain their normal prices. New Terraform actions neither charge nor
refund money; the city clock and normal monthly economy continue independently.

Existing parks now choose a stable fountain plaza or planted square. Their baked
soil/stone bases are removed, so the park cap sits on actual terrain or its level
foundation. A planted square contains one supplied-art tree; the fountain has
none. The update does not plant trees across the map or change saved vegetation.

Road-facing lamps occur sparsely on straight roads, with occasional low gray
barriers at suitable ends. Decorations skip bridges and rail crossings. Parked
police cars and ambulances appear at suitable curbs by their existing facilities;
a few industrial plots receive a parked garbage/work truck. These are appearance
changes, not new dispatch, waste-collection, utility or collision mechanics.
They add no simulated traffic agents and no new placement menu.

Taxis retain their headings and routes, using the supplied uphill/downhill frames
on graded roads. Pitch samples the local road deck, so it can switch correctly
at a crest or sag. Flat roads keep the existing simple sprite path. Static
furniture uses retained depth buckets, actual road samples and parcel dependency
invalidation. No new per-frame static rebuilding or save fields are introduced.

The original five atlases and licenses are unchanged. Twenty-five additional
crops enter the existing single 1024×2048 runtime atlas, which stays the same size.
All 17 original selected crops and 132 selectively colored building modules remain
verified. The 24 building recipes and six palettes are preserved.

Save13 remains. Existing cities import with their terrain and buildings intact;
their park/street appearance changes on rendering. Older APKs can read existing
saved fields but display their earlier art and charge their earlier prices.

Validation: 37 native suites and source-art/license receipts pass. The new free
Terraform suite passes 158 checks, including all tools at $0/−$50, exact Undo/Redo,
protection and unchanged paid construction. Native art checks cover source pixels,
base removal, all taxi headings, sparse placement, bridge/rail exclusions, no save
mutation, parcel curb changes and local crest pitch. Cached/full native records
and screenshots agree. Fresh review found two grade/cache edge cases; failing
regressions and the independent reproductions now pass.

Harbor draw calls:588→600 Fit/static,589→601 Fit/agents,446→452 district,
257→261 close. Cedar Reach:490→501,494→508,365→373,229→234. These are about 1–3%
more draw calls for the extra detail, with the same atlas dimensions and agent
counts. Software-GL timing varies by view and machine; no Galaxy S25+ FPS claim
is made. Test the populated cities on the phone at Fit, district and close zoom.

Phone checks: inspect existing parks, curbs, parked vehicles and taxis on slopes.
Edit an adjacent road and check that parked art moves/disappears correctly.
Try every Terraform tool, including large mountains and forest brushes, with low
cash. Undo/Redo, then save/reopen and export/import. Export your current city
before replacing the APK: stable signing is still deferred, so temporary test
certificates may require reinstall. The public GitHub download is verified without
login after export. No new sprite or simulation phase starts after this delivery.
