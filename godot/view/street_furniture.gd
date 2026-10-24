extends RefCounted
## Deterministic appearance only. No simulation, spending, traffic or save writes.
const W=preload("res://model/city_world.gd")
const N=W.N
static func park_style(seed:int,index:int)->String:
 return "park_plaza" if W._hash(index%N,int(index/N),seed+29)<.5 else "park_garden"
static func road_details(tiles:Array,index:int,mask:int)->Array:
 var q:Dictionary=tiles[index]
 if not q.get("road",false) or q.get("rail",false) or q.get("terrain","grass")=="water":return []
 var x:int=index%N;var y:int=index/N
 if mask in [5,10] and (x+y)%8==0:
  return [{"sprite":"street_lamp_e" if mask==5 else "street_lamp_s","u":.86 if mask==5 else .5,"v":.5 if mask==5 else .86,"span":1.}]
 if mask in [1,4] and (x+y)%3==0:
  return [{"sprite":"street_barrier","u":.12,"v":.85,"span":.8}]
 return []
static func parked_role(tile:Dictionary,index:int,seed:int)->String:
 if tile.get("civic")=="police":return "police"
 if tile.get("civic")=="hospital":return "ambulance"
 if tile.get("zone")=="ind" and tile.get("level",0)>0 and W._hash(index%N,int(index/N),seed+61)<.28:return "garbage"
 return ""
static func curb(tiles:Array,members:Array)->Dictionary:
 var candidates:Dictionary={}
 for i in members:
  var x:int=i%N;var y:int=i/N
  for r in [i-N if y>0 else -1,i+1 if x<N-1 else -1,i+N if y<N-1 else -1,i-1 if x>0 else -1]:
   if r<0:continue
   var q:Dictionary=tiles[r]
   if not q.get("road",false) or q.get("rail",false) or q.get("terrain","grass")=="water":continue
   candidates[r]={"index":r,"u":.5+.32*(x-r%N),"v":.5+.32*(y-int(r/N)),"heading":"SE" if y!=int(r/N) else "SW"}
 var best:Dictionary={};var depth:int=-1
 for r in candidates:
  var d:int=r%N+int(r/N)
  if d>depth or (d==depth and r>best.get("index",-1)):best=candidates[r];depth=d
 return best
static func taxi_sprite(heading:String,rise:float)->String:
 return "car"+heading+("U" if rise>.12 else "D" if rise<-.12 else "")
