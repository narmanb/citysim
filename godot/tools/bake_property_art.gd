extends RefCounted
## Offline-only curation from the retained Kenney Buildings atlas.
## Complete shop bases have their baked pedestal removed before they reach a lot.
const PALETTES:Dictionary={
 "cream":"#d6c9aa","stone":"#b0b1a9","terracotta":"#bd8170",
 "sage":"#a2b297","slate":"#8eabb4","ochre":"#c9ac76"}
const STOREFRONTS:Array=[18,100,124]

static func add(source_images:Dictionary,images:Dictionary,descriptors:Dictionary,recipes:Dictionary)->Dictionary:
 var expanded:Dictionary=recipes.duplicate(true)
 var additions:Dictionary={
  "house":[_recipe("paired_barrel_house",39,104),_recipe("square_flat_cottage",43,5),_recipe("arched_hip_cottage",53,60),_recipe("square_gable_cottage",56,69)],
  "apt":[_recipe("arched_flat_apartments",44,5),_recipe("paired_gable_apartments",48,81)],
  "shop":[_recipe("awning_convenience",39,118,"storefront_018"),_recipe("framed_market",48,118,"storefront_100"),_recipe("glazed_corner_shop",53,5,"storefront_124")],
  "office":[_recipe("paired_barrel_office",48,90),_recipe("arched_hip_office",44,74)],
  "light":[_recipe("small_shed",38,69,"","shed"),_recipe("broad_warehouse",48,118,"","warehouse"),_recipe("northlight_workshop",53,104,"","sawtooth")],
  "heavy":[_recipe("tank_processing_yard",44,5,"","tankyard"),_recipe("sawtooth_manufacturing",45,104,"","sawtooth"),_recipe("large_loading_works",56,118,"","warehouse")]}
 for kind in additions:
  var existing:Dictionary={}
  for recipe in expanded.get(kind,[]):existing[recipe.id]=true
  for recipe in additions[kind]:
   if not existing.has(recipe.id):expanded[kind].append(recipe)
 for kind in ["light","heavy"]:
  for index in range(expanded[kind].size()):
   var recipe:Dictionary=expanded[kind][index]
   if not recipe.has("profile"):
    recipe.profile=(["warehouse","shed","sawtooth"] if kind=="light" else ["sawtooth","tankyard","warehouse"])[index%3]
 var path:String=ProjectSettings.globalize_path("res://").path_join("../assets/atlases/buildings.xml").simplify_path()
 var xml:=XMLParser.new();assert(xml.open(path)==OK,"Canonical building crops required")
 var provenance:Dictionary={}
 var image:Image=source_images.buildings
 while xml.read()==OK:
  if xml.get_node_type()!=XMLParser.NODE_ELEMENT or xml.get_node_name()!="SubTexture":continue
  var filename:String=xml.get_named_attribute_value("name")
  var id:int=int(filename.trim_prefix("buildingTiles_").trim_suffix(".png"))
  if not STOREFRONTS.has(id):continue
  var x:int=int(xml.get_named_attribute_value("x"));var y:int=int(xml.get_named_attribute_value("y"))
  var width:int=int(xml.get_named_attribute_value("width"));var height:int=int(xml.get_named_attribute_value("height"))
  var original:Image=image.get_region(Rect2i(x,y,width,height))
  var alias:String="storefront_%03d"%id
  var front_y:float=height-45.
  # These complete source shops share a 99x49.5 facade-ground diamond.
  # The original 132x66 tile below it is deliberately not part of the sprite.
  var anchor:Dictionary={"x":width*.5,"y":front_y-24.75}
  var record:Dictionary={"source":filename,"source_atlas":"buildings","source_rect":[x,y,width,height],
   "source_rgba_sha256":_hash(original),"source_xml_sha256":FileAccess.get_sha256(path),
   "anchor":anchor,"front_y":front_y,
   "derivation":"Keep facade above its front diamond y=height-45-abs(x-width/2)*0.5; remove the tile pedestal and side ledges outside the99px facade; selectively recolor opaque wall material below roof, preserving glazing, awnings and roof RGBA.",
   "license":"Kenney CC0; retained assets/licenses/Buildings.txt"}
  provenance[alias]=record
  for palette in PALETTES:
   var crop:Image=original.get_region(Rect2i(0,0,width,height-43))
   var target:Color=Color(PALETTES[palette])
   var reference:Color=Color("#b15252" if id==18 else "#c2beac")
   for yy in range(crop.get_height()):
    for xx in range(crop.get_width()):
     var c:Color=crop.get_pixel(xx,yy)
     if yy>front_y-absf(xx-anchor.x)*.5 or (yy>=42 and absf(xx-anchor.x)>49.5):
      c.a=0
     elif _wall(c,yy,id):
      var shade:float=(c.r+c.g+c.b)/(reference.r+reference.g+reference.b)
      c=Color(clampf(target.r*shade,0,1),clampf(target.g*shade,0,1),clampf(target.b*shade,0,1),c.a)
     crop.set_pixel(xx,yy,c)
   var name:String=alias+"__"+palette
   images[name]=crop
   descriptors[name]={"width":crop.get_width(),"height":crop.get_height(),"anchor":anchor.duplicate(),
    "source_atlas":"buildings","source":filename,"source_rect":[x,y,width,height],
    "source_xml_sha256":record.source_xml_sha256,"derivation":record.derivation,"palette":palette}
 assert(provenance.size()==STOREFRONTS.size(),"All selected canonical storefronts must be present")
 return {"recipes":expanded,"provenance":provenance}

static func _recipe(id:String,floor_id:int,roof_id:int,storefront:String="",profile:String="")->Dictionary:
 var value:Dictionary={"id":id,"floor":"buildingTiles_%03d"%floor_id,"roof":"buildingTiles_%03d"%roof_id,"step":35.5}
 if not storefront.is_empty():
  value.storefront=storefront;value.storefront_complete=true;value.storefront_roof_lift=35.5
 if not profile.is_empty():value.profile=profile
 return value

static func _wall(c:Color,y:int,id:int)->bool:
 if c.a<.98:return false
 var r:float=c.r*255.;var g:float=c.g*255.;var b:float=c.b*255.
 if id==18:return r>g*1.6 and absf(g-b)<8
 if y<34:return false
 return r>135 and r<205 and g>130 and absf(r-g)<10 and g-b>12 and g-b<30

static func _hash(image:Image)->String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data());return hash.finish().hex_encode()
