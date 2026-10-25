extends SceneTree
## New recipes and storefront derivations are checked independently of atlas packing.
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:
 call_deferred("run")
func run()->void:
 if not FileAccess.file_exists("res://tools/bake_property_art.gd"):
  check(false,"Offline property baker must provide the three new source storefronts and expanded recipes")
  quit(1);return
 var helper=load("res://tools/bake_property_art.gd")
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/building_styles.json"))
 var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/render_atlas.json"))
 var packed:Image=(load("res://"+layout.file) as Texture2D).get_image()
 var images:Dictionary={};var descriptors:Dictionary={}
 for key in layout.sprites:
  var q:Dictionary=layout.sprites[key]
  images[key]=packed.get_region(Rect2i(q.x,q.y,q.width,q.height));descriptors[key]=q.duplicate(true)
 var source:Image=(load("res://assets/atlases/buildings.png") as Texture2D).get_image()
 var before:=source.get_data()
 var recipe_before=JSON.stringify(old.recipes)
 var result:Dictionary=helper.add({"buildings":source},images,descriptors,old.recipes)
 check(source.get_data()==before,"Baking keeps every original source pixel unchanged")
 check(JSON.stringify(old.recipes)==recipe_before,"Recipe expansion does not mutate its input")
 var count:=0
 for kind in ["house","apt","shop","office","light","heavy"]:
  check(result.recipes.has(kind),"All growth types remain available: "+kind)
  count+=result.recipes[kind].size()
  var combinations:Dictionary={}
  for recipe in result.recipes[kind]:
   var signature:String=recipe.floor+"/"+recipe.roof
   check(not combinations.has(signature),"New recipes vary actual floor/roof pairs: "+recipe.id)
   combinations[signature]=true
   check(recipe.step==35.5,"Growth stacking lift stays unchanged")
   for palette in old.palettes:
    for piece in [recipe.floor,recipe.roof]:check(images.has(piece+"__"+palette.id),"Every floor/roof resolves for "+recipe.id)
   if kind in ["light","heavy"]:check(recipe.get("profile","") in ["shed","warehouse","sawtooth","tankyard"],"Industrial recipes identify a genuine massing profile")
 check(count>=40,"Development variety increases from24 to at least40 recipes")
 check(result.provenance.size()==3,"Three verified source frontages are admitted")
 var extra_area:=0
 for alias in result.provenance:
  var record:Dictionary=result.provenance[alias]
  check(record.source in ["buildingTiles_018.png","buildingTiles_100.png","buildingTiles_124.png"],"Actual verified storefront source recorded")
  check(record.source_rect.size()==4 and not record.source_rgba_sha256.is_empty(),"Source crop and receipt recorded")
  for palette in old.palettes:
   var name:String=alias+"__"+palette.id
   check(images.has(name),"All six storefront palettes are baked")
   if not images.has(name):continue
   var crop:Image=images[name];var d:Dictionary=descriptors[name]
   extra_area+=crop.get_width()*crop.get_height()
   check(d.anchor==record.anchor,"Palette variants share the measured ground anchor")
   check(crop.get_height()<100,"Source pedestal has been removed rather than raised above the lot")
   var opaque:=0
   for y in range(crop.get_height()):
    for x in range(crop.get_width()):
     var c:Color=crop.get_pixel(x,y)
     if c.a>.01:opaque+=1
     if y>record.front_y-absf(x-record.anchor.x)*.5 or (y>=42 and absf(x-record.anchor.x)>49.5):check(c.a==0,"No pedestal or side ledge survives outside the facade ground diamond")
   check(opaque>2500,"Storefront body, glazing, roof and frontage remain")
 check(extra_area<=205000,"Added palette crops remain within the reserved atlas area")
 var catalog=load("res://view/building_catalog.gd").new()
 catalog.data=catalog.data.duplicate(true);catalog.data.recipes=result.recipes
 var selected:Dictionary={};var profiles:Dictionary={}
 for i in range(1,400):
  var a:Dictionary=catalog.style_for(4242,i,"shop")
  check(a==catalog.style_for(4242,i,"shop"),"Appearance selection remains deterministic")
  if a.recipe.has("storefront"):
   check(a.get("storefront","")==a.recipe.storefront+"__"+a.palette.id,"Catalog resolves storefront alias using selected palette")
   selected[a.recipe.storefront]=true
  var ind:Dictionary=catalog.style_for(4242,i,"heavy")
  check(ind.get("profile","")==ind.recipe.profile,"Catalog exposes the selected industrial profile")
  profiles[ind.profile]=true
 check(selected.size()==3,"A neighborhood can use all three new frontage shapes")
 check(profiles.size()>=3,"Industry can use at least three genuine silhouettes")
 print("Development art: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
