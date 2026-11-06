extends RefCounted
## Optional current-city challenges. Pure transitions, advanced only by model ticks.
const Report=preload("res://model/city_report.gd")
const KEYS=["id","status","startTick","lastTick","elapsed","duration","streak","baseline","targets"]
static func definitions()->Array:
 return [
  {"id":"growth","title":"Growing Community","description":"Reach 1,000 residents with power, water and a positive monthly budget.","duration":60,"minimum_population":0},
  {"id":"commutes","title":"Clearer Commutes","description":"Reduce starting congestion by 35% (target floor 20%), retain 90% of residents and keep unemployment at 15% or lower.","duration":36,"minimum_population":100},
  {"id":"clean","title":"Cleaner Neighborhoods","description":"Reduce resident pollution by 35% (target floor 10), retain 90% of residents, supply utilities and keep unemployment at 20% or lower.","duration":48,"minimum_population":100}]
static func _definition(id:String)->Dictionary:
 for item in definitions():
  if item.id==id:return item
 return {}
static func _number(value)->bool:return (value is int or value is float) and is_finite(float(value))
static func _integer(value)->bool:return _number(value) and float(value)==floor(float(value)) and value>=0 and value<=1000000000
static func _targets(id:String,baseline:Dictionary)->Dictionary:
 if id=="growth":return {"population":1000}
 var targets={"population":maxi(100,ceili(float(baseline.population)*.9))}
 if id=="commutes":targets.congestion=maxf(20.,float(baseline.congestion)*.65)
 else:targets.pollution=maxf(10.,float(baseline.pollution)*.65)
 return targets
static func start(world,id:String)->Dictionary:
 var definition:Dictionary=_definition(id)
 if definition.is_empty() or not _integer(world.tick):return {}
 var c:Dictionary=Report.conditions(world)
 if int(c.population)<int(definition.minimum_population):return {}
 var baseline={"population":int(c.population),"congestion":float(c.congestion),"pollution":float(c.pollution)}
 var state={"id":id,"status":"active","startTick":world.tick,"lastTick":world.tick,"elapsed":0,"duration":definition.duration,"streak":0,"baseline":baseline,"targets":_targets(id,baseline)}
 return state if validate(state) else {}
static func _eligible(world,state:Dictionary)->bool:
 var c:Dictionary=Report.conditions(world)
 if int(c.population)<int(state.targets.population):return false
 match state.id:
  "growth":return c.net>0 and c.unpowered==0 and c.unwatered==0
  "commutes":return c.congestion<=state.targets.congestion and c.unemployment<=15
  "clean":return c.pollution<=state.targets.pollution and c.unpowered==0 and c.unwatered==0 and c.unemployment<=20
 return false
static func update(world,value:Dictionary)->Dictionary:
 var state:Dictionary=normalize(value)
 if state.is_empty() or state.status!="active" or not _integer(world.tick) or world.tick<=state.lastTick:return state
 var gap:int=int(world.tick)-int(state.lastTick)
 state.lastTick=int(world.tick);state.elapsed=int(world.tick)-int(state.startTick)
 if state.elapsed>state.duration:
  state.status="lost";state.streak=0;return state
 if _eligible(world,state):state.streak=mini(3,int(state.streak)+1) if gap==1 else 1
 else:state.streak=0
 if state.streak>=3:state.status="won"
 elif state.elapsed>=state.duration:state.status="lost"
 return state
static func validate(value)->bool:
 if not value is Dictionary:return false
 if value.is_empty():return true
 if value.size()!=KEYS.size():return false
 for key in KEYS:
  if not value.has(key):return false
 if not value.id is String or not value.status is String:return false
 var definition:Dictionary=_definition(value.id)
 if definition.is_empty() or value.status not in ["active","won","lost"]:return false
 for key in ["startTick","lastTick","elapsed","duration","streak"]:
  if not _integer(value[key]):return false
 if value.duration!=definition.duration or value.lastTick<value.startTick or value.elapsed!=value.lastTick-value.startTick or value.streak>3 or value.streak>value.elapsed:return false
 if value.status=="active" and (value.elapsed>=value.duration or value.streak>=3):return false
 if value.status=="won" and (value.streak!=3 or value.elapsed<3 or value.elapsed>value.duration):return false
 if value.status=="lost" and (value.elapsed<value.duration or value.streak>=3):return false
 if not value.baseline is Dictionary or value.baseline.size()!=3 or not value.targets is Dictionary:return false
 for key in ["population","congestion","pollution"]:
  if not value.baseline.has(key) or not _number(value.baseline[key]):return false
 if not _integer(value.baseline.population) or value.baseline.population<definition.minimum_population:return false
 for key in ["congestion","pollution"]:
  if value.baseline[key]<0 or value.baseline[key]>100:return false
 var targets:Dictionary=_targets(value.id,value.baseline)
 if value.targets.size()!=targets.size():return false
 for key in targets:
  if not value.targets.has(key) or not _number(value.targets[key]) or not is_equal_approx(float(value.targets[key]),float(targets[key])):return false
 return true
static func normalize(value)->Dictionary:
 if not validate(value) or value.is_empty():return {}
 var state:Dictionary={"id":value.id,"status":value.status}
 for key in ["startTick","lastTick","elapsed","duration","streak"]:state[key]=int(value[key])
 state.baseline={"population":int(value.baseline.population),"congestion":float(value.baseline.congestion),"pollution":float(value.baseline.pollution)}
 state.targets=_targets(state.id,state.baseline)
 return state
static func progress(world,value:Dictionary)->Array[String]:
 var out:Array[String]=[]
 var state:Dictionary=normalize(value)
 if state.is_empty():return out
 var c:Dictionary=Report.conditions(world)
 out.append("Residents: %d / at least %d"%[int(c.population),int(state.targets.population)])
 if state.id=="growth":out.append("Monthly budget: $%d / above $0"%int(c.net))
 if state.id=="commutes":out.append("Traffic: %d%% / at most %.1f%%"%[int(c.congestion),float(state.targets.congestion)])
 if state.id=="clean":out.append("Resident pollution: %.1f / at most %.1f"%[float(c.pollution),float(state.targets.pollution)])
 if state.id in ["growth","clean"]:out.append("Developed properties missing utilities: %d power · %d water / both zero"%[int(c.unpowered),int(c.unwatered)])
 if state.id!="growth":out.append("Unemployment: %d%% / at most %d%%"%[int(c.unemployment),15 if state.id=="commutes" else 20])
 return out
