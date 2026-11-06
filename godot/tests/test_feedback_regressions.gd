extends SceneTree
const W=preload("res://model/city_world.gd")
const H=preload("res://model/city_history.gd")
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 var file=ProjectSettings.globalize_path("res://../examples/summit-bay/MetroForge-Summit-Bay-0.3.17.json").simplify_path()
 var w=W.from_dict(JSON.parse_string(FileAccess.get_file_as_string(file)))
 check(w.start_challenge("growth"),"Established city starts the utility-dependent challenge")
 w.step();w.step();var approval_before=w.cityHistory.back().approval
 check(w.scenario.streak==2,"Fixture is one month away from winning")
 w.funding.fire=0
 for q in w.tiles:
  if q.civic=="plant":q.fire=5.
 w.step()
 check(w.scenario.status=="active" and w.scenario.streak==0,"Utilities destroyed on a qualifying month prevent a false challenge victory")
 check(w.stats.unpowered>0 and w.stats.unwatered>0,"Monthly consumers see post-disaster utility failures immediately")
 check(w.cityHistory.back().approval<approval_before,"The same month's history reflects the damaged city")
 var base=W.new(24)
 for i in W.COUNT:base.tiles[i]=W.blank_tile()
 base.tiles[200].merge({"zone":"res","zoneType":"house","resType":"house","level":1,"occupancy":100},true)
 base.tiles[2500].civic="plant";base.funding.fire=0
 var a=W.from_dict(base.serialize());var b=W.from_dict(base.serialize())
 a.tiles[2500].fire=5.
 a.step();b.step()
 check(a.tiles[200].occupancy==b.tiles[200].occupancy,"Incident refresh does not apply a third occupancy decay")
 var point=H.sample(base);point.approval=50.5
 check(H.validate([point]) and H.normalize([point])[0].approval==50.5,"Valid fractional history retains its exact numeric value")
 w=W.new(24)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.recalculate();var i=100
 w.tiles[i].merge({"zone":"res","resType":"house","zoneType":"house","level":1},true);w.tiles[i+1].road=true
 w.fields.power[i]=1;w.fields.water[i]=1;w.fields.landValue[i]=48;w.fields.pollution[i]=0;w.fields.crime[i]=0;w.fields.school[i]=0;w.fields.hospital[i]=0;w.fields.trafficImpact[i]=0
 w.demand.res=35;w.stats.jobs=100
 while W._hash(i,w.tick,w.seed)*16-8<1:w.tick+=1
 var explanation=" ".join(w.city_report(i).growth).to_lower()
 check("variation" in explanation and not "holding back the next growth stage" in explanation,"Borderline growth explains monthly variation rather than a definite block")
 w._population_develop()
 check(w.tiles[i].level==2,"The borderline property is genuinely eligible in this monthly selection")
 for failure in failures:push_error(failure)
 print("Feedback regressions: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
