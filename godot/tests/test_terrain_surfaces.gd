extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
const S=preload("res://persistence/city_store.gd")
const H=preload("res://ui/construction_history.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 if "surface" not in E.OPERATIONS:push_error("Need a surface brush that preserves heights");quit(1);return
 var w=W.new(41);w.cash=1000000
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 var c=25*52+25
 E.commit(w,E.plan(w,[],"hill",1,null,{"preset_radius":1,"peak":6},[c]))
 var points=[]
 for u in [0.,.25,.5,1.]:points.append(G.sample(w.tiles,c,u,u))
 var before=S.export_json(w)
 var p=E.plan(w,E.footprint(c,1),"surface",1,null,{"surface_top":"snow","surface_rock":"gray"})
 var result=E.commit(w,p)
 check(result.changed and result.cost==0,"Cosmetic brush is free and atomic")
 check(w.tiles[c].get("surfaceTop")=="snow" and w.tiles[c].get("surfaceRock")=="gray","Top and flank materials independent")
 var history=H.new();history.begin();history.record(result.before,result.after,result.cost);history.finish()
 check(history.undo(w) and S.export_json(w)==before,"Undo restores exact appearance and cash")
 check(history.redo(w),"Redo restores appearance")
 for j in range(4):check(G.sample(w.tiles,c,[0.,.25,.5,1.][j],[0.,.25,.5,1.][j])==points[j],"Cosmetics preserve geometry")
 var imported=S.import_json(S.export_json(w))
 check(imported!=null and imported.tiles[c].surfaceTop=="snow" and imported.serialize().version==11,"Surface metadata imports")
 for pair in [["surfaceTop","invalid"],["surfaceRock","snow"],["surfaceTop",null]]:
  var bad=w.serialize();bad.tiles[c][pair[0]]=pair[1]
  check(W.from_dict(bad)==null,"Reject unsupported surface metadata")
 check(E.plan(w,[c],"surface",1,null,{"surface_top":"lava","surface_rock":"brown"}).error!="","Reject unsupported brush material")
 E.commit(w,E.plan(w,[c],"raise",1,null,{"shape":"rounded","direction":"auto","strength":1,"surface_top":"grass","surface_rock":"brown"}))
 check(w.tiles[c].surfaceTop=="snow" and w.tiles[c].surfaceRock=="gray","Height edits preserve painted material")
 var after=w.tiles[c].duplicate(true);E.commit(w,E.plan(w,[c],"surface",1,null,{"surface_top":"sand","surface_rock":"grass"}))
 check(w.tiles[c].elev==after.elev and w.tiles[c].roundedBase==after.roundedBase,"Repaint preserves foundations")
 w.tiles[c].merge({"terrainShape":"slope","slopeDir":"auto","elev":0},true);w.tiles[c].erase("roundedBase")
 for i in w.neighbors(c):w.tiles[i].elev=0
 var ramp=G.corners(w.tiles,c)
 E.commit(w,E.plan(w,[c],"surface",1,null,{"surface_top":"sand","surface_rock":"brown"}))
 check(w.tiles[c].terrainShape=="slope" and G.corners(w.tiles,c)==ramp,"Cosmetic brush preserves Auto slope even beside level neighbors")
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 var flat_smooth=E.plan(w,E.footprint(c,1),"smooth",1,null,{"surface_top":"snow","surface_rock":"gray"})
 check(flat_smooth.cost==0 and flat_smooth.after.is_empty(),"Smooth on level ground stays free even with custom materials")
 w.cash=-50
 var free=E.plan(w,[c],"surface",1,null,{"surface_top":"snow","surface_rock":"gray"})
 check(free.affordable,"Free repaint remains affordable while city is in debt")
 var debt_result=E.commit(w,free)
 check(debt_result.changed and w.cash==-50,"Free paint works without increasing debt")
 if debt_result.changed:
  var debt_history=H.new();debt_history.begin();debt_history.record(debt_result.before,debt_result.after,0);debt_history.finish()
  check(debt_history.undo(w) and debt_history.redo(w) and w.cash==-50,"Free repaint Undo/Redo works while in debt")
 var unchanged=E.plan(w,[c],"surface",1,null,{"surface_top":"snow","surface_rock":"gray"})
 check(unchanged.blocked.get(c)=="Already at target","Unchanged appearance reports target rather than height limit")
 for failure in failures:push_error(failure)
 print("Terrain surfaces: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
