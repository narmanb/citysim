extends SceneTree
## Ground contact, save neutrality and retained invalidation for the new batch.
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
const L=preload("res://view/iso_layer.gd")
const C=preload("res://model/civil_engineering.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 var w=W.new(73)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.cash=1000000
 var v=V.new();root.add_child(v);v.size=Vector2(854,394);v.set_process(false);v.set_world(w)
 await process_frame;await process_frame
 for kind in ["police","fire","school","hospital","plant","pump","tower","station"]:
  for mode in ["flat","raised","gentle"]:
   if kind=="station" and mode=="gentle":continue
   var q=W.blank_tile();q.civic=kind
   if mode!="flat":q.elev=5
   if mode=="gentle":q.merge({"terrainShape":"slope","slopeDir":"E","shapeStrength":1,"foundationHeight":5.5},true)
   var layer=L.new();v._draw_civic(layer,q,20,20)
   check(layer.commands.size()==1 and layer.commands[0][0]==2,"Facility is a single retained sprite: "+kind+" "+mode)
   var alias="civic_"+kind
   check(v._manifest.sprites.has(alias),"Facility has a baked alias: "+alias)
   if v._manifest.sprites.has(alias) and layer.commands.size()==1 and layer.commands[0][0]==2:
    var s:Dictionary=v._manifest.sprites[alias]
    var command:Array=layer.commands[0]
    var contact:Vector2=command[2].position+Vector2(s.anchor.x,s.anchor.y)*v.BASE/66.
    check(contact.distance_to(v._point(20.5,20.5,C.build_height(q)))<.0001,"Measured ground contact: "+kind+" "+mode)
   layer.free()
 # Complete source frontages replace only the first retail floor, then grow up.
 var catalog=v._building_catalog
 var styles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/building_styles.json"))
 for recipe in styles.recipes.shop:
  if not recipe.has("storefront"):continue
  catalog.data.recipes.shop=[recipe]
  for level in [1,2]:
   var tile=W.blank_tile();tile.zone="com";tile.zoneType="shop";tile.level=level;tile.elev=2
   var layer=L.new();v._draw_development(layer,tile,20.5,20.5,.94,17)
   var sprites=0
   for cmd in layer.commands:
    if cmd[0]==2:sprites+=1
   check(sprites==(1 if level==1 else 3),"Complete frontage stacks once at level "+str(level)+" "+recipe.id)
   check(layer.commands.size()==sprites,"No duplicate awning or pedestal over complete storefront")
   layer.free()
 # Same colors and roof must yield four structurally distinct industrial shells.
 var style:Dictionary=catalog.style_for(73,17,"light")
 var silhouettes:Dictionary={}
 for profile in ["shed","warehouse","sawtooth","tankyard"]:
  style.profile=profile
  var layer=L.new();v._draw_factory(layer,style,20.5,20.5,2,2,3,true,false)
  var polygons:Array=[]
  for cmd in layer.commands:
   if cmd[0]==0:polygons.append(cmd[1])
  silhouettes[str(polygons)]=true
  layer.free()
 check(silhouettes.size()==4,"Industrial profiles change actual silhouette rather than palette alone")
 for palette in catalog.data.palettes:
  style.wall=Color(palette.wall);style.profile="sawtooth"
  var layer=L.new();v._draw_factory(layer,style,20.5,20.5,2,2,3,true,true)
  var dim_glazing=false;var bright_glazing=false
  for cmd in layer.commands:
   if cmd[0]==0:
    if cmd[2]==Color("88a7aa").darkened(.35):dim_glazing=true
    if cmd[2]==Color("88a7aa"):bright_glazing=true
  check(dim_glazing and not bright_glazing,"Abandoned sawtooth glazing dims for every palette: "+palette.id)
  layer.free()
 var index=25*52+25
 w.tiles[index].merge({"elev":3,"terrainShape":"slope","slopeDir":"E","shapeStrength":1},true)
 check(w.place(index,"hospital"),"Actual hospital construction on gentle terrain")
 w.recalculate();var before=w.serialize();v.refresh();await process_frame;await process_frame
 check(w.serialize()==before,"New artwork does not mutate model or save")
 var redraws=v.metrics.ground_redraws
 v.camera+=Vector2(7,11);v.zoom_at(1.1,Vector2(400,180));await process_frame
 check(v.metrics.ground_redraws==redraws,"Camera movement reuses retained facility commands")
 w.tiles[index].civic="fire";w.tiles[index].elev=6;w.tiles[index].foundationHeight=6.5
 v.refresh();await process_frame;await process_frame
 var cached=v._tile_records.duplicate(true)
 v._cached_world=null;v.refresh();await process_frame;await process_frame
 check(cached==v._tile_records,"Civic replacement and raised pad agree with full rebuild")
 v.queue_free();await process_frame
 for failure in failures:push_error(failure)
 print("Art batch view: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
