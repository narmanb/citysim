extends SceneTree
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
const L=preload("res://view/iso_layer.gd")
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func color_at(layer,point):
 for command in layer.commands:
  if command[0]!=6:continue
  for i in range(command[1].size()):
   if command[1][i].is_equal_approx(point):return command[2][i]
 return Color.MAGENTA
func run():
 var w=W.new(41)
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 var c=25*52+25
 for y in range(22,29):
  for x in range(22,29):w.tiles[y*52+x].merge({"terrainShape":"rounded","elev":clampi(12-(x-24)*9,-5,12)},true)
 var v=V.new();v.size=Vector2(854,394);root.add_child(v);v.set_world(w)
 await process_frame;await process_frame
 var layer=L.new();v._draw_ground(layer,c)
 var steep=color_at(layer,v._rounded_mesh(c).points[12])
 check(steep.r>steep.g and steep.g>steep.b,"Exposed rounded rock uses brown cliff hues rather than gray-green")
 layer.free()
 for i in range(W.COUNT):w.tiles[i]=W.blank_tile()
 w.tiles[c].merge({"terrainShape":"rounded","elev":5,"roundedBase":5},true)
 w.tiles[c+1].terrainShape="cliff"
 v.refresh();layer=L.new();v._draw_ground(layer,c)
 var edge=color_at(layer,v._rounded_mesh(c).points[14])
 var center=color_at(layer,v._rounded_mesh(c).points[12])
 check(edge.r>edge.g and edge.g>edge.b,"Exposed curved cap joins the cliff with a brown rock rim")
 check(center.is_equal_approx(Color("8ab549")),"Gentle interior matches original grass color")
 # Same cached geometry is used before/after purely visual rim evaluation.
 var mesh=v._rounded_mesh(c).duplicate(true)
 var corners=v._terrain_points(c)
 v._draw_ground(layer,c)
 check(mesh==v._rounded_mesh(c) and corners==v._terrain_points(c),"Material joins do not change heights or mesh")
 layer.free()
 for y in range(24,27):
  for x in range(24,28):w.tiles[y*52+x].merge({"terrainShape":"rounded","elev":5,"roundedBase":5},true)
 w.tiles[c-52].merge({"terrainShape":"cliff","elev":0},true);w.tiles[c-52].erase("roundedBase")
 v.refresh()
 var a=L.new();var b=L.new();v._draw_ground(a,c);v._draw_ground(b,c+1)
 for along in [0.,.25,.5]:
  var point=v._point(26,25+along,5)
  check(color_at(a,point)==color_at(b,point),"Terminating cliff rim shares color across connected caps " +str(along))
 a.free();b.free();v.queue_free();await process_frame
 for failure in failures:push_error(failure)
 print("Terrain style: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
