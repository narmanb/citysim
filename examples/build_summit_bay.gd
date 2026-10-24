extends SceneTree
## Authored content only, using the native v13 model and real grading planner.
const W=preload("res://model/city_world.gd")
const S=preload("res://persistence/city_store.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
const C=preload("res://model/civil_engineering.gd")
const F=preload("res://view/street_furniture.gd")
var city
var reserved: Dictionary={}
var districts: Dictionary={}
var roots: Dictionary={}
var failures: Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func at(x:int,y:int)->int:return y*52+x
func t(x:int,y:int)->Dictionary:return city.tiles[at(x,y)]
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func rectangle(x1:int,y1:int,x2:int,y2:int)->Array:
 var out:Array=[]
 for y in range(y1,y2+1):
  for x in range(x1,x2+1):out.append(at(x,y))
 return out
func flat(x:int,y:int,height:int=1):
 var q=t(x,y)
 q.elev=height;q.terrainShape="flat";q.slopeDir="auto";q.shapeStrength=1;q.tree=false
 q.erase("roundedBase");q.erase("gradeCorners");q.erase("surfaceTop");q.erase("surfaceRock");q.erase("foundationHeight")
func platforms():
 for region in [[11,11,28,32,4],[11,11,20,16,2],[34,43,48,49,1]]:
  var cells=rectangle(region[0],region[1],region[2],region[3])
  var p=E.plan(city,cells,"raise",region[4],null,{"smooth_edges":true})
  check(p.error.is_empty() and E.commit(city,p).changed,"Native graded platform "+str(region))
  for i in p.after:
   reserved[i]=true
   for yy in range(maxi(0,int(i/52)-2),mini(52,int(i/52)+3)):
    for xx in range(maxi(0,i%52-2),mini(52,i%52+3)):reserved[at(xx,yy)]=true
 # A modest level industrial court, separated from housing by woodland.
 for i in rectangle(12,39,27,44):reserved[i]=true
func landscape():
 var peaks=[[4,4,32],[12,3,36],[21,3,33],[31,3,40],[49,7,26]]
 for y in range(52):
  for x in range(52):
   var i=at(x,y)
   if reserved.has(i):
    t(x,y).tree=W._hash(x,y,city.seed+3)<.48
    continue
   var q=W.blank_tile()
   var n=W._noise(x*.18,y*.21,city.seed)
   var h=1.2+3.8*n+2.4*pow(sin(x*.21+y*.14),2)
   for p in peaks:
    var d=pow((x-p[0])/5.5,2)+pow((y-p[1])/4.3,2)
    h=maxf(h,1.+(p[2]-1.)*exp(-d*1.25))
   if x<8 and y in range(16,34):h+=5.*sin((y-16.)/18.*PI)*(1.-x/11.)
   q.elev=clampi(roundi(h),1,40);q.terrainShape="rounded";q.roundedBase=1
   q.surfaceRock="gray" if x<35 and y<13 else "brown"
   if q.elev>=21:q.surfaceTop="snow"
   elif q.elev>=16:q.surfaceTop="rock"
   q.tree=q.elev<15 and W._hash(x,y,city.seed+5)<(.76 if n>.5 else .44)
   # Southwestern sandstone mesas, cliffs, dunes and a dry negative quarry.
   if x<12 and y>=35:
    q.biome="desert";q.tree=false;q.surfaceRock="sand"
    q.elev=3+int((y-35)/5)*3+int(x/5)
    if x in range(3,10) and y in range(39,47):
     q.elev=9 if x<5 or y<41 else 5 if x<7 or y<43 else -3
     if x>=8 and y>=44:q.elev=-5
     q.terrainShape="cliff";q.erase("roundedBase");q.surfaceTop="sand" if q.elev>0 else "rock"
    elif x<4:q.terrainShape="rounded";q.surfaceTop="sand"
    else:q.terrainShape="cliff";q.erase("roundedBase");q.surfaceTop="sand"
   if q.biome=="grass" and q.elev<=7 and y>33:q.surfaceRock="grass"
   # Exposed tilted strata provide Medium and Steep samples, away from construction.
   if x in [10,11] and y in range(36,50):
    q.terrainShape="slope";q.slopeDir="W";q.shapeStrength=2 if y<44 else 3;q.erase("roundedBase")
   # Large natural lake, wooded island, and a meandering northern river.
   var lake=pow((x-42.)/8.4,2)+pow((y-29.5)/11.0,2)+.10*sin(x*.6+y*.9)<1.
   var river_x=40.5+2.5*sin(y*.31)
   var river=y<=22 and absf(x-river_x)<1.25
   var island=pow((x-44.)/1.8,2)+pow((y-29.)/2.4,2)<1.
   if (lake or river) and not island:
    q=W.blank_tile("water");q.elev=-1-(y%4) if river and y>1 else 0
    if river and y>1:q.channel=true;q.waterSource=false
   if island:
    q.elev=3+int(W._noise(x*.6,y*.5,77)*3);q.terrainShape="rounded";q.roundedBase=0;q.tree=true
   # A high forest pond and a rocky overlook distinct from the main lake.
   if pow((x-3.)/2.1,2)+pow((y-24.)/2.8,2)<1.:
    q=W.blank_tile("water");q.elev=5
   if x>=49 and y in range(22,36) and q.terrain!="water":
    q.elev=7+(y%3);q.terrainShape="cliff";q.erase("roundedBase");q.surfaceTop="grass";q.surfaceRock="gray";q.tree=y%2==0
   city.tiles[i]=q
 # Support the true visible summit at +40, rather than a smoothed single-cell spike.
 for i in rectangle(30,2,32,4):
  check(not reserved.has(i),"Summit remains outside settlement grading")
  city.tiles[i].elev=40;city.tiles[i].surfaceTop="snow";city.tiles[i].tree=false
 # Low shores get level beach/grass banks; high cliff banks stay high.
 for y in range(52):
  for x in range(52):
   var i=at(x,y);var q=t(x,y)
   if q.terrain=="water" or reserved.has(i) or q.elev>=7:continue
   var shore=false
   for j in city.neighbors(i):
    if city.tiles[j].terrain=="water" and G.water_height(city.tiles[j])==0:shore=true
   if shore:
    flat(x,y,0);q.biome="desert" if (y>30 or x>44) else "grass";q.tree=q.biome=="grass" and (x+y)%4==0
func road(x:int,y:int):
 var i=at(x,y);var q=t(x,y)
 if q.road:return
 check(not(q.zone or q.civic),"Road footprint clear")
 if q.terrain!="water" and not reserved.has(i):flat(x,y)
 check(city.place(i,"road",q.terrain=="water"),"Road placement %d,%d"%[x,y])
 q.pipe=true;q.line=q.terrain!="water";q.tree=false
func street(x1:int,y1:int,x2:int,y2:int):
 check(x1==x2 or y1==y2,"Aligned street")
 for y in range(mini(y1,y2),maxi(y1,y2)+1):
  for x in range(mini(x1,x2),maxi(x1,x2)+1):road(x,y)
func civic(x:int,y:int,kind:String):
 var i=at(x,y);var q=t(x,y)
 if q.terrainShape=="rounded":flat(x,y)
 check(city.place(i,kind),"Civic placement "+kind+" "+str(Vector2i(x,y)))
 q.pipe=true;q.line=false;q.tree=false
 if kind=="tower":q.storage=180
func lot(x:int,y:int,w:int,h:int,kind:String,level:int,area:String):
 var cells=rectangle(x,y,x+w-1,y+h-1)
 var height=C.foundation_height(city.tiles,cells[0])
 for i in cells:
  check(city.can_place(i,kind),"Usable lot "+str(i))
  check(absf(C.foundation_height(city.tiles,i)-height)<.00001,"Level multi-tile foundation "+str(i))
 var id=city.nextParcelId;city.nextParcelId+=1
 for i in cells:
  check(city.place(i,kind,false,id),"Zone placement "+str(i))
  var q=city.tiles[i];q.level=level;q.autoGrow=true;q.line=false;q.tree=false
 districts[area]=districts.get(area,0)+1
 if not roots.has(area):roots[area]=[]
 roots[area].append(cells[0])
func campus(x:int,y:int):
 for p in [[0,0,"school"],[3,0,"hospital"],[0,3,"fire"],[3,3,"police"]]:civic(x+p[0],y+p[1],p[2])
 for yy in range(y,y+4):
  for xx in range(x,x+4):
   if t(xx,yy).civic:continue
   if (xx+yy)%3==0:civic(xx,yy,"park")
   else:t(xx,yy).tree=true
func networks():
 for x in [12,17,22,27]:street(x,12,x,32)
 for y in [12,17,22,27,32]:street(12,y,31,y)
 # The valley road descends from the city, through forest to the lower town.
 street(31,17,31,47);street(31,46,47,46)
 for y in [24,26,29,31]:street(30,y,31,y)
 # Road bridge across the narrow river, with flat dry landings.
 street(31,17,49,17);street(49,11,49,17)
 for x in [12,17,22,27]:street(x,39,x,44)
 for y in [39,44]:street(12,y,27,y)
 street(22,32,22,39)
 for x in [35,39,43,47]:street(x,42,x,50)
 for y in [42,46,50]:street(35,y,47,y)
 street(31,42,35,42)
 # Flat rail loop around the lower city; no rail is put on a slope.
 var rail_cells=[]
 for x in range(12,28):rail_cells.append(at(x,22));rail_cells.append(at(x,32))
 for y in range(23,32):rail_cells.append(at(12,y));rail_cells.append(at(27,y))
 for i in rail_cells:check(city.place(i,"rail"),"Level city rail loop")
 for xy in [[19,22],[27,25],[20,32],[12,25]]:civic(xy[0],xy[1],"station")
func neighborhoods():
 for row in range(4):
  for col in range(3):
   var x=13+col*5;var y=13+row*5
   if [col,row] in [[0,1],[2,3]]:campus(x,y);continue
   if [col,row]==[1,2]:
    lot(x,y,3,3,"apt",3,"Central city")
    for xx in range(x,x+4):civic(xx,y+3,"park")
    for yy in range(y,y+3):civic(x+3,yy,"park")
    continue
   for dy in [0,2]:
    for dx in [0,2]:
     var xx=x+dx;var yy=y+dy
     var kind="apt" if (row+col+dx+dy)%3 else "office"
     if row==3 and col==0:kind="shop"
     var height=C.foundation_height(city.tiles,at(xx,yy))
     var level=3 if row in [1,2] else 2
     var square=rectangle(xx,yy,xx+1,yy+1)
     var aligned=true
     for i in square:
      if absf(C.foundation_height(city.tiles,i)-height)>.00001:aligned=false
     if aligned:lot(xx,yy,2,2,kind,level,"Upper terrace" if height>5 else "Central city")
     else:
      for i in square:
       if i%52 in [x,x+3] or int(i/52) in [y,y+3]:lot(i%52,int(i/52),1,1,"res" if (i%3) else "shop",2,"Hillside homes")
 # Employment district, with woodland between it and the two residential areas.
 for col in range(3):
  var x=13+col*5
  for dx in [0,2]:
   for dy in [0,2]:
    var kind="heavy" if col==0 else "light" if col==1 else "office"
    lot(x+dx,40+dy,2,2,kind,3,"Works and offices")
 # Low-rise single plots around the town's perimeter roads, with planted gardens.
 for row in range(2):
  for col in range(3):
   var x=36+col*4;var y=43+row*4
   if [col,row]==[1,1]:
    for p in [[0,0,"school"],[2,0,"hospital"],[0,2,"police"],[2,2,"fire"]]:civic(x+p[0],y+p[1],p[2])
    civic(x+1,y+1,"park");continue
   for yy in range(y,y+3):
    for xx in range(x,x+3):
     if xx==x+1 and yy==y+1:t(xx,yy).tree=true;continue
     var kind="shop" if yy==y and ((xx+col)%3==0) else "res"
     lot(xx,yy,1,1,kind,1 if kind=="shop" else 2,"Lakeside town")
 # Slope-side detached homes expose the new level foundation pads.
 for y in [24,26,29,31]:lot(29,y,1,1,"res",2,"Hillside homes")
 for xy in [[10,21],[10,23],[10,26]]:
  if not t(xy[0],xy[1]).road:
   street(xy[0],xy[1],12,xy[1]);lot(xy[0],xy[1]-1,1,1,"res",2,"Hillside homes")
 for xy in [[28,24],[28,26],[28,29],[28,31],[34,41],[36,41],[40,41],[46,41]]:
  var q=t(xy[0],xy[1])
  if q.terrain!="water" and not(q.zone or q.road or q.civic):civic(xy[0],xy[1],"park")
 # Four power plants, two in the industrial district and two off the valley road.
 for xy in [[13,45],[15,45],[30,37],[32,38]]:civic(xy[0],xy[1],"plant")
 civic(28,20,"tower");civic(34,47,"tower")
 # Find four real shore pump sites clear of roads and reserved lots.
 for target in [Vector2(34,25),Vector2(36,37),Vector2(45,40),Vector2(35,19)]:
  var best=-1;var distance=INF
  for i in range(W.COUNT):
   var q=city.tiles[i]
   if q.terrain=="water" or q.zone or q.civic or q.road:continue
   var waterside=false
   for j in city.neighbors(i):
    if city.tiles[j].terrain=="water":waterside=true
   var d=Vector2(i%52,int(i/52)).distance_to(target)
   if waterside and d<distance:best=i;distance=d
  check(best>=0,"Shore pump site exists")
  if best>=0:civic(best%52,int(best/52),"pump")
func connect_civics():
 for start in range(W.COUNT):
  if not city.tiles[start].civic:continue
  var queue=[start];var seen={start:-1};var head=0;var found=-1
  while head<queue.size():
   var i=queue[head];head+=1
   if city.tiles[i].line:found=i;break
   for n in city.neighbors(i):
    var q=city.tiles[n]
    if seen.has(n) or q.terrain=="water" or q.zone or q.civic:continue
    seen[n]=i;queue.append(n)
  check(found>=0,"Civic connects to the network "+str(start))
  while found>=0 and found!=start:
   var q=city.tiles[found];q.line=true;q.pipe=true;q.tree=false;found=seen[found]
func thin_trees():
 # One defined forest around the western upland pond; open ground elsewhere.
 for i in range(W.COUNT):
  var q=city.tiles[i]
  var x=i%52;var y=int(i/52)
  var garden=q.tree and ((x in range(12,29) and y in range(12,33)) or (x in range(35,48) and y in range(42,51)))
  q.tree=false
  if q.terrain=="water" or q.biome=="desert" or q.elev>=15 or q.zone or q.civic or q.road or q.rail or q.line:continue
  var distance=pow((x-4.)/5.8,2)+pow((y-23.)/8.5,2)
  var density=.64 if distance<1. else .18 if distance<1.45 else .045
  if garden:density=.35
  q.tree=W._hash(x,y,city.seed+43)<density
func verify(c,label:String):
 check(c!=null,label+" imports")
 if c==null:return
 check(c.stats.population>=2000,label+" populated main city")
 check(c.stats.net>0,label+" positive income")
 check(c.stats.unpowered==0 and c.stats.unwatered==0,label+" all utilities served")
 check(c.stats.unemployment<20,label+" sufficient jobs")
 for p in c._parcels.values():
  check(c.road_near(p.root),label+" property road access "+str(p.root))
  var height=C.build_height(c.tiles[p.root])
  for i in p.members:check(absf(C.build_height(c.tiles[i])-height)<.00001,label+" level footprint")
 for i in range(W.COUNT):
  var q=c.tiles[i]
  check(not(q.tree and (q.zone or q.road or q.line or q.civic or q.rail)),label+" clear tree footprints")
  check(G.valid_grade(q),label+" valid corner metadata")
  if q.civic and q.civic!="plant":check(c.fields.power[i]>0 and c.fields.water[i]>0,label+" serviced civic "+str(i))
  if q.road:
   for n in c.neighbors(i):
    if c.tiles[n].road:check(C.road_link(c.tiles,i,n),label+" connected road grade")
 # Main city and town must be in one road component through the valley.
 var pending=[at(12,22)];var seen={pending[0]:true};var head=0
 while head<pending.size():
  var i=pending[head];head+=1
  for n in c.neighbors(i):
   if c.tiles[n].road and not seen.has(n) and C.road_link(c.tiles,i,n):seen[n]=true;pending.append(n)
 check(seen.has(at(47,50)),label+" city and town share a connected route")
 print(label," ",JSON.stringify({"pop":c.stats.population,"jobs":c.stats.jobs,"net":c.stats.net,"unpowered":c.stats.unpowered,"unwatered":c.stats.unwatered,"unemployment":c.stats.unemployment}))
func street_showcase()->Dictionary:
 var result={"park_plaza":0,"park_garden":0,"street_lamp_e":0,"street_lamp_s":0,"street_barrier":0,"parked_police":0,"parked_ambulance":0,"parked_garbage":0,"graded_roads":0}
 for i in range(W.COUNT):
  var q=city.tiles[i]
  if q.civic=="park":result[F.park_style(city.seed,i)]+=1
  if q.road:
   var mask=0
   var x=i%52;var y=int(i/52)
   for pair in [[i-52,1,y>0],[i+1,2,x<51],[i+52,4,y<51],[i-1,8,x>0]]:
    if pair[2] and city.tiles[pair[0]].road and C.road_link(city.tiles,i,pair[0]):mask|=pair[1]
   for detail in F.road_details(city.tiles,i,mask):result[detail.sprite]+=1
   var corners=G.corners(city.tiles,i)
   if maxf(maxf(corners[0],corners[1]),maxf(corners[2],corners[3]))-minf(minf(corners[0],corners[1]),minf(corners[2],corners[3]))>.001:result.graded_roads+=1
  if q.civic:
   var role=F.parked_role(q,i,city.seed)
   if not role.is_empty() and not F.curb(city.tiles,[i]).is_empty():result["parked_"+role]+=1
 for parcel in city._parcels.values():
  var role=F.parked_role(city.tiles[parcel.root],parcel.root,city.seed)
  if not role.is_empty() and not F.curb(city.tiles,parcel.members).is_empty():result["parked_"+role]+=1
 for key in result:check(result[key]>0,"Latest art represented: "+key)
 check(G.sample(city.tiles,at(31,3))>=39.999,"Visible summit reaches +40")
 check(W.COST.raise==0 and W.COST.mountain==0 and W.COST.smooth==0,"Current game has free Terraform")
 return result
func run():
 var args=OS.get_cmdline_user_args();var out=args[0] if not args.is_empty() else "/tmp/summit-bay"
 DirAccess.make_dir_recursive_absolute(out)
 city=W.new(241026);city.cash=2000000;city.year=2019;city.month=5;city.tick=232;city.randomDisasters=false
 city.funding={"road":115,"police":110,"fire":115,"school":110,"hospital":110};city.taxes={"res":8,"com":8,"ind":8}
 for i in range(W.COUNT):city.tiles[i]=W.blank_tile();city.tiles[i].elev=1
 platforms();landscape();networks();neighborhoods();connect_civics()
 for r in range(3):city.recalculate()
 for m in range(24):city.step()
 for r in range(90):city.advance_agents(.6)
 thin_trees()
 city.recalculate();city.events.clear();city.messages.clear();city.milestones=[500,1000,2500]
 city.notify("Summit Bay: terraced city, Lakeside village, snowy range, river bridge, forest lake, sandstone mesas and a dry quarry.","good")
 city.notify("Visit the fountain and garden squares, service campuses and work district. All Terraform tools are now free; explore without charging your city.")
 verify(city,"INITIAL")
 var text=S.export_json(city);var copy=S.import_json(text)
 verify(copy,"IMPORTED")
 if copy!=null:check(JSON.parse_string(JSON.stringify(copy.tiles))==JSON.parse_string(JSON.stringify(city.tiles)),"Every tile survives JSON roundtrip")
 var counts={"water":0,"trees":0,"rounded":0,"cliff":0,"grade_corners":0,"desert":0,"snow":0,"roads":0,"bridges":0,"rail":0,"foundations":0,"high_peaks":0,"low_basins":0,"blank_flat":0}
 var materials:Dictionary={};var min_height=30;var max_height=-5
 for q in city.tiles:
  for key in ["water","trees","rounded","cliff","grade_corners","desert","snow","roads","bridges","rail","foundations","high_peaks","low_basins","blank_flat"]:
   var yes=q.terrain=="water" if key=="water" else q.tree if key=="trees" else q.terrainShape==key if key in ["rounded","cliff"] else q.has("gradeCorners") if key=="grade_corners" else q.biome=="desert" if key=="desert" else q.get("surfaceTop","")=="snow" if key=="snow" else q.road if key=="roads" else q.road and q.terrain=="water" if key=="bridges" else q.rail if key=="rail" else q.has("foundationHeight") if key=="foundations" else q.elev>=20 if key=="high_peaks" else q.elev<0 and q.terrain!="water" if key=="low_basins" else q.terrain!="water" and q.terrainShape=="flat" and not(q.tree or q.road or q.zone or q.civic or q.line or q.rail)
   if yes:counts[key]+=1
  min_height=mini(min_height,q.elev);max_height=maxi(max_height,q.elev)
  materials[q.get("surfaceTop","biome")]=true
 check(counts.water>250 and counts.rounded>500 and counts.cliff>60 and counts.grade_corners>100,"Substantial terrain variety")
 check(counts.high_peaks>30 and counts.snow>10 and counts.low_basins>0,"Snowy high country and negative dry basin")
 check(counts.bridges>=2 and counts.foundations>=4 and counts.rail>=40,"Construction variety and sloped foundations")
 var later=null
 if copy!=null:
  for m in range(24):copy.step()
  verify(copy,"AFTER24");check(copy.cash>city.cash,"Treasury grows during continued play");later=copy.stats
 var showcase=street_showcase()
 showcase["moving_cars"]=city.cars.size();showcase["moving_trains"]=city.trains.size()
 var graded_routes=0
 for car in city.cars:
  for i in car.path:
   if city.tiles[i].has("gradeCorners"):
    graded_routes+=1;break
 showcase["cars_with_graded_routes"]=graded_routes
 check(graded_routes>0,"Traffic routes include graded roads")
 var report={"showcase":showcase,"schema":city.serialize().version,"size":[52,52],"seed":city.seed,"districts":districts,"district_roots":roots,"terrain":counts,"materials":materials.keys(),"height_range":[min_height,max_height],"initial_stats":city.stats,"after24_stats":later,"initial_cash":city.cash,"after24_cash":copy.cash if copy!=null else 0,"checks":checks,"sha256":text.sha256_text(),"failures":failures}
 var f=FileAccess.open(out+"/validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 if not failures.is_empty():
  for message in failures.slice(0,30):push_error(message)
  print("FAILED ",failures.size()," / ",checks);quit(1);return
 f=FileAccess.open(out+"/MetroForge-Summit-Bay-0.3.17.json",FileAccess.WRITE);f.store_string(text);f.close()
 print("SUMMIT BAY VERIFIED ",JSON.stringify(counts)," checks=",checks);quit()
