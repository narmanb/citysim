extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
const S=preload("res://persistence/city_store.gd")
const H=preload("res://ui/construction_history.gd")
var failures:Array[String]=[]
var checks=0
func _initialize(): call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok: failures.append(message)
func blank():
 var w=W.new(41)
 for i in range(W.COUNT): w.tiles[i]=W.blank_tile()
 w.cash=1000000;return w
func run():
 var c=25*52+25
 for operation in ["raise","hill","mountain"]:
  var w=blank()
  for i in E.footprint(c,1): w.tiles[i].elev=5
  w.recalculate();var before=S.export_json(w)
  var settings={"shape":"rounded","direction":"auto","strength":1,"preset_radius":1,"peak":9,"preset_shape":"rounded"}
  var p=E.plan(w,E.footprint(c,1),operation,1,null,settings,[c])
  var result=E.commit(w,p)
  check(result.changed,"Plateau operation commits " +operation)
  for i in E.footprint(c,1):
   for u in [0.,.25,.5,.75,1.]:
    for v in [0.,.25,.5,.75,1.]: check(G.sample(w.tiles,i,u,v)>=5,"Added rounding never cuts the plateau " +operation)
  check(G.sample(w.tiles,c)>5,"Added rounding visibly rises above its foundation " +operation)
  check(G.sample(w.tiles,c,1,.25)==G.sample(w.tiles,c+1,0,.25),"Equal foundation edges agree " +operation)
  var after=S.export_json(w);var history=H.new();history.begin();history.record(result.before,result.after,result.cost);history.finish()
  check(history.undo(w) and S.export_json(w)==before,"Undo exact foundation/cash " +operation)
  check(history.redo(w) and S.export_json(w)==after,"Redo exact foundation/cash " +operation)
  var restored=S.import_json(after)
  check(restored!=null and G.sample(restored.tiles,c,.25,.25)==G.sample(w.tiles,c,.25,.25),"Foundation survives import " +operation)
  for invalid in [null,INF,5.5,13,-6]:
   var bad=w.serialize();bad.tiles[c].roundedBase=invalid
   check(W.from_dict(bad)==null,"Reject invalid base " +str(invalid))
  p=E.plan(w,[c],"flatten",1,3);E.commit(w,p)
  check(not w.tiles[c].has("roundedBase") and G.sample(w.tiles,c)==3,"Flatten removes foundation metadata")
 var w=blank()
 for i in E.footprint(c,1): w.tiles[i].elev=5
 E.commit(w,E.plan(w,[],"hill",1,null,{"preset_radius":4,"peak":6,"preset_shape":"rounded"},[c]))
 for i in E.footprint(c,1):
  check(G.sample(w.tiles,i)<=6.00001,"Mixed-base preset does not exceed its highest reference")
 w=blank();w.tiles[c].elev=5
 E.commit(w,E.plan(w,[c],"raise",1,null,{"shape":"rounded","direction":"auto","strength":1}))
 check(G.sample(w.tiles,c)>5,"Single raised tile visibly grows without swallowing its base")
 var initial=G.sample(w.tiles,c)
 E.commit(w,E.plan(w,[c],"raise",1,null,{"shape":"rounded","direction":"auto","strength":1}))
 check(G.sample(w.tiles,c)>initial,"Repeated Raise accumulates added relief")
 E.commit(w,E.plan(w,[c],"lower",4,null,{"shape":"rounded","direction":"auto","strength":1}))
 check(S.import_json(S.export_json(w))!=null,"Lower keeps foundation in bounds")
 E.commit(w,E.plan(w,[c],"shape",1,null,{"shape":"cliff","direction":"auto","strength":1}))
 check(not w.tiles[c].has("roundedBase"),"Cliff conversion removes rounded metadata")
 w=blank()
 for i in E.footprint(c,2): w.tiles[i].elev=(i%52-25)+2
 for uv in [Vector2(.125,.35),Vector2(.65,.8)]:
  var x=25+uv.x;var y=25+uv.y
  var derivative=G.field_sample(w.tiles,x,y)
  var dx=(G.field_height(w.tiles,x+.001,y)-G.field_height(w.tiles,x-.001,y))/.002
  var dy=(G.field_height(w.tiles,x,y+.001)-G.field_height(w.tiles,x,y-.001))/.002
  check(absf(derivative.y-dx)<.001 and absf(derivative.z-dy)<.001,"Analytic vertex gradients match finite differences")
 for message in failures: push_error(message)
 print("Terrain foundations: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
