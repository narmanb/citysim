extends RefCounted
## Offline compositions. Source shells are supplied Kenney modules; signs,
## bay doors, equipment and planting are authored geometric details, not prefabs.
const ROLES=["police","fire","school","hospital","plant","pump","tower","station"]
const SIZE=Vector2i(132,192)
const GROUND=Vector2(66,148)
static func add(images:Dictionary,descriptors:Dictionary)->Dictionary:
 var result:Dictionary={}
 for kind in ROLES:
  var canvas=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8);canvas.fill(Color.TRANSPARENT)
  var modules:Array[String]=[]
  var pad=_polygon([_p(.08,.08),_p(.92,.08),_p(.92,.92),_p(.08,.92)],"#c4c3b6")
  pad+=_polygon([_p(.12,.12),_p(.88,.12),_p(.88,.88),_p(.12,.88)],"#d8d4c3")
  _overlay(canvas,pad)
  var detail=""
  match kind:
   "police":
    _module(canvas,images,descriptors,"buildingTiles_000__slate",.5,.5,0,1.,modules)
    _module(canvas,images,descriptors,"buildingTiles_118__slate",.5,.5,35.5,1.,modules)
    detail+=_face(.14,.85,.878,23,31,"#315c86")
    detail+=_face(.42,.66,.882,0,22,"#354f63")
    detail+=_line(_p(.31,.31,54),_p(.31,.31,81),"#697476",2)
    detail+=_line(_p(.2,.31,71),_p(.42,.31,71),"#abb5b1",2)
    detail+=_polygon([Vector2(32,127),Vector2(40,131),Vector2(40,138),Vector2(36,140),Vector2(32,135)],"#e7d99c")
    detail+=_circle(36,133,1.5,"#627e9b")
   "fire":
    _module(canvas,images,descriptors,"buildingTiles_048__terracotta",.5,.5,0,1.,modules)
    _module(canvas,images,descriptors,"buildingTiles_005__terracotta",.5,.5,35.5,1.,modules)
    detail+=_face(.15,.85,.878,26,33,"#a64339")
    for u in [.18,.53]:
     detail+=_face(u,u+.27,.884,0,25,"#505d63")
     for z in [5,10,15,20]:detail+=_line(_p(u,.886,z),_p(u+.27,.886,z),"#9babad",1)
     detail+=_face(u+.035,u+.235,.887,16,21,"#b8d1d5")
    detail+=_box(.66,.15,.17,.17,43,25,["#cfb894","#927863","#b49a7d"])
    detail+=_circle(101,94,3,"#e9c264")
    detail+=_line(Vector2(101,90),Vector2(101,98),"#fff0c0",1.5)
   "school":
    _module(canvas,images,descriptors,"buildingTiles_048__ochre",.44,.39,0,.85,modules)
    _module(canvas,images,descriptors,"buildingTiles_048__ochre",.44,.39,30.175,.85,modules)
    _module(canvas,images,descriptors,"buildingTiles_065__ochre",.44,.39,60.35,.85,modules)
    detail+=_polygon([_p(.55,.77),_p(.84,.77),_p(.84,.9),_p(.55,.9)],"#b9b38c")
    detail+=_line(_p(.61,.8),_p(.78,.8),"#e9dba4",2)
    detail+=_line(_p(.61,.86),_p(.78,.86),"#e9dba4",2)
    detail+=_line(_p(.88,.2),_p(.88,.2,65),"#7c7f76",2)
    detail+=_polygon([_p(.88,.2,65),_p(.88,.2,50),_p(1.04,.2,57)],"#4e83a6")
    detail+=_circle(50,89,7,"#f0e5c5")+_circle(50,89,5.5,"#f7f1d9")
    detail+=_line(Vector2(50,89),Vector2(50,85),"#666b66",1.5)+_line(Vector2(50,89),Vector2(53,90),"#666b66",1.5)
    detail+=_face(.3,.5,.71,0,22,"#6d6658")
   "hospital":
    _module(canvas,images,descriptors,"buildingTiles_000__cream",.5,.5,0,1.,modules)
    _module(canvas,images,descriptors,"buildingTiles_000__cream",.5,.5,35.5,1.,modules)
    _module(canvas,images,descriptors,"buildingTiles_118__cream",.5,.5,71.,1.,modules)
    detail+=_face(.14,.85,.878,24,34,"#91adb1")
    detail+=_face(.4,.64,.883,0,23,"#50757f")
    detail+=_polygon([Vector2(84,67),Vector2(102,76),Vector2(102,92),Vector2(84,83)],"#cf6c5f")
    detail+=_polygon([Vector2(91,72),Vector2(95,74),Vector2(95,88),Vector2(91,86)],"#fff2dd")
    detail+=_polygon([Vector2(87,77),Vector2(99,83),Vector2(99,87),Vector2(87,81)],"#fff2dd")
    detail+=_polygon([_p(.34,.9,29),_p(.76,.9,29),_p(.76,1.,29),_p(.34,1.,29)],"#b5c3bf")
   "plant":
    # Chimneys are behind the source shell, with their tops rising above it.
    _overlay(canvas,_box(.18,.19,.15,.15,0,100,["#c4baa6","#777970","#a2a18f"])+_box(.43,.19,.15,.15,0,83,["#c4baa6","#777970","#a2a18f"]))
    _module(canvas,images,descriptors,"buildingTiles_032__stone",.47,.54,0,.9,modules)
    _module(canvas,images,descriptors,"buildingTiles_118__stone",.47,.54,31.95,.9,modules)
    detail+=_face(.17,.7,.88,1,23,"#59676b")
    for z in [5,10,15,20]:detail+=_line(_p(.17,.883,z),_p(.7,.883,z),"#8a9898",1)
    detail+=_tank(.82,.43,14,18,"#adb5ae","#778c88")
    detail+=_polygon([Vector2(52,120),Vector2(57,122),Vector2(53,128),Vector2(58,129),Vector2(49,137),Vector2(52,130),Vector2(48,128)],"#e7c96c")
   "pump":
    _module(canvas,images,descriptors,"buildingTiles_000__slate",.3,.33,0,.62,modules)
    _module(canvas,images,descriptors,"buildingTiles_118__slate",.3,.33,22.01,.62,modules)
    detail+=_tank(.68,.59,22,9,"#a6b7ad","#779189")
    var center=_p(.68,.59,9)
    detail+=_ellipse(center.x,center.y,18,9,"#6ba5b4")+_ellipse(center.x-2,center.y-2,10,4,"#8cbfca")
    detail+=_line(_p(.36,.47,14),_p(.36,.65,14),"#6d9caa",6)
    detail+=_line(_p(.36,.65,14),_p(.54,.65,14),"#6d9caa",6)
    detail+=_line(_p(.77,.79,0),_p(.77,.79,27),"#788f94",5)
    detail+=_line(_p(.77,.79,27),_p(.77,.64,27),"#95b6b9",5)
   "tower":
    _module(canvas,images,descriptors,"buildingTiles_048__stone",.25,.2,0,.45,modules)
    _module(canvas,images,descriptors,"buildingTiles_118__stone",.25,.2,15.975,.45,modules)
    for uv in [[.35,.35],[.72,.35],[.35,.72],[.72,.72]]:detail+=_line(_p(uv[0],uv[1]),_p(uv[0],uv[1],76),"#7f8f8b",4)
    for v in [.35,.72]:
     detail+=_line(_p(.35,v,10),_p(.72,v,66),"#9ea8a0",2)
     detail+=_line(_p(.72,v,10),_p(.35,v,66),"#9ea8a0",2)
    detail+=_tank(.535,.535,32,31,"#a6bec0","#698e97",74)
    var peak=_p(.535,.535,123);var cap=_p(.535,.535,105)
    detail+=_polygon([Vector2(cap.x-32,cap.y),peak,Vector2(cap.x+32,cap.y)],"#85a5ac")
    detail+=_ellipse(cap.x,cap.y,32,16,"#adc7c5")
    detail+=_polygon([Vector2(cap.x-32,cap.y),peak,Vector2(cap.x+32,cap.y),Vector2(cap.x+16,cap.y+7)],"#91b2b5")
    detail+=_line(_p(.31,.74,0),_p(.31,.74,92),"#a6b7b3",1.6)
    for z in range(5,89,7):detail+=_line(_p(.28,.74,z),_p(.34,.74,z),"#c4cebf",1)
   "station":
    _module(canvas,images,descriptors,"buildingTiles_048__stone",.36,.29,0,.7,modules)
    _module(canvas,images,descriptors,"buildingTiles_081__stone",.36,.29,24.85,.7,modules)
    for u in [.22,.75]:detail+=_line(_p(u,.84),_p(u,.84,36),"#8b8d85",2.5)
    detail+=_polygon([_p(.12,.56,36),_p(.85,.56,36),_p(.85,.94,36),_p(.12,.94,36)],"#708486")
    detail+=_polygon([_p(.12,.94,36),_p(.85,.94,36),_p(.85,.94,32),_p(.12,.94,32)],"#4f686e")
    detail+=_polygon([_p(.13,.58),_p(.88,.58),_p(.88,.65),_p(.13,.65)],"#e3c875")
    detail+=_circle(52,108,5,"#f1e6c8")+_line(Vector2(52,108),Vector2(52,104),"#607076",1)+_line(Vector2(52,108),Vector2(55,109),"#607076",1)
  _overlay(canvas,detail)
  var used=canvas.get_used_rect();var top=maxi(0,used.position.y-2);var bottom=mini(SIZE.y,used.end.y+2)
  var image=canvas.get_region(Rect2i(0,top,SIZE.x,bottom-top))
  var alias="civic_"+kind
  images[alias]=image
  descriptors[alias]={"width":image.get_width(),"height":image.get_height(),"anchor":{"x":GROUND.x,"y":GROUND.y-top},"source_modules":modules,"derivation":"Supplied Kenney selective module shell; authored geometric service signs, bay doors, equipment, paving and planting; offline RGBA composite, no dedicated facility prefab claimed."}
  result[alias]={"modules":modules,"authored_details":kind,"ground_projection":[132,66],"source_family":"Kenney Isometric Tiles Buildings CC0","derivation":descriptors[alias].derivation}
 return result
static func _p(u:float,v:float,z:float=0.)->Vector2:return GROUND+Vector2((u-v)*66.,(u+v-1.)*33.-z)
static func _polygon(points:Array,color:String)->String:
 var coords=""
 for p in points:coords+="%s,%s "%[p.x,p.y]
 return '<polygon points="%s" fill="%s"/>'%[coords,color]
static func _line(a:Vector2,b:Vector2,color:String,width:float)->String:return '<path d="M%s %s L%s %s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"/>'%[a.x,a.y,b.x,b.y,color,width]
static func _ellipse(x:float,y:float,rx:float,ry:float,color:String)->String:return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>'%[x,y,rx,ry,color]
static func _circle(x:float,y:float,r:float,color:String)->String:return _ellipse(x,y,r,r,color)
static func _face(u0:float,u1:float,v:float,z0:float,z1:float,color:String)->String:return _polygon([_p(u0,v,z0),_p(u1,v,z0),_p(u1,v,z1),_p(u0,v,z1)],color)
static func _box(u:float,v:float,w:float,d:float,lift:float,height:float,colors:Array)->String:
 var a=_p(u,v,lift);var b=_p(u+w,v,lift);var c=_p(u+w,v+d,lift);var e=_p(u,v+d,lift)
 var z=Vector2(0,height)
 return _polygon([b-z,c-z,c,b],colors[1])+_polygon([c-z,e-z,e,c],colors[2])+_polygon([a-z,b-z,c-z,e-z],colors[0])
static func _tank(u:float,v:float,r:float,h:float,top:String,side:String,lift:float=0)->String:
 var p=_p(u,v,lift)
 return '<path d="M%s %s V%s A%s %s 0 0 0 %s %s V%s Z" fill="%s"/>'%[p.x-r,p.y-h,p.y,r,r*.5,p.x+r,p.y,p.y-h,side]+_ellipse(p.x,p.y-h,r,r*.5,top)
static func _overlay(target:Image,body:String)->void:
 var layer=Image.new()
 assert(layer.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="132" height="192" viewBox="0 0 132 192">'+body+'</svg>')==OK)
 target.blend_rect(layer,Rect2i(Vector2i.ZERO,SIZE),Vector2i.ZERO)
static func _module(target:Image,images:Dictionary,descriptors:Dictionary,alias:String,u:float,v:float,lift:float,scale:float,modules:Array[String])->void:
 assert(images.has(alias) and descriptors.has(alias),"Facility module unavailable: "+alias)
 var image:Image=images[alias];var q:Dictionary=descriptors[alias]
 if scale!=1.:
  image=image.duplicate();image.resize(roundi(image.get_width()*scale),roundi(image.get_height()*scale),Image.INTERPOLATE_BILINEAR)
 var position=_p(u,v,lift)-Vector2(q.anchor.x,q.anchor.y)*scale
 target.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(roundi(position.x),roundi(position.y)))
 if not modules.has(alias):modules.append(alias)
