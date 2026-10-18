extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
const V=preload("res://view/isometric_view.gd")
var failures:Array[String]=[]
var checks=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func run():
 var w=W.new(41);w.cash=1000000
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 var c=25*52+25
 E.commit(w,E.plan(w,[],"mountain",1,null,{"preset_radius":2,"peak":12,"profile":3},[c]))
 var v=V.new();v.size=Vector2(854,394);root.add_child(v);v.set_world(w)
 await process_frame;await process_frame
 var worst=0.
 for i in E.footprint(c,2):
  var x=i%52;var y=int(i/52)
  for side in range(4):
   var n=i+[1,52,-1,-52][side]
   if w.tiles[n].terrainShape=="rounded":continue
   for t in [0.,.25,.5,.75,1.]:
    var uv=Vector2(1,t) if side==0 else Vector2(t,1) if side==1 else Vector2(0,t) if side==2 else Vector2(t,0)
    var s=G.rounded_sample(w.tiles,i,uv.x,uv.y)
    worst=maxf(worst,absf(s.x))
    check(absf(s.x)<.000001 and Vector2(s.y,s.z).length()<.000001,"Mountain meets level ground with zero relief/gradient")
  check(v._terrain_faces(i).is_empty(),"No thin cliff wall around a mountain on level ground")
  for n in [i+1,i+52]:
   if w.tiles[n].terrainShape!="rounded":continue
   for t in [0.,.25,.5,.75,1.]:
    var a=G.rounded_sample(w.tiles,i,1,t) if n==i+1 else G.rounded_sample(w.tiles,i,t,1)
    var b=G.rounded_sample(w.tiles,n,0,t) if n==i+1 else G.rounded_sample(w.tiles,n,t,0)
    check(a.is_equal_approx(b),"Foot transition shares heights and normals across curved caps")
 print("Mountain boundary worst height gap: ",worst)
 # A deliberately elevated foundation must still retain its vertical wall.
 w.tiles[c].merge({"terrainShape":"rounded","roundedBase":5,"elev":8},true)
 w.tiles[c+1].merge({"terrainShape":"cliff","elev":0},true)
 v.refresh();check(not v._terrain_faces(c).is_empty(),"Intentional cliff below the mountain foundation remains")
 # Shape-only neighboring edits must invalidate cached geometry, even at the same elevation.
 var i=c-2
 var before=v._rounded_mesh(i).duplicate(true)
 w.tiles[i-1].terrainShape="rounded"
 v.refresh()
 check(before!=v._rounded_mesh(i),"Changing a flat neighbor to rounded updates the foot geometry")
 var cache=v._tile_records.duplicate(true);v._cached_world=null;v.refresh()
 check(cache==v._tile_records,"Incremental foot records match full rebuild")
 v.queue_free();await process_frame
 for failure in failures:push_error(failure)
 print("Mountain feet: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
