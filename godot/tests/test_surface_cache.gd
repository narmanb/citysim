extends SceneTree
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func run():
 var w=W.new(41)
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 var c=25*52+25
 for y in range(21,30):
  for x in range(21,30):w.tiles[y*52+x].merge({"terrainShape":"rounded","roundedBase":0},true)
 for y in range(24,27):
  for x in range(24,27):w.tiles[y*52+x].elev=8
 w.tiles[c].surfaceTop="snow";w.tiles[c+4].elev=12
 var v=V.new();v.size=Vector2(854,394);root.add_child(v);v.set_world(w)
 await process_frame;await process_frame
 var before=v._tile_records[c].duplicate(true)
 w.tiles[c+4].elev=0;v.refresh();await process_frame;await process_frame
 check(v._tile_records[c]!=before,"A distant peak updates summit coverage without local geometry changing")
 var records=v._tile_records.duplicate(true);v._cached_world=null;v.refresh();await process_frame;await process_frame
 check(records==v._tile_records,"Material color dependency matches a full rebuild")
 v.queue_free();await process_frame
 for failure in failures:push_error(failure)
 print("Surface cache: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
