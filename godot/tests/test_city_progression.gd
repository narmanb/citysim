extends SceneTree
const W=preload("res://model/city_world.gd")
const S=preload("res://persistence/city_store.gd")
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 var city=W.new(24)
 if not city.has_method("city_report") or not city.has_method("start_challenge"):
  check(false,"World must integrate Report, monthly history and challenges")
  for failure in failures:push_error(failure)
  quit(1);return
 var filename=ProjectSettings.globalize_path("res://../examples/summit-bay/MetroForge-Summit-Bay-0.3.17.json").simplify_path()
 city=S.import_json(FileAccess.get_file_as_string(filename))
 check(city!=null,"Existing13 Summit Bay imports")
 if city==null:quit(1);return
 check(city.serialize().version==14,"Feedback data uses save14")
 check(city.cityHistory.size()==1,"Legacy history starts at the current month")
 var history=city.cityHistory.duplicate(true);var scenario=city.scenario.duplicate(true)
 var before=city.serialize();var rng=city._rng.state
 city.city_report();city.challenge_definitions();city.challenge_progress()
 check(city.serialize()==before and city._rng.state==rng,"Reading all report sections is model/RNG-neutral")
 city.recalculate();city.recalculate()
 check(city.cityHistory==history and city.scenario==scenario,"Recalculation does not advance history or challenge time")
 check(city.start_challenge("growth"),"A normal supplied city can start the growth challenge")
 check(not city.start_challenge("clean"),"An active challenge cannot be silently replaced")
 for month in range(2):city.step()
 check(city.scenario.status=="active" and city.scenario.streak==2,"Two actual months do not finish a three-month goal")
 var saved=S.export_json(city);var restored=S.import_json(saved)
 check(restored!=null,"Current city with history and active challenge imports")
 if restored!=null:
  check(restored.cityHistory==city.cityHistory and restored.scenario==city.scenario,"Monthly history and challenge deadline/progress roundtrip exactly")
  restored.step()
  check(restored.scenario.status=="won","Saved two-month challenge wins on the next actual month")
  var end=restored.cityHistory.size();var tick=restored.tick
  restored.step()
  check(restored.tick==tick+1 and restored.cityHistory.size()==end+1,"Winning leaves the city running and recording")
  restored.abandon_challenge();check(restored.scenario.is_empty(),"Explicit abandon returns to sandbox")
 var invalid=city.serialize();invalid.cityHistory[0].month=99999999
 check(S.import_json(JSON.stringify(invalid))==null,"History beyond the city calendar rejects safely")
 invalid=city.serialize();invalid.scenario.id="unknown"
 check(S.import_json(JSON.stringify(invalid))==null,"Invalid challenge data rejects safely")
 invalid=city.serialize();invalid.scenario.lastTick=city.tick+1
 check(S.import_json(JSON.stringify(invalid))==null,"Future challenge progress rejects safely")
 var stable=city.cityHistory.size();var cash=city.cash
 check(city.place(51*52+51,"raise") or city.tiles[51*52+51].terrain=="water","Free Terraform remains usable")
 check(city.cash==cash and city.cityHistory.size()==stable,"Construction creates neither cost nor a fake historical month")
 for failure in failures:push_error(failure)
 print("City progression: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
