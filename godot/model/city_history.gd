extends RefCounted
## Immutable bounded monthly records; no wall-clock or rendering dependence.
const Report=preload("res://model/city_report.gd")
const KEYS=["month","population","jobs","cash","net","crime","pollution","traffic","approval"]
const LIMIT=240
static func _number(value)->bool:return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<=1.e15
static func _integer(value)->bool:return _number(value) and float(value)==floor(float(value))
static func sample(world)->Dictionary:
 var report:Dictionary=Report.evaluate(world)
 return {"month":world.year*12+world.month-1,"population":int(world.stats.get("population",0)),"jobs":int(world.stats.get("jobs",0)),"cash":float(world.cash),"net":float(world.stats.get("net",0)),"crime":float(report.summary.crime),"pollution":float(report.summary.pollution),"traffic":float(world.stats.get("congestion",0)),"approval":int(report.approval)}
static func record(history:Array,point:Dictionary)->Array:
 var out:Array=history.duplicate(true)
 if not validate([point]):return out
 if not out.is_empty() and float(out.back().month)>=float(point.month):return out
 out.append(normalize([point])[0])
 if out.size()>LIMIT:out=out.slice(out.size()-LIMIT)
 return out
static func validate(value)->bool:
 if not value is Array or value.size()>LIMIT:return false
 var previous:float=-INF
 for point in value:
  if not point is Dictionary or point.size()!=KEYS.size():return false
  for key in KEYS:
   if not point.has(key) or not _number(point[key]):return false
  if not _integer(point.month) or absf(float(point.month))>1.e10 or float(point.month)<=previous:return false
  previous=float(point.month)
  for key in ["population","jobs"]:
   if not _integer(point[key]) or point[key]<0 or point[key]>1000000000:return false
  for key in ["crime","pollution","traffic","approval"]:
   if point[key]<0 or point[key]>100:return false
 return true
static func normalize(value)->Array:
 if not validate(value):return []
 var out:Array=[]
 for point in value:
  var copy:Dictionary={}
  for key in KEYS:copy[key]=int(point[key]) if key in ["month","population","jobs"] else float(point[key])
  out.append(copy)
 return out
