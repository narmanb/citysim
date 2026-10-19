extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
const C=preload("res://model/civil_engineering.gd")
const S=preload("res://persistence/city_store.gd")
const V=preload("res://view/isometric_view.gd")
const L=preload("res://view/iso_layer.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures.append(message)
func _initialize():call_deferred("run")
func blank():
	var w=W.new(51)
	for i in W.COUNT:w.tiles[i]=W.blank_tile()
	w.cash=1000000;w.recalculate();return w
func run():
	var c=26*52+26
	for op in ["raise","lower"]:
		for radius in [0,1,2]:
			for step in [1,2,4]:
				var w=blank()
				var original=w.tiles.duplicate(true)
				var core=E.footprint(c,radius)
				var p=E.plan(w,core,op,step,null,{"shape":"flat","direction":"auto","strength":1,"smooth_edges":true})
				var height: int=step if op=="raise" else -step
				var size: int=(radius*2+1+step*2)
				check(p.error.is_empty() and p.after.size()==size*size,"Smooth perimeter footprint "+op+str(radius)+str(step))
				check(p.cost==p.after.size()*20 and w.tiles==original,"Pure proposal includes full transition cost")
				for i in core:
					check(p.after.has(i) and p.after[i].elev==height and p.after[i].terrainShape=="flat","Level buildable top")
				for i in p.after:
					var h=G.corners(w.tiles,i,p.after)
					for k in range(4):check(h[k]>=0 if op=="raise" else h[k]<=0,"Monotonic corner change")
					if i not in core:check(maxf(maxf(h[0],h[1]),maxf(h[2],h[3]))-minf(minf(h[0],h[1]),minf(h[2],h[3]))<=1.00001,"Gentle transition range")
					for neighbor in w.neighbors(i):
						var edge=C._edge(i,neighbor)
						var nh=G.corners(w.tiles,neighbor,p.after)
						for k in range(2):check(is_equal_approx(h[edge[0][k]],nh[edge[1][k]]),"Seamless shared edge")
				check(E.commit(w,p).changed,"Commit smooth platform")
				var decoded=S.import_json(S.export_json(w))
				check(decoded!=null,"Graded land save roundtrip")
	var w=blank()
	var p=E.plan(w,[c],"raise",1,null,{"smooth_edges":false})
	check(p.after.size()==1 and p.cost==20,"Sharp remains unchanged")
	for i in [0,51,2652,2703]:
		w=blank();p=E.plan(w,[i],"raise",1,null,{"smooth_edges":true})
		check(p.after.size()==4 and p.cost==80 and E.commit(w,p).changed,"Smooth transition clips at map corner")
	for protected in ["road","rail","line","pipe","zone","civic","water","cliff","rounded"]:
		w=blank();var t: Dictionary=w.tiles[c+1]
		if protected in ["road","rail","line","pipe"]:t[protected]=true
		elif protected=="zone":w.place(c+1,"res")
		elif protected=="civic":w.place(c+1,"school")
		elif protected=="water":w.tiles[c+1]=W.blank_tile("water")
		else:t.terrainShape=protected
		var before=w.serialize()
		p=E.plan(w,[c],"raise",1,null,{"smooth_edges":true})
		check(not p.error.is_empty() and not E.commit(w,p).changed and w.serialize()==before,"Blocked transition atomic "+protected)
	w=blank();w.cash=179
	p=E.plan(w,[c],"raise",1,null,{"smooth_edges":true})
	check(not p.affordable and not E.commit(w,p).changed and w.cash==179,"Whole transition must be affordable")
	w=blank();p=E.plan(w,[c],"raise",1,null,{"smooth_edges":true})
	if p.after.has(c+1):w.tiles[c+1].tree=true
	check(not E.commit(w,p).changed,"Stale transition snapshot rejects")
	w=blank();p=E.plan(w,[c],"raise",1,null,{"smooth_edges":true})
	w.tiles[c+2].terrainShape="rounded"
	var stale_state=w.serialize()
	check(not E.commit(w,p).changed and w.serialize()==stale_state,"Stale unchanged terrain dependency rejects atomically")
	w=blank()
	for tile in w.tiles:tile.elev=30
	w.tiles[c].elev=29
	p=E.plan(w,[c,0],"raise",1,null,{"smooth_edges":true})
	w.tiles[0].elev=29;stale_state=w.serialize()
	check(not E.commit(w,p).changed and w.serialize()==stale_state,"Distant unchanged selected core is guarded")
	w=blank()
	for i in E.footprint(c,1):w.tiles[i].elev=30
	p=E.plan(w,[c],"raise",1,null,{"smooth_edges":true})
	check(p.cost==0 and not E.commit(w,p).changed,"Maximum bound is free")
	w=blank();p=E.plan(w,[c,c+1,c+52,c],"raise",1,null,{"smooth_edges":true})
	var q=E.plan(w,[c+52,c+1,c],"raise",1,null,{"smooth_edges":true})
	check(p.after==q.after and p.cost==q.cost,"Stroke ordering/overlap is deterministic")
	w=blank();p=E.plan(w,[c],"raise",2,null,{"smooth_edges":true});E.commit(w,p)
	var ramp=c+1
	check(w.can_place(c,"res") and w.can_place(ramp,"road"),"Plateau and graded shoulder remain buildable")
	check(w.place(ramp,"res") and w.tiles[ramp].has("foundationHeight"),"Graded shoulder supports a level pad")
	check(S.import_json(S.export_json(w))!=null,"Graded foundation saves correctly")
	for invalid in [null,[],[0,1,0],[-6,0,0,0],[0,2,0,0],[0,"a",0,0]]:
		var data=w.serialize();data.tiles[ramp].gradeCorners=invalid
		check(W.from_dict(data)==null,"Malformed grade metadata rejected")
	# Original sharp mode must clear explicit corners when reshaping.
	p=E.plan(w,[c+52],"flatten",1,0)
	E.commit(w,p)
	check(not w.tiles[c+52].has("gradeCorners"),"Flatten clears obsolete grading")
	var v=V.new();root.add_child(v);v.size=Vector2(854,394)
	w=blank();p=E.plan(w,[c],"raise",2,null,{"smooth_edges":true});E.commit(w,p);v.set_world(w)
	await process_frame;await process_frame
	for i in p.after:
		check(v._terrain_faces(i).is_empty(),"No dirt wall inside graded patch or perimeter")
		if w.tiles[i].has("gradeCorners"):
			var layer=L.new();v._draw_ground(layer,i)
			var points=v._terrain_points(i)
			var triangles: Array=[]
			for command in layer.commands:
				if command[0] in [0,6] and command[3]!=null:triangles.append(command[1])
			check(triangles.size()==2 and triangles[0]==PackedVector2Array([points[0],points[1],points[2]]) and triangles[1]==PackedVector2Array([points[0],points[2],points[3]]),"Actual retained triangles use the same bevel diagonal as samples")
			layer.free()
			for uv in [Vector2(.25,.75),Vector2(.75,.25),Vector2(.5,.5)]:
				var h=G.sample(w.tiles,i,uv.x,uv.y)
				check(is_equal_approx(h,C.sample_corners(G.corners(w.tiles,i),uv.x,uv.y)),"Bevel samples match rendering triangles")
	v.queue_free();await process_frame
	for f in failures.slice(0,15):push_error(f)
	print("Smooth edges: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
