extends RefCounted
## Independently authored, deterministic resident feedback. Never writes city state.
static func _field(world,key:String,index:int)->float:
 var values=world.fields.get(key,[])
 return float(values[index]) if index>=0 and index<values.size() else 0.
static func conditions(world)->Dictionary:
 var s:Dictionary=world.stats
 var out:Dictionary={}
 for key in ["population","jobs","employed","unemployment","congestion","commuteUnserved","avgCommute","net","unpowered","unwatered"]:out[key]=s.get(key,0)
 var people:float=0.;var crime:float=0.;var pollution:float=0.;var education:float=0.;var health:float=0.
 for i in world.tiles.size():
  var q:Dictionary=world.tiles[i]
  if q.zone!="res" or q.occupancy<=0:continue
  var weight:float=float(q.occupancy);people+=weight
  crime+=_field(world,"crime",i)*weight;pollution+=_field(world,"pollution",i)*weight
  education+=weight if _field(world,"school",i)>=.15 else 0.
  health+=weight if _field(world,"hospital",i)>=.15 else 0.
 out.crime=crime/people if people else 0.;out.pollution=pollution/people if people else 0.
 out.schoolCoverage=education/people if people else 0.;out.healthCoverage=health/people if people else 0.
 out.developed=0
 for value in s.get("developed",{}).values():out.developed+=int(value)
 return out
static func evaluate(world,index:int=-1)->Dictionary:
 var s:Dictionary=conditions(world)
 var result={"approval":50,"headline":"Build your first neighborhood","summary":s,"issues":[],"growth":[],"growthTitle":"Select a property"}
 _growth(world,index,result)
 if int(s.population)<=0:return result
 var entries:Array=[]
 var count:float=maxf(1.,float(s.developed))
 _issue(entries,"power","Electricity is missing",100.*float(s.unpowered)/count,"Connect developed properties to an energized network with enough generation.","power")
 _issue(entries,"water","Water supply is missing",100.*float(s.unwatered)/count,"Connect properties to a powered pump or a supplied water tower.","water")
 _issue(entries,"employment","Jobs need better access",(float(s.unemployment)-8.)*2.,"%d residents have no reachable job allocation. Connect homes to workplaces and provide enough jobs."%int(s.commuteUnserved),"traffic")
 _issue(entries,"traffic","Busy roads",(float(s.congestion)-30.)*1.4,"Traffic reflects assigned commuters. Shorter connections and additional routes can relieve busy streets.","traffic")
 _issue(entries,"crime","Residents report crime",(float(s.crime)-25.)*1.7,"Improve powered, watered police access and nearby neighborhood conditions.","crime")
 _issue(entries,"pollution","Pollution affects homes",(float(s.pollution)-20.)*1.5,"Separate homes from industry and power generation; inspect the pollution overlay.","pollution")
 var tax:float=maxf(float(world.taxes.res),maxf(float(world.taxes.com),float(world.taxes.ind)))
 _issue(entries,"taxes","Taxes are high",(tax-9.)*8.,"Review zone taxes against demand and the monthly budget.","")
 if int(s.population)>=120:
  _issue(entries,"services","Schools or health services need access",(1.-minf(float(s.schoolCoverage),float(s.healthCoverage)))*35.,"Education reaches %d%% of residents; health reaches %d%%. Departments need utilities and connected roads."%[roundi(s.schoolCoverage*100.),roundi(s.healthCoverage*100.)],"school" if s.schoolCoverage<s.healthCoverage else "hospital")
 var financial:float=maxf(0.,-float(s.net)/maxf(20.,float(s.population))*15.)
 if world.cash<0:financial=maxf(financial,80.)
 _issue(entries,"budget","Finances need attention",financial,"Review maintenance, department funding and taxes before expanding.","")
 entries.sort_custom(func(a,b):return a.severity>b.severity if a.severity!=b.severity else a.id<b.id)
 var weights={"power":.22,"water":.22,"employment":.20,"traffic":.12,"crime":.14,"pollution":.12,"taxes":.08,"services":.10,"budget":.08}
 var penalty:float=0.
 for issue in entries:penalty+=float(issue.severity)*float(weights[issue.id])
 result.approval=clampi(roundi(90.-penalty),0,100)
 result.issues=entries.filter(func(issue):return issue.severity>=12.)
 result.headline="City conditions are healthy" if result.issues.is_empty() else str(result.issues[0].title)
 return result
static func _issue(out:Array,id:String,title:String,severity:float,description:String,overlay:String):
 out.append({"id":id,"title":title,"severity":clampf(severity,0.,100.),"description":description,"overlay":overlay})
static func _growth(world,index:int,result:Dictionary):
 var reasons:Array[String]=[]
 if index<0 or index>=world.tiles.size():
  result.growth=["Select a zoned tile with Pan, then reopen Report to inspect its growth."];return
 var q:Dictionary=world.tiles[index]
 var parcel:Dictionary=world.parcel_info(index) if q.parcel else {}
 if not parcel.is_empty():index=parcel.root;q=world.tiles[index]
 if not q.zone:
  result.growthTitle="Service site" if q.civic else "Unzoned land"
  result.growth=["Service buildings do not develop through zoning. They need utilities and road access."] if q.civic else ["Paint a Housing, Business or Industrial zone on suitable land to begin development."]
  return
 result.growthTitle=("Housing" if q.zone=="res" else "Business" if q.zone=="com" else "Industrial")+" property"
 var has_road:bool=world.road_near(index)
 var has_power:bool=world.parcel_has(parcel,"power") if not parcel.is_empty() else _field(world,"power",index)>0
 var has_water:bool=world.parcel_has(parcel,"water") if not parcel.is_empty() else _field(world,"water",index)>0
 if not has_road:reasons.append("No road touches this property.")
 if not has_power:reasons.append("Power is missing.")
 if not has_water:reasons.append("Water is missing.")
 if q.fire:reasons.append("An active fire prevents development.")
 if q.abandoned:reasons.append("The property is abandoned; restore access and local conditions for recovery.")
 if float(world.demand.get(q.zone,0))<=0:reasons.append("Demand for this zone is weak.")
 var kind:String=str(q.zoneType if q.zoneType else q.resType if q.resType else "house" if q.zone=="res" else "shop" if q.zone=="com" else "light")
 var maximum:int=(4 if kind=="apt" else 3) if q.zone=="res" else 4 if kind in ["office","heavy"] else 3
 var score:float=world._growth_score(index)
 var threshold:float=17. if q.level==0 else 22.+float(q.level)*19.
 if q.abandoned:
  reasons.append("Monthly variation and local conditions affect recovery selection.")
 elif q.level>=maximum:reasons.append("This building is at its current growth-stage limit.")
 elif score+8.<=threshold:reasons.append("Local demand, land value, pollution, traffic or services are holding back the next growth stage.")
 elif has_road and has_power and has_water and not q.fire:
  if score-8.<=threshold:reasons.append("Monthly variation may allow or delay the next growth stage.")
  else:reasons.append("Basic growth conditions are ready. Development is selected at monthly updates, not immediately.")
 if not q.autoGrow:reasons.append("This property retains its explicit building type. Rezone with a general zone tool to enable automatic density selection.")
 elif not parcel.is_empty() and kind in ["house","shop","light"]:
  var dense:Array[String]=[]
  if world._parcel_flat_square(parcel)<2:dense.append("a level usable area of at least 2×2")
  var pop:int=120 if kind=="house" else 180 if kind=="shop" else 80
  var demand:int=28 if kind=="house" else 25 if kind=="shop" else 42
  var land:float=48. if kind=="house" else 52. if kind=="shop" else 22.
  if int(world.stats.get("population",0))<pop:dense.append("a larger city population")
  if float(world.demand.get(q.zone,0))<demand:dense.append("stronger demand")
  if world._parcel_avg(parcel,"landValue")<land:dense.append("higher land value")
  if score<(46. if kind=="light" else 48.):dense.append("better local growth conditions")
  if kind in ["house","shop"]:
   var coverage:float=(world._parcel_avg(parcel,"school")+world._parcel_avg(parcel,"hospital"))*.5
   if coverage<(.15 if kind=="house" else .10):dense.append("better education and health coverage")
  var roads:Array=world._parcel_roads(parcel);var condition:float=0.
  for road in roads:condition+=world.tiles[road].condition
  condition/=maxi(1,roads.size())
  if condition<(.65 if kind=="light" else .5):dense.append("better road maintenance")
  if kind=="light" and roads.size()<2:dense.append("at least two bordering road tiles")
  if not dense.is_empty():reasons.append("Denser development needs "+", ".join(dense)+".")
  elif has_power and has_water and has_road:reasons.append("Density conditions are adequate; automatic growth keeps a mixture of building types.")
 result.growth=reasons
