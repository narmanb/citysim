extends SceneTree
const W = preload("res://model/city_world.gd")
const G = preload("res://model/terrain_geometry.gd")
const E = preload("res://model/terrain_editor.gd")
const S = preload("res://persistence/city_store.gd")
const H = preload("res://ui/construction_history.gd")
var failures: Array[String] = []
var checks = 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func blank():
	var w = W.new(177)
	for i in range(W.COUNT): w.tiles[i] = W.blank_tile()
	w.cash = 1000000
	w.recalculate()
	return w
func run():
	check("rounded" in G.SHAPES and "smooth" in E.OPERATIONS, "Rounded and Smooth are supported")
	if "rounded" not in G.SHAPES or "smooth" not in E.OPERATIONS:
		for message in failures: push_error(message)
		quit(1);return
	var w = blank()
	var c = 25*52+25
	for scenario in ["plane","bowl","saddle","peak","valley"]:
		for y in range(20,32):
			for x in range(20,32):
				var i=y*52+x
				w.tiles[i].terrainShape="rounded"
				var dx=x-25;var dy=y-25
				w.tiles[i].elev=3 if scenario=="plane" else clampi(dx*dx+dy*dy,0,12) if scenario=="bowl" else clampi(dx*dy,-5,12) if scenario=="saddle" else clampi(12-dx*dx-dy*dy,-5,12) if scenario=="peak" else clampi(dy*dy-5,-5,12)
		for i in [c,c+1,c+52,c-53]:
			for t in [0.,.125,.25,.5,.75,.875,1.]:
				check(is_equal_approx(G.sample(w.tiles,i,1,t),G.sample(w.tiles,i+1,0,t)), "Shared E/W edge " + scenario)
				check(is_equal_approx(G.sample(w.tiles,i,t,1),G.sample(w.tiles,i+52,t,0)), "Shared N/S edge " + scenario)
				check(G.sample(w.tiles,i,t,t)>=-5 and G.sample(w.tiles,i,t,t)<=12,"Rounded bounds " + scenario)
		if scenario=="plane": check(is_equal_approx(G.sample(w.tiles,c,.3,.7),3),"Constant field stays flat")
	var sample = G.sample(w.tiles,c,.25,.75)
	w.tiles[c].line=true;w.tiles[c+1].road=true;w.tiles[c+52].zone="res";w.tiles[c-1].tree=true
	check(G.sample(w.tiles,c,.25,.75)==sample,"Construction never changes rounded geometry")
	w=blank()
	var settings={"shape":"rounded","direction":"auto","strength":1,"smooth_strength":2,"preset_radius":2,"peak":6,"profile":2}
	var p=E.plan(w,E.footprint(c,2),"smooth",1,null,settings)
	check(p.cost==0 and p.before.is_empty(),"Smooth on all-flat land costs nothing")
	w.tiles[c].elev=12;w.tiles[c+1].terrainShape="cliff";w.tiles[c+1].elev=8
	w.tiles[c-1].road=true;w.tiles[c+52].pipe=true
	p=E.plan(w,E.footprint(c,2),"smooth",1,null,settings)
	check(not p.after.has(c+1) and not p.after.has(c-1) and not p.after.has(c+52),"Smooth preserves Cliff, roads and utilities")
	for i in p.after: check(absi(p.after[i].elev-w.tiles[i].elev)<=2,"Smooth bounded delta")
	w.recalculate()
	var before=S.export_json(w);var result=E.commit(w,p)
	check(result.changed and w.tiles[c].elev>=10 and w.tiles[c].elev<12,"Smooth softens peak with bounded change")
	var history=H.new();history.begin();history.record(result.before,result.after,result.cost);history.finish()
	check(history.undo(w) and S.export_json(w)==before,"Smooth Undo restores exact state and cash")
	check(history.redo(w),"Smooth Redo succeeds")
	for op in ["hill","mountain"]:
		w=blank();settings.peak=6 if op=="hill" else 12
		p=E.plan.call(w,[],op,1,null,settings,[c])
		check(p.after.has(c) and p.after[c].elev==settings.peak,"Preset reaches selected reference peak " + op)
		check(p.cost==0 and p.after.size()<=25,"Free preset changes only its unique footprint cells")
		var retraced=E.plan.call(w,[],op,1,null,settings,[c,c,c])
		check(retraced.after==p.after and retraced.cost==p.cost,"Retraced preset stamps never accumulate")
		check(p.after[c].elev>=p.after.get(c+1,W.blank_tile()).elev,"Radial peak falls outward")
		for i in p.after: check(p.after[i].elev>=0 and p.after[i].elev<=12,"Preset bounded")
		w.tiles[c].tree=true
		var stale_state=w.serialize()
		check(not E.commit(w,p).changed and w.serialize()==stale_state,"Stale preset rejects atomically")
		w.tiles[c].tree=false;w.recalculate()
		var preset_before=S.export_json(w)
		result=E.commit(w,p)
		var preset_after=S.export_json(w)
		var preset_history=H.new();preset_history.begin();preset_history.record(result.before,result.after,result.cost);preset_history.finish()
		check(preset_history.undo(w) and S.export_json(w)==preset_before,"Multi-tile preset Undo restores exact state and cash " + op)
		check(preset_history.redo(w) and S.export_json(w)==preset_after,"Multi-tile preset Redo restores exact state and cash " + op)
		check(result.changed and w.tiles[c].terrainShape=="rounded","Preset uses Rounded")
		check(not w.can_place(c,"res") and not w.can_place(c,"road") and w.can_place(c,"line"),"Rounded requires flat foundation but permits anchored utility")
		var restored=S.import_json(S.export_json(w))
		check(restored!=null and restored.tiles[c].terrainShape=="rounded" and restored.serialize().version==13,"Rounded save roundtrip")
		settings.peak=0
		check(E.plan.call(w,[],op,1,null,settings,[c]).cost==0,"Lower-than-center preset free")
	# The visible rounded summit must reach the requested absolute Peak, not
	# just its control tile. Include small stamps, profiles and raised land.
	for radius in [1,2,4]:
		for profile in [1,2,3]:
			for base in [0,7]:
				w=blank()
				for tile in w.tiles:tile.elev=base
				var peak_settings={"preset_radius":radius,"peak":30,"profile":profile}
				p=E.plan.call(w,[],"mountain",1,null,peak_settings,[c])
				check(is_equal_approx(G.sample(w.tiles,c,.5,.5,p.after),30.),"Visible Peak30 matches selected height radius/profile/base "+str([radius,profile,base]))
				check(p.after.size()<=(radius*2+1)*(radius*2+1),"Exact visible peak keeps selected footprint")
	w=blank()
	var cliff_settings={"preset_radius":4,"peak":6,"preset_shape":"cliff"}
	p=E.plan.call(w,[],"hill",1,null,cliff_settings,[c])
	check(not p.after.has(c+4+4*52),"Cliff preset leaves zero-weight corners untouched")
	var raised=0
	for i in p.after:
		if p.after[i].elev>w.tiles[i].elev: raised+=1
	check(p.cost==0 and raised==p.after.size(),"Free Cliff preset changes only actually raised cells")
	w=blank()
	for i in range(W.COUNT): w.tiles[i]=W.blank_tile("water")
	for i in [c,c+1,c+52,c+53]: w.tiles[i].merge({"terrain":"grass","elev":4,"terrainShape":"rounded"},true)
	for t in [0.,.25,.5,.75,1.]:
		check(is_equal_approx(G.sample(w.tiles,c,0,t),4),"Island field excludes surrounding water without collapsing its banks")
		check(is_equal_approx(G.sample(w.tiles,c,1,t),G.sample(w.tiles,c+1,0,t)),"Island shared edge remains continuous")
	for edge in [0,51,2652,2703]:
		w=blank();w.tiles[edge].terrainShape="rounded";w.tiles[edge].elev=-5
		for u in [0.,.5,1.]: check(is_finite(G.sample(w.tiles,edge,u,1-u)),"Boundary field finite")
	for message in failures: push_error(message)
	print("Rounded terrain: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
