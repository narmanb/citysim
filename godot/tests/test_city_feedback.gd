extends SceneTree
const W=preload("res://model/city_world.gd")
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 for file in ["city_report","city_history","scenario_system"]:
  if not FileAccess.file_exists("res://model/"+file+".gd"):
   check(false,"City feedback helper is required: "+file)
 if not failures.is_empty():
  for failure in failures:push_error(failure)
  quit(1);return
 var Report=load("res://model/city_report.gd")
 var History=load("res://model/city_history.gd")
 var Scenario=load("res://model/scenario_system.gd")
 var w=W.new(24)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.recalculate()
 var before=w.serialize();var rng=w._rng.state
 var empty:Dictionary=Report.evaluate(w)
 check(empty.approval>=0 and empty.approval<=100,"Empty city has a finite approval and a starting hint")
 check(not empty.headline.is_empty(),"Report has an actionable empty-city headline")
 check(w.serialize()==before and w._rng.state==rng,"Report is read-only and consumes no simulation randomness")
 w.cash=100000;var i=25*52+25
 check(w.place(i,"res"),"Selected housing fixture")
 var selected:Dictionary=Report.evaluate(w,i)
 check("power" in " ".join(selected.growth).to_lower() and "water" in " ".join(selected.growth).to_lower(),"Growth diagnostics explain both missing utilities")
 w.tiles[i].level=1;w.tiles[i].occupancy=10;w.recalculate()
 var baseline:Dictionary=Report.evaluate(w)
 for j in W.COUNT:
  if j!=i:w.fields.pollution[j]=100.;w.fields.crime[j]=100.
 var unused:Dictionary=Report.evaluate(w)
 check(is_equal_approx(float(baseline.summary.pollution),float(unused.summary.pollution)),"Unused land does not determine resident pollution")
 check(is_equal_approx(float(baseline.summary.crime),float(unused.summary.crime)),"Unused land does not determine resident crime")
 check(Report.evaluate(w)==Report.evaluate(w),"Ranked report is deterministic under unchanged conditions")
 var point:Dictionary=History.sample(w)
 check(History.validate([point]),"A real monthly snapshot validates")
 var history:Array=[]
 for month in range(241):
  var p=point.duplicate(true);p.month=24000+month;history=History.record(history,p)
 check(history.size()==240 and history[0].month==24001,"History is bounded to20 years")
 var duplicate=point.duplicate(true);duplicate.month=24240;duplicate.population=99999
 check(History.record(history,duplicate)==history,"Repeating a date cannot rewrite a monthly result")
 var invalid=history.duplicate(true);invalid[1].month=invalid[0].month
 check(not History.validate(invalid),"Duplicate and non-increasing dates reject")
 invalid=history.duplicate(true);invalid[0].cash=INF
 check(not History.validate(invalid),"Non-finite history values reject")
 check(not History.validate({}) and not History.validate(history+[point]),"Wrong shape and oversized history reject")
 w.stats.merge({"population":1200,"jobs":1300,"employed":1200,"unemployment":0,"unpowered":0,"unwatered":0,"net":100,"congestion":70},true)
 var state:Dictionary=Scenario.start(w,"growth")
 check(state.get("status")=="active" and Scenario.validate(state),"Challenge starts with valid saved state")
 var original=state.duplicate(true)
 check(Scenario.update(w,state)==state and state==original,"Viewing/update at the same tick cannot advance a challenge")
 for month in range(3):
  w.tick+=1;state=Scenario.update(w,state)
 check(state.status=="won" and state.streak==3,"Goals win only after3 consecutive real months")
 var deadline:Dictionary=Scenario.start(w,"growth")
 w.stats.population=0;w.tick+=61;deadline=Scenario.update(w,deadline)
 check(deadline.status=="lost","A failed challenge reaches its deadline")
 var invalid_state=original.duplicate(true);invalid_state.id="unknown"
 check(not Scenario.validate(invalid_state),"Unknown saved challenge rejects")
 check(Scenario.start(w,"commutes").is_empty(),"Transport challenge requires an established population")
 check(Scenario.definitions().size()==3,"All three optional challenges are available")
 for failure in failures:push_error(failure)
 print("City feedback: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
