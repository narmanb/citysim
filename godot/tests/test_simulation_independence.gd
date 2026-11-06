extends SceneTree
const W=preload("res://model/city_world.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 var filename=ProjectSettings.globalize_path("res://../examples/summit-bay/MetroForge-Summit-Bay-0.3.17.json").simplify_path()
 var data=JSON.parse_string(FileAccess.get_file_as_string(filename))
 var a=W.from_dict(data);var b=W.from_dict(data)
 check(a!=null and b!=null,"Existing populated city imports twice")
 if a==null or b==null:quit(1);return
 var next_tick=18
 while W._hash(next_tick,11,a.seed)<=.88 or int(next_tick/18)%3==2:next_tick+=18
 a.tick=next_tick-1;b.tick=next_tick-1;a.randomDisasters=true;b.randomDisasters=true
 a.cars.clear();b.cars.clear();a.trains.clear();b.trains.clear()
 for n in range(12):a.advance_agents(.6)
 check(a.cars.size()>b.cars.size(),"Fixture actually exercises different animation cadences")
 check(a._rng.state==b._rng.state,"Animation must not consume authoritative simulation randomness")
 a.step();b.step();a.recalculate();b.recalculate()
 check(a.events==b.events and a.tiles==b.tiles,"Later automatic disaster targets and damage are independent of animation cadence")
 check(a.stats==b.stats and a.demand==b.demand,"Future employment, traffic and growth remain authoritative")
 for failure in failures:push_error(failure)
 print("Simulation independence: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
