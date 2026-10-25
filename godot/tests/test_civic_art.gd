extends SceneTree
## Offline facility contracts plus actual retained ground contact when integrated.
const W=preload("res://model/city_world.gd")
const S=preload("res://persistence/city_store.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 if not FileAccess.file_exists("res://tools/bake_civic_art.gd") or not FileAccess.file_exists("res://view/civic_catalog.gd"):
  push_error("Recognizable baked civic/utility art and pure civic catalog required");quit(1);return
 var baker=load("res://tools/bake_civic_art.gd")
 var catalog=load("res://view/civic_catalog.gd")
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/render_atlas.json"))
 var atlas=(load("res://assets/render_atlas.png") as Texture2D).get_image()
 var images:Dictionary={};var descriptors:Dictionary={};var before:Dictionary={}
 for name in layout.sprites:
  var q:Dictionary=layout.sprites[name]
  images[name]=atlas.get_region(Rect2i(q.x,q.y,q.width,q.height));descriptors[name]=q.duplicate(true)
  if not name.begins_with("civic_"):before[name]=images[name].get_data()
 var metadata:Dictionary=baker.add(images,descriptors)
 var visuals:Dictionary={}
 for kind in ["police","fire","school","hospital","plant","pump","tower","station"]:
  var alias:String=catalog.sprite_for(kind,42,333)
  check(alias==catalog.sprite_for(kind,42,333),"Stable facility role "+kind)
  check(images.has(alias) and descriptors.has(alias),"Baked facility "+kind)
  if not images.has(alias):continue
  var q:Dictionary=descriptors[alias];var image:Image=images[alias]
  check(q.width==132 and q.height<=192 and q.anchor.x==66,"Single tile projection/compact canvas "+kind)
  check(q.anchor.y>30 and q.anchor.y<q.height,"Measured anchor within crop "+kind)
  check(q.has("derivation") and q.has("source_modules") and not q.source_modules.is_empty(),"Honest module/detail provenance "+kind)
  check(image.get_used_rect().size.x>70 and image.get_used_rect().size.y>45,"Recognizable full facility silhouette "+kind)
  var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data());visuals[hash.finish().hex_encode()]=true
  check(metadata.has(alias),"Facility metadata entry "+kind)
 check(visuals.size()==8,"Eight distinct facility silhouettes")
 for name in before:check(images[name].get_data()==before[name],"Existing module pixels unchanged "+name)
 check(catalog.sprite_for("unknown",1,1).is_empty(),"Unknown role cannot silently get another service identity")
 # Integration mode: once parent regenerates the atlas, check real retained sprites.
 if layout.sprites.has("civic_police"):
  var V=load("res://view/isometric_view.gd")
  var Civil=load("res://model/civil_engineering.gd")
  var w=W.new(42)
  for i in W.COUNT:w.tiles[i]=W.blank_tile()
  var v=V.new();root.add_child(v);v.size=Vector2(854,394);v.set_process(false)
  var i=20*52+20;w.tiles[i].civic="police";w.tiles[i].elev=5;w.tiles[i].foundationHeight=5.5
  w.recalculate();var saved=S.export_json(w)
  v.set_world(w);await process_frame;await process_frame
  var sprite_count=0;var sprite:Dictionary=layout.sprites.civic_police
  for commands in v._tile_records[i].values():
   for command in commands:
    if command[0]==2 and command[3]==Rect2(sprite.x,sprite.y,sprite.width,sprite.height):
     sprite_count+=1
     var expected=v._point(20.5,20.5,Civil.build_height(w.tiles[i]))-Vector2(sprite.anchor.x,sprite.anchor.y)*28./66.
     check(command[2].position.distance_to(expected)<.001,"Facility uses the real foundation height")
  check(sprite_count==1,"Facility is exactly one retained static sprite")
  check(S.export_json(w)==saved,"Art preserves model/save fields")
  var cached=v._tile_records.duplicate(true)
  v._cached_world=null;v.refresh();await process_frame;await process_frame
  check(cached==v._tile_records,"Facility cached/full retained commands identical")
  v.queue_free();await process_frame
 for message in failures:push_error(message)
 print("Civic and utility art: %s failures"%failures.size());quit(0 if failures.is_empty() else 1)
