extends SceneTree
const W=preload("res://model/city_world.gd")
const C=preload("res://model/scenario_system.gd")
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 var w=W.new(24)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.recalculate();w.tick=0
 w.tiles[100].zone="res";w.tiles[100].level=1;w.tiles[100].occupancy=400
 w.fields.pollution[100]=60.
 w.stats.merge({"population":400,"jobs":500,"employed":360,"unemployment":10,"congestion":80,"unpowered":0,"unwatered":0,"net":10},true)
 var state:Dictionary=C.start(w,"commutes")
 check(state.targets.congestion==52. and state.targets.population==360,"Commute targets use fixed starting conditions")
 var before=state.duplicate(true);w.stats.congestion=50;w.tick=1
 var progressed=C.update(w,state)
 check(state==before and progressed.streak==1,"Challenge transition leaves prior state untouched")
 check(C.update(w,progressed)==progressed,"Duplicate tick cannot add another qualifying month")
 w.stats.population=350;w.tick=2;progressed=C.update(w,progressed)
 check(progressed.streak==0,"Demolishing away the population cannot solve congestion")
 w.stats.population=400;w.tick=3;progressed=C.update(w,progressed)
 var loaded=C.normalize(JSON.parse_string(JSON.stringify(progressed,"",true,true)))
 check(loaded==progressed and loaded.lastTick is int,"JSON numeric types normalize without changing progress")
 w.tick=4;loaded=C.update(w,loaded);w.tick=5;loaded=C.update(w,loaded)
 check(loaded.status=="won","Commute goals can win after a resumed three-month streak")
 var won=loaded.duplicate(true);w.tick=100;w.stats.congestion=100
 check(C.update(w,loaded)==won,"A completed challenge remains completed while city play continues")
 w.tick=0;w.stats.congestion=80;w.stats.population=400;w.stats.unemployment=10
 state=C.start(w,"commutes");w.stats.congestion=50;w.tick=3
 check(C.update(w,state).streak==1,"Skipped months do not fabricate a successful streak")
 var last=state.duplicate(true);last.lastTick=33;last.elapsed=33
 check(C.validate(last),"Valid saved deadline fixture")
 for tick in [34,35,36]:w.tick=tick;last=C.update(w,last)
 check(last.status=="won" and last.elapsed==36,"Goals may finish on the last allowed month")
 w.tick=0;var late=C.start(w,"commutes");w.tick=37;late=C.update(w,late)
 check(late.status=="lost","Meeting goals after the deadline does not win")
 var bad=state.duplicate(true);bad.targets.population=1
 check(not C.validate(bad),"Imported targets cannot silently relax the fixed goals")
 bad=state.duplicate(true);bad.baseline.congestion=INF
 check(not C.validate(bad),"Infinite baseline rejects")
 bad=state.duplicate(true);bad.duration=true
 check(not C.validate(bad),"Boolean deadline rejects")
 bad=state.duplicate(true);bad.status="won";bad.streak=2
 check(not C.validate(bad),"A forged win without a full streak rejects")
 w.tick=0;w.stats.population=400;w.stats.unemployment=10;w.fields.pollution[100]=60.
 var clean=C.start(w,"clean")
 check(is_equal_approx(clean.targets.pollution,39.),"Clean target uses resident-weighted starting pollution")
 w.fields.pollution[100]=20.;w.stats.unwatered=1;w.tick=1;clean=C.update(w,clean)
 check(clean.streak==0,"Pollution challenge still requires water")
 w.stats.unwatered=0;w.stats.unemployment=21;w.tick=2;clean=C.update(w,clean)
 check(clean.streak==0,"Pollution challenge cannot ignore unemployment")
 w.stats.unemployment=20
 for tick in [3,4,5]:w.tick=tick;clean=C.update(w,clean)
 check(clean.status=="won","Cleaner neighborhoods challenge can complete")
 check(C.validate({}) and C.normalize({}).is_empty(),"Sandbox has no compulsory challenge")
 check(C.start(w,"unknown").is_empty(),"Unknown challenge cannot start")
 for failure in failures:push_error(failure)
 print("City challenges: %d checks, %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
