extends SceneTree
## Content generator for the existing 0.3.19 APK; no engine/map-size changes.
## godot --headless --path godot --script /absolute/path/examples/build_three_valleys.gd -- OUTPUT
const W=preload("res://model/city_world.gd")
const S=preload("res://persistence/city_store.gd")
const E=preload("res://model/terrain_editor.gd")
const G=preload("res://model/terrain_geometry.gd")
const C=preload("res://model/civil_engineering.gd")
const FILE="MetroForge-Three-Valleys-0.3.19.json"
const SEED=6110626
var city
var reserved:Dictionary={}
var roots:Dictionary={}
var checks:=0
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func at(x:int,y:int)->int:return y*W.N+x
func tile(x:int,y:int)->Dictionary:return city.tiles[at(x,y)]
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func rectangle(x1:int,y1:int,x2:int,y2:int)->Array:
 var out:Array=[]
 for y in range(y1,y2+1):
  for x in range(x1,x2+1):out.append(at(x,y))
 return out
func flat(x:int,y:int,h:int=1):
 var q=tile(x,y)
 check(q.terrain!="water","Do not fill a water cell while preparing construction")
 q.elev=h;q.terrainShape="flat";q.slopeDir="auto";q.shapeStrength=1;q.tree=false
 for key in ["gradeCorners","roundedBase","surfaceTop","surfaceRock","foundationHeight"]:q.erase(key)
func platforms():
 # Level settlement centers with the actual free Smooth Edges grading planner.
 for area in [[3,4,25,31,2],[35,5,47,17,1],[35,38,47,50,1]]:
  var proposal=E.plan(city,rectangle(area[0],area[1],area[2],area[3]),"raise",area[4],null,{"smooth_edges":true})
  check(proposal.error.is_empty() and E.commit(city,proposal).changed,"Native settlement grading "+str(area))
  for i in proposal.after:
   reserved[i]=true
   # Preserve dependencies of authored grade corners while composing scenery.
   for yy in range(maxi(0,int(i/W.N)-1),mini(W.N,int(i/W.N)+2)):
    for xx in range(maxi(0,i%W.N-1),mini(W.N,i%W.N+2)):reserved[at(xx,yy)]=true
func landscape():
 var peaks=[[5,44,40],[13,42,35],[20,47,32],[2,50,26]]
 for y in range(W.N):
  for x in range(W.N):
   var i=at(x,y)
   if reserved.has(i):continue
   var q=W.blank_tile()
   var noise=W._noise(x*.19,y*.16,SEED+7)
   var h=1.0+4.0*noise+2.5*pow(sin(x*.24+y*.11),2)
   # Broad foothills link the southern range, rather than isolated pointed cones.
   h+=6.0*exp(-pow((x-19.)/11.,2)-pow((y-38.)/5.8,2))
   for peak in peaks:
    var d=pow((x-peak[0])/5.8,2)+pow((y-peak[1])/5.4,2)
    h=maxf(h,1.+(peak[2]-1.)*exp(-d*.85))
   q.elev=clampi(roundi(h),1,40);q.terrainShape="rounded";q.roundedBase=1
   q.surfaceRock="gray" if y>36 and x<25 else "grass"
   if q.elev>=27:q.surfaceTop="snow"
   elif q.elev>=18:q.surfaceTop="rock"
   # A dry sandstone corner, dunes, escarpments and exposed strata.
   if x>=47 and y>=38:
    q.biome="desert";q.surfaceTop="sand";q.surfaceRock="sand"
    q.elev=4+int((x-47)/2)*3+int((y-38)/6)*2
    if x>=50:
     q.terrainShape="cliff";q.erase("roundedBase")
   if x>=43 and y<=4:
    q.biome="desert";q.surfaceTop="sand";q.surfaceRock="sand";q.elev=3+int((51-x)/3)
   if x in [49,50] and y in range(24,35):
    q.elev=6+int((y-24)/4)*2;q.terrainShape="cliff";q.erase("roundedBase");q.surfaceTop="grass";q.surfaceRock="gray"
   if x>=50 and y>=46:
    q.elev=-3 if x==50 else -5;q.terrainShape="cliff";q.erase("roundedBase");q.surfaceTop="rock";q.surfaceRock="sand"
   # A main river, large lake, outlet and a second river from the western hills.
   var lake=pow((x-40.7)/8.0,2)+pow((y-28.7)/8.0,2)+.09*sin(x*.85+y*.5)<1.
   var river_x=31.8+1.15*sin(y*.27)+maxf(0.,y-18.)*.45
   var river=y<=24 and absf(x-river_x)<1.2
   var outlet_x=35.2-.7*minf(6.,y-30.)+.45*sin((y-30.)*.34)
   var outlet=y>=30 and absf(x-outlet_x)<1.05
   var creek_y=37.2+.8*sin(x*.24)
   var creek=x<=35 and absf(y-creek_y)<.9
   var island=pow((x-42.5)/1.75,2)+pow((y-28.)/2.1,2)<1.
   if lake or river or outlet or creek:
    q=W.blank_tile("water");q.elev=0
   if island:
    q=W.blank_tile();q.elev=2+int(W._noise(x*.4,y*.4,SEED)*2);q.terrainShape="rounded";q.roundedBase=0
   # A small upland pond beside the foothill woodland.
   if pow((x-4.)/1.8,2)+pow((y-34.)/1.7,2)<1.:
    q=W.blank_tile("water");q.elev=5
   # Deliberate grass-topped bluffs and a shallow dry ravine south of Lakehaven.
   if x in range(38,46) and y==51 and q.terrain!="water":
    q.terrainShape="cliff";q.elev=-3 if x<42 else -5;q.erase("roundedBase");q.surfaceTop="rock";q.surfaceRock="brown"
   city.tiles[i]=q
 # Nine supporting cells produce a real +40 surface, not just a hidden control peak.
 for i in rectangle(4,43,6,45):
  city.tiles[i].elev=40;city.tiles[i].surfaceTop="snow";city.tiles[i].tree=false
 # Soft low banks and occasional sandy coves; retain intentional tall bluffs.
 for y in range(W.N):
  for x in range(W.N):
   var i=at(x,y);var q=tile(x,y)
   if q.terrain=="water" or reserved.has(i) or q.elev>8:continue
   var shore=false
   for j in city.neighbors(i):
    if city.tiles[j].terrain=="water" and G.water_height(city.tiles[j])==0.:shore=true
   if shore:
    flat(x,y,0)
    q.biome="desert" if (x>=38 and y>27) or y>36 else "grass"
func road(x:int,y:int):
 var q=tile(x,y);var i=at(x,y)
 if q.road:return
 check(not(q.zone or q.civic),"Road has clear footprint "+str(Vector2i(x,y)))
 if q.terrain!="water" and not reserved.has(i):flat(x,y,1)
 check(city.place(i,"road",q.terrain=="water"),"Legal road "+str(Vector2i(x,y)))
 q.pipe=true;q.line=q.terrain!="water";q.tree=false
func street(x1:int,y1:int,x2:int,y2:int):
 check(x1==x2 or y1==y2,"Straight street")
 for y in range(mini(y1,y2),maxi(y1,y2)+1):
  for x in range(mini(x1,x2),maxi(x1,x2)+1):road(x,y)
func civic(x:int,y:int,kind:String):
 var q=tile(x,y)
 if q.terrainShape=="rounded":flat(x,y)
 check(city.place(at(x,y),kind),"Legal "+kind+" "+str(Vector2i(x,y)))
 q.pipe=true;q.line=false;q.tree=false
 if kind=="tower":q.storage=180
func lot(x:int,y:int,w:int,h:int,kind:String,level:int,district:String):
 var cells=rectangle(x,y,x+w-1,y+h-1)
 var height=C.foundation_height(city.tiles,cells[0])
 for i in cells:
  check(city.can_place(i,kind),"Legal lot "+str(i))
  check(absf(C.foundation_height(city.tiles,i)-height)<.00001,"Level multi-cell foundation "+str(i))
 var id=city.nextParcelId;city.nextParcelId+=1
 for i in cells:
  check(city.place(i,kind,false,id),"Zone placement "+str(i))
  var q=city.tiles[i];q.level=level;q.autoGrow=true;q.tree=false;q.line=false
 if not roots.has(district):roots[district]=[]
 roots[district].append(cells[0])
func campus(x:int,y:int):
 # Four corner sites all directly face the surrounding connected road ring.
 for p in [[0,0,"school"],[3,0,"hospital"],[0,3,"police"],[3,3,"fire"]]:civic(x+p[0],y+p[1],p[2])
 for p in [[1,1],[2,2]]:civic(x+p[0],y+p[1],"park")
func networks():
 for x in [4,9,14,19,24]:street(x,5,x,30)
 for y in [5,10,15,20,25,30]:street(4,y,24,y)
 # Valley arterial with two city entrances and a second northern river crossing.
 street(24,10,36,10);street(24,20,27,20);street(27,10,27,44)
 street(24,5,27,5);street(27,1,27,10);street(27,1,46,1);street(46,1,46,6)
 # Small town grids; the lake separates them both visually and geographically.
 for x in [36,41,46]:street(x,6,x,16);street(x,39,x,49)
 for y in [6,11,16,39,44,49]:street(36,y,46,y)
 street(27,44,36,44)
 # A short parallel bypass and scenic bridge across the western tributary.
 street(28,20,28,40);street(27,20,28,20);street(27,40,28,40)
func town(x:int,y:int,district:String):
 for row in range(2):
  for col in range(2):
   var xx=x+col*5;var yy=y+row*5
   if row==0 and col==1:campus(xx,yy);continue
   for dy in range(4):
    for dx in range(4):
     if dx in [1,2] and dy in [1,2]:continue
     var kind="shop" if dy==0 and dx in [0,3] else "res"
     lot(xx+dx,yy+dy,1,1,kind,2 if kind=="res" else 1,district)
   civic(xx+1,yy+1,"park")
func neighborhoods():
 for row in range(4):
  for col in range(4):
   var x=5+col*5;var y=6+row*5
   if [col,row] in [[0,0],[3,1],[1,2],[2,3]]:campus(x,y);continue
   if [col,row]==[1,1]:
    lot(x,y,3,3,"apt",4,"Granite City")
    for xx in range(x,x+4):civic(xx,y+3,"park")
    for yy in range(y,y+3):civic(x+3,yy,"park")
    continue
   for dy in [0,2]:
    for dx in [0,2]:
     var kind="apt" if row in [1,2] else "shop" if (row+col+dx+dy)%3==0 else "office"
     var level=4 if kind=="office" else 3 if kind=="apt" or col in [1,2] else 2
     lot(x+dx,y+dy,2,2,kind,level,"Granite City")
 # A distinct work district between the city and the western river.
 for col in range(4):
  for dy in [0,2]:
   for dx in [0,2]:
    lot(5+col*5+dx,26+dy,2,2,"heavy" if col==0 else "light" if col in [1,2] else "office",4 if col in [0,3] else 3,"Granite Works")
 town(37,7,"Riverbend")
 town(37,40,"Lakehaven")
 # Modest workshops sit outside the housing rings with explicit street frontage.
 for row in [11,44]:
  street(46,row,48,row);street(48,row,48,row+4)
  for yy in [row+1,row+2]:flat(49,yy)
  lot(49,row+1,1,2,"light",3,"Riverbend workshops" if row==11 else "Lakehaven workshops")
 # Genuine one-cell foundations on the city's Gentle graded western fringe.
 for y in [12,17,22]:
  street(2,y,4,y)
  lot(2,y-1,1,1,"res",2,"Hillside homes")
 # Power is generated on each bank; no hidden electricity across water.
 for xy in [[5,31],[8,31],[20,31],[35,17],[35,48]]:
  if tile(xy[0],xy[1]).terrainShape=="rounded":flat(xy[0],xy[1])
  civic(xy[0],xy[1],"plant")
 civic(25,24,"tower");civic(47,15,"tower");civic(47,47,"tower")
 # Real shore pumps near the two rivers, each attached below to land utilities.
 for target in [Vector2(29,11),Vector2(26,33),Vector2(35,21),Vector2(35,37)]:
  var best=-1;var distance=INF
  for i in range(W.COUNT):
   var q=city.tiles[i]
   if q.terrain=="water" or q.zone or q.civic or q.road:continue
   var shore=false
   for j in city.neighbors(i):
    if city.tiles[j].terrain=="water" and G.water_height(city.tiles[j])==0.:shore=true
   var d=Vector2(i%W.N,int(i/W.N)).distance_to(target)
   if shore and d<distance:best=i;distance=d
  check(best>=0,"Real shore pump site exists")
  if best>=0:
   flat(best%W.N,int(best/W.N),0)
   civic(best%W.N,int(best/W.N),"pump")
func connect_civics():
 for start in range(W.COUNT):
  if not city.tiles[start].civic:continue
  var pending=[start];var seen={start:-1};var head=0;var found=-1
  while head<pending.size():
   var i=pending[head];head+=1
   if city.tiles[i].line:found=i;break
   for j in city.neighbors(i):
    var q=city.tiles[j]
    if seen.has(j) or q.terrain=="water" or q.civic:continue
    seen[j]=i;pending.append(j)
  check(found>=0,"Civic has a land utility connection "+str(start))
  while found>=0 and found!=start:
   var q=city.tiles[found];q.line=not q.zone;q.pipe=true;q.tree=false;found=seen[found]
func vegetation():
 for i in range(W.COUNT):
  var q=city.tiles[i];var x=i%W.N;var y=int(i/W.N)
  q.tree=false
  if q.terrain=="water" or q.biome=="desert" or q.elev>=18 or q.zone or q.civic or q.road or q.rail or q.line:continue
  var forest=pow((x-6.)/7.,2)+pow((y-33.)/4.8,2)
  var density=.50 if forest<1. else .13 if forest<1.65 else .055
  if x in range(41,45) and y in range(26,31):density=.5
  q.tree=W._hash(x,y,SEED+43)<density
func road_component(c,start:int)->Dictionary:
 var pending=[start];var seen={start:true};var head=0
 while head<pending.size():
  var i=pending[head];head+=1
  for j in c.neighbors(i):
   if c.tiles[j].road and not seen.has(j) and C.road_link(c.tiles,i,j):seen[j]=true;pending.append(j)
 return seen
func verify_waterways():
 var start=at(32,0);var pending=[start];var seen={start:true};var head=0
 check(city.tiles[start].terrain=="water","Northern river enters the region")
 while head<pending.size():
  var i=pending[head];head+=1
  for j in city.neighbors(i):
   if city.tiles[j].terrain=="water" and G.water_height(city.tiles[j])==0. and not seen.has(j):seen[j]=true;pending.append(j)
 for i in [at(40,28),at(0,37),at(31,51)]:check(seen.has(i),"Connected river, lake, tributary and outlet "+str(i))
 for i in range(W.COUNT):
  if city.tiles[i].terrain=="water" and G.water_height(city.tiles[i])==0.:check(seen.has(i),"No disconnected sea-level water fragment")
func district_stats(c)->Dictionary:
 var result:Dictionary={}
 for district in roots:
  var entry={"population":0,"jobs":0,"properties":roots[district].size()}
  for i in roots[district]:
   if c.tiles[i].zone=="res":entry.population+=c.tiles[i].occupancy
   else:entry.jobs+=c.tiles[i].occupancy
  result[district]=entry
 return result
func verify(c,label:String):
 check(c!=null,label+" imports")
 if c==null:return
 check(c.stats.population>=2500,label+" substantial city population")
 check(c.stats.net>0,label+" positive budget")
 check(c.stats.unpowered==0 and c.stats.unwatered==0,label+" supplied developed properties")
 check(c.stats.unemployment<=15,label+" accessible employment")
 check(c.stats.abandoned==0,label+" no abandoned properties")
 var component=road_component(c,at(4,10))
 for i in [at(46,16),at(46,49)]:check(component.has(i),label+" connected settlement "+str(i))
 for p in c._parcels.values():
  check(c.road_near(p.root),label+" property has road access "+str(p.root))
  var height=C.build_height(c.tiles[p.root])
  for i in p.members:check(absf(C.build_height(c.tiles[i])-height)<.00001,label+" level parcel footprint")
 for i in range(W.COUNT):
  var q=c.tiles[i]
  check(G.valid_grade(q),label+" valid terrain metadata")
  check(not(q.tree and (q.road or q.rail or q.line or q.zone or q.civic)),label+" clear tree footprint")
  check(not q.fire and not q.damage,label+" undamaged tile")
  if q.civic and q.civic!="plant":check(c.fields.power[i]>0 and c.fields.water[i]>0,label+" civic utilities "+str(i))
  if q.civic in W.SERVICES:
   var adjacent=false
   for j in c.neighbors(i):
    if component.has(j):adjacent=true
   check(adjacent and c.fields[q.civic][i]>0,label+" actual connected service source "+str(i))
  if q.road:
   for j in c.neighbors(i):
    if c.tiles[j].road:check(C.road_link(c.tiles,i,j),label+" legal road grade")
 var places=district_stats(c)
 check(places["Granite City"].population>8*places.Riverbend.population and places["Granite City"].population>8*places.Lakehaven.population,label+" a dominant city and two smaller towns")
 check(places.Riverbend.population>=90 and places.Lakehaven.population>=90,label+" both small towns inhabited")
 print(label+" "+JSON.stringify({"stats":c.stats,"districts":places}))
func terrain_counts()->Dictionary:
 var result={"water":0,"trees":0,"rounded":0,"cliff":0,"graded":0,"desert":0,"snow":0,"roads":0,"bridges":0,"foundations":0,"highland":0,"dry_negative":0,"grassland":0}
 for q in city.tiles:
  if q.terrain=="water":result.water+=1
  if q.tree:result.trees+=1
  if q.terrainShape=="rounded":result.rounded+=1
  if q.terrainShape=="cliff":result.cliff+=1
  if q.has("gradeCorners"):result.graded+=1
  if q.biome=="desert":result.desert+=1
  if q.get("surfaceTop")=="snow":result.snow+=1
  if q.road:result.roads+=1
  if q.road and q.terrain=="water":result.bridges+=1
  if q.has("foundationHeight"):result.foundations+=1
  if q.elev>=18:result.highland+=1
  if q.elev<0 and q.terrain!="water":result.dry_negative+=1
  if q.terrain!="water" and q.biome=="grass" and q.elev<=5 and not(q.zone or q.civic or q.road or q.line or q.tree):result.grassland+=1
 return result
func numeric_equal(a,b)->bool:
 if (a is int or a is float) and (b is int or b is float):return absf(float(a)-float(b))<=1.e-12
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not numeric_equal(a[i],b[i]):return false
  return true
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in a:
   if not b.has(key) or not numeric_equal(a[key],b[key]):return false
  return true
 return a==b
func run():
 var args=OS.get_cmdline_user_args();var out=args[0] if not args.is_empty() else "/tmp/three-valleys"
 DirAccess.make_dir_recursive_absolute(out)
 city=W.new(SEED);city.cash=2200000;city.year=2020;city.month=1;city.tick=240
 city.randomDisasters=false;city.funding={"road":115,"police":115,"fire":115,"school":115,"hospital":115}
 city.taxes={"res":8,"com":8,"ind":8};city.cityHistory.clear();city.scenario={}
 for i in range(W.COUNT):city.tiles[i]=W.blank_tile();city.tiles[i].elev=1
 platforms();landscape();networks();neighborhoods();connect_civics();vegetation()
 for repeat in range(3):city.recalculate()
 city._record_month()
 # Actual simulation supplies two years of useful graphs, not invented records.
 for month in range(24):city.step()
 for repeat in range(90):city.advance_agents(.6)
 city.recalculate();city.events.clear();city.messages.clear();city.milestones=[500,1000,2500]
 city.notify("Three Valleys: Granite City at the west end, Riverbend in the northeast, Lakehaven beside the southern shore. Explore the snowy range, river valleys and sandstone bluffs.","good")
 city.notify("Report includes two real years of history. All three settlements have connected roads, jobs and utilities. Random disasters are off; growth and free Terraform stay active.")
 verify(city,"INITIAL")
 verify_waterways()
 var counts=terrain_counts()
 check(counts.water>=250 and counts.rounded>=500 and counts.highland>=80,"Substantial rivers, lake, hills and mountains")
 check(counts.desert>=50 and counts.cliff>=20 and counts.snow>=10 and counts.dry_negative>0,"Sandstone, bluffs, snow and dry ravine")
 check(counts.trees>=70 and counts.trees<=220,"Moderate tree count")
 check(counts.bridges>=6 and counts.foundations>=3 and counts.graded>=100,"Bridges and Gentle grading represented")
 check(G.sample(city.tiles,at(5,44))>=39.999,"Actual visible mountain summit reaches +40")
 check(city.cityHistory.size()==25,"Exactly 25 real monthly history samples")
 check(city.scenario.is_empty(),"Sandbox with no forced challenge")
 var text=S.export_json(city)
 check(text.to_utf8_buffer().size()<S.MAX_BYTES,"Native import size limit")
 var restored=S.import_json(text)
 verify(restored,"IMPORTED")
 if restored!=null:
  check(numeric_equal(restored.tiles,city.tiles),"Tile values survive JSON roundtrip")
  check(numeric_equal(restored.cityHistory,city.cityHistory),"History survives JSON roundtrip within 1e-12 numeric precision")
  for month in range(24):restored.step()
  verify(restored,"AFTER24")
  check(restored.cash>city.cash,"Treasury grows over another two years")
 var report={"schema":city.serialize().version,"engine_source_commit":"92162de13932f246927f0eb9d90cb6b879b91269","seed":SEED,"map_size":[W.N,W.N],"checks":checks,"failures":failures,"districts":district_stats(city),"district_roots":roots,"terrain":counts,"initial_stats":city.stats,"after24_stats":restored.stats if restored!=null else {},"initial_cash":city.cash,"after24_cash":restored.cash if restored!=null else 0,"history_months":city.cityHistory.size(),"height_range":[-5,40],"sha256":text.sha256_text()}
 var f=FileAccess.open(out+"/validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 if not failures.is_empty():
  for failure in failures.slice(0,40):push_error(failure)
  print("FAILED ",failures.size()," / ",checks);quit(1);return
 f=FileAccess.open(out+"/"+FILE,FileAccess.WRITE);f.store_string(text);f.close()
 print("THREE VALLEYS VERIFIED ",JSON.stringify(counts)," checks=",checks);quit()
