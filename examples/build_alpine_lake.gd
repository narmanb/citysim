extends SceneTree
## Creates a version11 playable terrain showcase; does not modify the game.
const W=preload("res://model/city_world.gd")
const S=preload("res://persistence/city_store.gd")
const G=preload("res://model/terrain_geometry.gd")
var city
var failures:Array[String]=[]
var district:Dictionary={}
var district_roots:Dictionary={}
var checks=0
func _initialize():call_deferred("run")
func at(x:int,y:int)->int:return y*52+x
func t(x:int,y:int)->Dictionary:return city.tiles[at(x,y)]
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func flatten(x:int,y:int,height:int=1):
 var q=t(x,y);q.elev=height;q.terrainShape="flat";q.erase("roundedBase");q.erase("surfaceTop");q.erase("surfaceRock");q.tree=false
func land():
 var peaks=[[6,6,26],[9,15,30],[6,25,27],[10,35,29],[6,45,25]]
 for y in range(52):
  for x in range(52):
   var q=W.blank_tile();var n=W._noise(x*.19,y*.16,city.seed)
   var h=2.+n*4.+2.*sin(x*.23+y*.18)*sin(y*.11)
   for p in peaks:
    var d=pow((x-p[0])/5.2,2)+pow((y-p[1])/7.2,2)
    h=maxf(h,1.+(p[2]-1)*exp(-d*1.35))
   q.elev=clampi(roundi(h),1,30);q.terrainShape="rounded";q.roundedBase=1
   if x<15 and q.elev>=17:q.surfaceTop="snow"
   q.tree=q.elev<16 and W._hash(x,y,city.seed+5)<(.70 if n>.52 else .39)
   var lake=pow((x-42.)/8.4,2)+pow((y-28.)/11.5,2)+.13*sin(y*.8+x*.4)<1.
   lake=lake or (x in range(38,43) and y in range(14,21))
   var island=pow((x-44.)/1.6,2)+pow((y-29.)/2.,2)<1.
   if lake and not island:q=W.blank_tile("water")
   if island:q.elev=2;q.tree=true
   # Sandy, stepped mesa country beyond the lakeside town.
   if x>=47 and y>=43 and q.terrain!="water":
    q.biome="desert";q.surfaceTop="sand";q.surfaceRock="sand";q.tree=false
    q.elev=5 if x<50 else 8;q.terrainShape="cliff";q.erase("roundedBase")
   city.tiles[at(x,y)]=q
 # Irregular beaches and low banks around the natural lake.
 for y in range(52):
  for x in range(52):
   var q=t(x,y)
   if q.terrain=="water":continue
   var waterside=false
   for i in city.neighbors(at(x,y)):
    if city.tiles[i].terrain=="water":waterside=true
   if waterside:
    flatten(x,y);q.biome="desert" if (y>32 or x>44) else "grass"
    q.tree=q.biome=="grass" and (x+y)%3==0
func road(x:int,y:int):
 var q=t(x,y);check(not q.zone and not q.civic,"Road footprint clear")
 if q.terrain!="water":flatten(x,y)
 q.road=true;q.pipe=true;q.line=q.terrain!="water";q.tree=false
func street(x1:int,y1:int,x2:int,y2:int):
 check(x1==x2 or y1==y2,"Axis-aligned street")
 for y in range(mini(y1,y2),maxi(y1,y2)+1):
  for x in range(mini(x1,x2),maxi(x1,x2)+1):road(x,y)
func civic(x:int,y:int,kind:String):
 var q=t(x,y)
 check(q.terrain!="water" and not(q.zone or q.road or q.civic),"Civic footprint clear at %d,%d"%[x,y])
 flatten(x,y);q.civic=kind;q.pipe=true;q.line=false
 if kind=="tower":q.storage=180
func lot(x:int,y:int,w:int,h:int,kind:String,level:int,area:String):
 var id=city.nextParcelId;city.nextParcelId+=1
 for yy in range(y,y+h):
  for xx in range(x,x+w):
   var q=t(xx,yy)
   check(q.terrain!="water" and not(q.zone or q.road or q.civic),"Parcel footprint clear at %d,%d"%[xx,yy])
   flatten(xx,yy)
   q.zone="res" if kind in ["house","apt"] else "com" if kind in ["shop","office"] else "ind"
   q.zoneType=kind;q.resType=kind if q.zone=="res" else null
   q.parcel=id;q.level=level;q.autoGrow=true;q.line=false
 district[area]=district.get(area,0)+1
 if not district_roots.has(area):district_roots[area]=[]
 district_roots[area].append(at(x,y))
func campus(x:int,y:int):
 for p in [[0,0,"school"],[3,0,"hospital"],[0,3,"fire"],[3,3,"police"]]:civic(x+p[0],y+p[1],p[2])
 for yy in range(y,y+4):
  for xx in range(x,x+4):
   if t(xx,yy).civic:continue
   if (xx+yy)%4==0:civic(xx,yy,"park")
   else:t(xx,yy).tree=true
func networks():
 # Two parallel carriageways with a planted median: existing road simulation.
 street(30,1,30,50);street(32,1,32,50)
 for y in [5,17,34,41,48]:street(28,y,34,y)
 for y in range(1,51):
  if not t(31,y).road:
   flatten(31,y);t(31,y).tree=y%2==0
 # Compact foothill city blocks.
 for x in [16,21,26,30]:street(x,7,x,32)
 for y in [7,12,17,22,27,32]:street(16,y,30,y)
 # A southern employment district, linked through a wooded road cutting.
 street(23,32,23,37)
 for x in [18,23,28]:street(x,37,x,46)
 for y in [37,42,46]:street(18,y,32,y)
 # Lakefront town faces the south shore; its promenade follows dry land.
 for y in [41,45,49]:street(34,y,46,y)
 for x in [34,38,42,46]:street(x,41,x,49)
 street(32,41,34,41);street(32,49,34,49)
 # Scenic causeway over the narrow northern lake inlet.
 street(30,16,49,16)
 street(49,9,49,16)
 street(45,9,49,9)
 # Dune-top lookout reached from the town, with a winding foothill road north.
 street(46,49,49,49)
 street(16,5,23,5);street(23,5,23,7)
func places():
 for bj in range(5):
  for bi in range(3):
   var x=17+bi*5;var y=8+bj*5
   var width=4 if bi<2 else 3
   if [bi,bj] in [[0,1],[2,3]]:
    # The narrow eastern civic block fits three columns.
    if width==4:campus(x,y)
    else:
     for p in [[0,0,"school"],[2,0,"hospital"],[0,3,"fire"],[2,3,"police"]]:civic(x+p[0],y+p[1],p[2])
    continue
   if bi==0 and bj in [0,4]:
    for xx in range(x,x+width):
     lot(xx,y,1,1,"house",2,"Foothill gardens");lot(xx,y+3,1,1,"house",1,"Foothill gardens")
    for xx in range(x,x+width):
     for yy in [y+1,y+2]:t(xx,yy).tree=true
   elif [bi,bj]==[1,2]:
    lot(x,y,3,3,"apt",3,"Central city")
    for xx in range(x,x+4):
     if not t(xx,y+3).zone:civic(xx,y+3,"park")
   else:
    for oy in [0,2]:
     for ox in ([0,2] if width==4 else [0]):
      var kind="apt" if (bi+bj+ox+oy)%3 else "office" if bj in [2,3] else "shop"
      if (bi==1 and bj==1) or (bi==2 and bj==2):kind="office"
      lot(x+ox,y+oy,2,2,kind,3 if bj in [1,2,3] else 2,"Central city")
    if width==3:
     for yy in range(y,y+4):
      if yy%2==0:lot(x+2,yy,1,1,"shop",2,"Central city")
      else:t(x+2,yy).tree=true
 # Industry is buffered from the town by woods and the divided road.
 for x in [19,24]:
  for y in [38,43]:
   lot(x,y,2,2,"light",3,"Works district")
   if y==38:lot(x+2,y,2,2,"heavy",3,"Works district")
   else:lot(x+2,y,2,2,"office",3,"Works district")
 civic(19,41,"plant");civic(21,41,"plant");civic(27,41,"plant");civic(25,41,"fire")
 # Low-rise cottages, small apartments and shops by the lake.
 for by in [42,46]:
  for bx in [35,39,43]:
   if bx==39 and by==46:
    civic(bx,by,"school");civic(bx+2,by,"hospital");civic(bx,by+2,"police");civic(bx+2,by+2,"fire")
    continue
   for xx in range(bx,bx+3):
    lot(xx,by,1,1,"house",2,"Lakeside town")
    lot(xx,by+2,1,1,"shop" if xx==bx+1 else "house",1,"Lakeside town")
 # Small lakefront parks between the beaches and village streets.
 for x in [35,37,41,43,45]:
  if t(x,40).terrain!="water":civic(x,40,"park")
 civic(29,9,"tower");civic(33,44,"tower")
 # Waterside pumps: choose real dry shore cells rather than guess lake geometry.
 for target in [Vector2(34,25),Vector2(34,34),Vector2(43,39)]:
  var best=-1;var distance=999.
  for i in range(W.COUNT):
   var q=city.tiles[i]
   if q.terrain=="water" or q.zone or q.civic or q.road:continue
   var shore=false
   for n in city.neighbors(i):
    if city.tiles[n].terrain=="water":shore=true
   var d=Vector2(i%52,int(i/52)).distance_to(target)
   if shore and d<distance:best=i;distance=d
  check(best>=0,"Pump has a shore location")
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
  check(found>=0,"Civic connects to utility grid")
  while found>=0 and found!=start:
   var q=city.tiles[found];q.line=true;q.pipe=true;q.tree=false;found=seen[found]
func verify(c,label:String):
 check(c!=null,label+" imports")
 if c==null:return
 check(c.tiles.size()==2704,label+" full52 map")
 check(c.stats.population>=1500,label+" populated city")
 check(c.stats.net>0,label+" positive budget")
 check(c.stats.unpowered==0 and c.stats.unwatered==0,label+" serviced buildings")
 check(c.stats.unemployment<20,label+" jobs available")
 for p in c._parcels.values():
  check(c.road_near(p.root),label+" parcel road access")
  for i in p.members:
   var q=c.tiles[i];check(q.elev==c.tiles[p.root].elev and q.terrainShape=="flat",label+" level foundations")
 for q in c.tiles:
  check(not(q.tree and (q.zone or q.road or q.line or q.civic)),label+" clear footprints")
 print(label," ",JSON.stringify({"pop":c.stats.population,"jobs":c.stats.jobs,"net":c.stats.net,"power":[c.stats.powerUsed,c.stats.powerGenerated],"water":[c.stats.waterUsed,c.stats.waterCapacity],"unpowered":c.stats.unpowered,"unwatered":c.stats.unwatered,"unemployment":c.stats.unemployment}))
func run():
 var args=OS.get_cmdline_user_args();var out=args[0] if not args.is_empty() else "/tmp/alpine-lake"
 DirAccess.make_dir_recursive_absolute(out)
 city=W.new(187203);city.cash=850000;city.year=2015;city.month=6;city.tick=186;city.randomDisasters=false
 city.funding={"road":110,"police":110,"fire":115,"school":110,"hospital":110}
 city.taxes={"res":8,"com":8,"ind":8}
 land();networks();places();connect_civics()
 for r in range(4):city.recalculate()
 for month in range(24):city.step()
 for r in range(90):city.advance_agents(.6)
 city.recalculate();city.events.clear();city.messages.clear();city.milestones=[500,1000]
 city.notify("Alpine Lake: a mountain city, wooded ridge country, divided valley road and a lakeside town.","good")
 city.notify("Explore the snowy western range, North Inlet causeway, lakeside promenade and southeastern sandstone mesas.")
 verify(city,"INITIAL")
 var text=S.export_json(city)
 var copy=S.import_json(text)
 if copy==null:
  push_error("Import failed: "+S.last_error)
  quit(1);return
 verify(copy,"IMPORTED")
 check(copy!=null and JSON.parse_string(JSON.stringify(copy.tiles))==JSON.parse_string(JSON.stringify(city.tiles)) and copy.cash==city.cash,"Exact native save roundtrip")
 var counts={"water":0,"trees":0,"rounded":0,"desert":0,"roads":0,"high_peaks":0,"blank_flat":0}
 for q in city.tiles:
  if q.terrain=="water":counts.water+=1
  if q.tree:counts.trees+=1
  if q.terrainShape=="rounded":counts.rounded+=1
  if q.biome=="desert":counts.desert+=1
  if q.road:counts.roads+=1
  if q.elev>=20:counts.high_peaks+=1
  if q.terrain!="water" and q.terrainShape=="flat" and not(q.tree or q.road or q.zone or q.civic or q.line):counts.blank_flat+=1
 check(counts.water>=230 and counts.rounded>=1100 and counts.trees>=500,"Large lake and terrain variety")
 check(counts.high_peaks>=30 and counts.blank_flat<80,"Substantial range with little blank flat land")
 for month in range(24):
  copy.step()
  for r in range(3):copy.advance_agents(.6)
 verify(copy,"AFTER24")
 check(copy.cash>city.cash,"Playable city grows its treasury")
 var report={"schema":11,"size":[52,52],"seed":city.seed,"districts":district,"district_roots":district_roots,"terrain":counts,"initial_stats":city.stats,"after24_stats":copy.stats,"initial_cash":city.cash,"after24_cash":copy.cash,"checks":checks,"sha256":text.sha256_text(),"failures":failures}
 var f=FileAccess.open(out+"/validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 if not failures.is_empty():
  for failure in failures:push_error(failure)
  quit(1);return
 f=FileAccess.open(out+"/MetroForge-Alpine-Lake.json",FileAccess.WRITE);f.store_string(text);f.close()
 print("ALPINE LAKE VERIFIED ",JSON.stringify(counts));quit()
