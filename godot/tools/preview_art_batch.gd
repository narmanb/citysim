extends SceneTree
## Native retained render evidence; content fixtures only, no production save changes.
const W=preload("res://model/city_world.gd")
const V=preload("res://view/isometric_view.gd")
const S=preload("res://persistence/city_store.gd")
var out:String
var view
var title:Label
var world
func _initialize():call_deferred("run")
func fresh():
 world=W.new(4242)
 for i in W.COUNT:world.tiles[i]=W.blank_tile()
 world.cash=1000000
func shot(name:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var pixels=root.get_texture().get_image();assert(pixels.save_png(out+"/"+name)==OK);return pixels
func focus(x:float,y:float,elev:float,scale:float):
 view.tile_scale=scale;view.camera=view.size*.5-view._point(x,y,elev)*scale/28.+Vector2(0,40)
func gallery(kinds:Array,ground:String):
 fresh()
 for n in range(kinds.size()):
  var x=20+(n%4)*3;var y=20+int(n/4)*5;var i=y*52+x
  if ground=="gentle":world.tiles[i].merge({"terrainShape":"slope","slopeDir":"E","shapeStrength":1,"elev":4},true)
  elif ground=="raised":
   for yy in range(y-1,y+2):
    for xx in range(x-1,x+2):world.tiles[yy*52+xx].elev=4
  if kinds[n]=="station":assert(world.place(i,"rail"))
  assert(world.place(i,kinds[n]),"Legal facility fixture "+kinds[n])
  for xx in range(x-1,x+2):
   var r=(y+1)*52+xx
   if not world.tiles[r].road:assert(world.place(r,"road"))
 world.recalculate();world.cars=[];world.trains=[]
 view.set_world(world);focus(24.5,22.5,2 if ground!="flat" else 0,70)
func run():
 var args=OS.get_cmdline_user_args();assert(args.size()==1 and DisplayServer.get_name()!="headless")
 out=args[0];DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1600,1000);root.content_scale_size=Vector2i(1600,1000)
 view=V.new();view.size=Vector2(1600,1000);root.add_child(view);view.set_process(false)
 title=Label.new();title.position=Vector2(28,24);title.z_index=4096;title.add_theme_font_size_override("font_size",26);root.add_child(title)
 title.text="MetroForge 0.3.18 — police, fire station, school and hospital"
 gallery(["police","fire","school","hospital"],"flat");focus(24.5,20.5,0,83)
 await shot("service-buildings.png")
 title.text="MetroForge 0.3.18 — power plant, pump, water tower and rail station"
 gallery(["plant","pump","tower","station"],"raised");focus(24.5,20.5,4,83)
 await shot("utility-buildings.png")
 title.text="MetroForge 0.3.18 — services upright on gentle terrain and level pads"
 gallery(["police","fire","school","hospital"],"gentle");focus(24.5,20.5,4,83)
 var before=S.export_json(world)
 var cached=await shot("facilities-on-slopes.png")
 # Change an existing civic and foundation through retained invalidation.
 var i=20*52+23;world.tiles[i].civic="hospital";world.tiles[i].elev=7;world.tiles[i].foundationHeight=7.5
 view.refresh();var changed=await shot("incremental-facility.png")
 view._cached_world=null;view.refresh();var full=await shot("full-facility.png")
 assert(changed.get_data()==full.get_data(),"Incremental facility/pad differs from full renderer")
 world.tiles[i].civic="fire";world.tiles[i].elev=4;world.tiles[i].foundationHeight=4.5
 assert(S.export_json(world)==before,"Rendering mutated fixture state")
 title.text="MetroForge 0.3.18 — housing, business and industrial variety"
 fresh()
 var parcel=1
 for entry in [[19,19,"res",1],[24,19,"res",3],[29,19,"shop",1],[19,24,"office",3],[24,24,"light",2],[29,24,"heavy",3]]:
  for yy in range(entry[1],entry[1]+3):
   for xx in range(entry[0],entry[0]+3):
    var k=yy*52+xx;assert(world.place(k,entry[2],false,parcel));world.tiles[k].level=entry[3]
  parcel+=1
 world.recalculate();world.cars=[];world.trains=[];view.set_world(world);focus(25,23,0,45)
 await shot("development-variety.png")
 title.text="MetroForge 0.3.18 — source storefronts at levels 1 and 2"
 fresh()
 var shops:Array=[]
 for recipe in view._building_catalog.data.recipes.shop:
  if recipe.has("storefront"):shops.append(recipe)
 for n in range(shops.size()):
  for level in [1,2]:
   var k=(20+(level-1)*5)*52+20+n*3
   var id=1000+n*3000+level*10000
   var limit=id+10000
   while view._building_catalog.style_for(world.seed,id,"shop",k).recipe.id!=shops[n].id and id<limit:id+=1
   assert(id<limit,"Storefront recipe is selectable")
   assert(view._building_catalog.style_for(world.seed,id,"shop",k).recipe.storefront==shops[n].storefront,"Actual rendered member selects the requested storefront")
   assert(world.place(k,"shop",false,id));world.tiles[k].level=level
 world.recalculate();world.cars=[];world.trains=[];view.set_world(world);focus(23.5,22.5,0,80)
 await shot("storefront-growth.png")
 # Dedicated industrial profiles show each silhouette with the same palette.
 title.text="MetroForge 0.3.18 — shed, warehouse, sawtooth works and tank yard"
 fresh();var catalog=view._building_catalog;var saved:Dictionary=catalog.data.duplicate(true)
 for n in range(4):
  var profile=["shed","warehouse","sawtooth","tankyard"][n]
  var selected:Dictionary={}
  for recipe in catalog.data.recipes.light+catalog.data.recipes.heavy:
   if recipe.get("profile")==profile:selected=recipe;break
  assert(not selected.is_empty())
  # Deterministic ids chosen to select the intended profile in the normal catalog.
  var id=1000+n*1000
  var kind="heavy" if profile=="tankyard" else "light"
  while catalog.style_for(world.seed,id,kind).get("profile")!=profile and id<10000:id+=1
  assert(id<10000,"Fixture can find the requested industrial profile")
  for yy in range(20,22):
   for xx in range(19+n*3,21+n*3):
    var k=yy*52+xx;assert(world.place(k,kind,false,id));world.tiles[k].level=2
 world.recalculate();world.cars=[];world.trains=[];view.set_world(world);focus(24.5,20.5,0,75)
 await shot("industrial-profiles.png")
 catalog.data=saved
 var f=FileAccess.open(out+"/art-capture-results.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"native_facilities":true,"legal_gentle_construction":true,"incremental_full_equal":true,"rendering_preserves_city":true,"renderer":RenderingServer.get_video_adapter_name()},"  "))
 print("PASS native facility, slope, property captures, unchanged saved state and exact incremental/full pixels")
 view.queue_free();await process_frame;quit()
