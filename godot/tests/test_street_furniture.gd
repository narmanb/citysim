extends SceneTree
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
const F=preload("res://view/street_furniture.gd")
const E=preload("res://model/terrain_editor.gd")
const L=preload("res://view/iso_layer.gd")
var failures:Array[String]=[]
func check(ok:bool,msg:String):
 if not ok:failures.append(msg)
func _initialize():call_deferred("run")
func run():
 var w=W.new(41)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 var v=V.new();root.add_child(v);v.size=Vector2(854,394);v.set_world(w)
 await process_frame;await process_frame
 for alias in ["park_plaza","park_garden","street_lamp_e","street_lamp_s","street_barrier","parked_policeSE","parked_ambulanceSW","parked_garbageSE","carSEU","carSED"]:
  check(v._manifest.sprites.has(alias),"Verified compact crop "+alias)
 var layer=L.new()
 var t=W.blank_tile();t.civic="park"
 v._draw_civic(layer,t,10,10)
 check(layer.commands.size()==1,"Park is one measured sprite instead of two generic trees")

 layer.free()
 var styles:Dictionary={}
 for i in range(100):styles[F.park_style(w.seed,i)]=true
 check(styles.size()==2,"Both supplied park appearances occur deterministically")
 for heading in ["NE","SE","SW","NW"]:
  check(F.taxi_sprite(heading,1)=="car"+heading+"U" and F.taxi_sprite(heading,-1)=="car"+heading+"D" and F.taxi_sprite(heading,0)=="car"+heading,"Taxi headings preserve flat/up/down variants")
 var count=0
 for y in range(5,46):
  var i=y*52+16;w.tiles[i].road=true
  var details=F.road_details(w.tiles,i,5);count+=details.size()
  for d in details:check(d.u>.77 and d.v==.5,"Lamp foot stays on road curb")
  w.tiles[i].rail=true;check(F.road_details(w.tiles,i,5).is_empty(),"No furniture on rail crossings")
  w.tiles[i].rail=false;w.tiles[i].terrain="water";check(F.road_details(w.tiles,i,5).is_empty(),"No furniture on bridge decks")
  w.tiles[i]=W.blank_tile()
 check(count>0 and count<=6,"Street lamps remain sparse")
 # Verify original source pixels and removal of the park's baked dirt walls.
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/render_atlas.json"))
 var packed=Image.load_from_file(ProjectSettings.globalize_path("res://assets/render_atlas.png"))
 for name in layout.sprites:
  var target:Dictionary=layout.sprites[name]
  if not target.has("source_atlas"):continue
  var source=(load("res://assets/atlases/"+target.source_atlas+".png") as Texture2D).get_image()
  var rect:Array=target.source_rect
  var matched=true;var clipped=true
  for yy in range(target.height):
   for xx in range(target.width):
    var pixel:Color=packed.get_pixel(target.x+xx,target.y+yy)
    var removed=name.begins_with("park_") and yy>rect[3]-34-absf(xx-66)*.5
    if removed:
     if pixel.a!=0:clipped=false
    elif pixel!=source.get_pixel(rect[0]+xx,rect[1]+yy):matched=false
  check(matched,"Source art retained exactly for "+name)
  check(clipped,"Baked park foundation removed for "+name)
 # A far parcel member can determine the parked truck's curb. Road edits must
 # invalidate the root record, not only its adjacent non-root members.
 var r=20*52+20
 w.cash=1000000
 for i in [r,r+1,r+52,r+53]:check(w.place(i,"light",false,77),"Industrial fixture place");w.tiles[i].level=2
 while F.parked_role(w.tiles[r],r,w.seed).is_empty():w.seed+=1
 w.tiles[r-1].road=true;w.tiles[r+105].road=true;w.recalculate()
 var before=w.serialize()
 v._cached_world=null;v.refresh();await process_frame;await process_frame
 check(w.serialize()==before,"Art does not alter save fields or agent counts")
 var curb=F.curb(w.tiles,[r,r+1,r+52,r+53])
 check(curb.get("index")==r+105,"Nearest front curb uses entire parcel")
 w.tiles[r+105].road=false;w.recalculate();v.refresh();await process_frame;await process_frame
 var cached=v._tile_records.duplicate(true)
 v._cached_world=null;v.refresh();await process_frame;await process_frame
 check(cached==v._tile_records,"Adjacent road removal refreshes distant parcel parking identically to full rebuild")
 w=W.new(41)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.cash=1000000
 var a=20*52+20;var b=a+1
 for entry in [[a,"E"],[b,"W"]]:w.tiles[entry[0]].merge({"terrainShape":"slope","slopeDir":entry[1],"shapeStrength":1},true);check(w.place(entry[0],"road"),"Connected crest road accepts construction")
 w.recalculate();v.set_world(w);await process_frame;await process_frame
 for item in [[.2,"carSEU"],[.7,"carSED"]]:
  w.cars=[{"path":[a,b],"p":item[0],"speed":1.}];v._update_agents()
  var sprite=v._manifest.sprites[item[1]]
  var expected=Rect2(sprite.x,sprite.y,sprite.width,sprite.height)
  check(v._agent_layers[0].commands[0][3]==expected,"Taxi pitch follows local crest segment "+str(item))
 w=W.new(41)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.cash=1000000
 var owner=20*52+20;var landing=owner+1;var ramp=owner+2
 check(w.place(owner,"police") and w.place(landing,"road"),"Service parking landing fixture")
 w.tiles[ramp].merge({"terrainShape":"slope","slopeDir":"W","shapeStrength":1},true)
 w.recalculate();v.set_world(w);await process_frame;await process_frame
 check(w.place(ramp,"road"),"Neighbor ramp connects legally")
 w.recalculate();v.refresh();await process_frame;await process_frame
 cached=v._tile_records.duplicate(true)
 v._cached_world=null;v.refresh();await process_frame;await process_frame
 check(cached==v._tile_records,"Indirect road deck edits refresh adjacent service parking")
 v.queue_free();await process_frame
 for f in failures:push_error(f)
 print("Street furniture: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
