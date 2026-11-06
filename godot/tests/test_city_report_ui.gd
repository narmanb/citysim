extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func _initialize():call_deferred("run")
func run():
 if not FileAccess.file_exists("res://ui/city_report_panel.gd") or not FileAccess.file_exists("res://ui/history_plot.gd"):
  check(false,"Native Report panel and history chart are required")
 else:
  var Panel=load("res://ui/city_report_panel.gd")
  var p=Panel.new();p.size=Vector2(650,310);root.add_child(p)
  var report={"approval":62,"headline":"Traffic needs attention","summary":{"population":800,"jobs":720,"employed":700,"unemployment":12,"congestion":70,"commuteUnserved":100,"avgCommute":8.5,"net":120},"issues":[{"id":"traffic","title":"Busy roads","severity":70,"description":"Improve routes between homes and jobs.","overlay":"traffic"}],"growth":["Power is missing."],"growthTitle":"Housing property"}
  var points:Array=[]
  for n in range(15):points.append({"month":24000+n,"population":100+n*10,"jobs":120,"cash":-200+n*20,"net":-10,"crime":20,"pollution":12,"traffic":40,"approval":62})
  var definitions=[{"id":"growth","title":"Growing Community","description":"Reach1,000 residents with services.","duration":60,"available":true}]
  var starts:Array=[];var overlays:Array=[]
  p.challenge_start_requested.connect(func(id):starts.append(id))
  p.overlay_requested.connect(func(key):overlays.append(key))
  p.present(report,points,definitions,{})
  await process_frame;await process_frame
  check(p.get_combined_minimum_size().x<=650,"Report fits the phone modal width")
  check(p.find_child("Approval",true,false)!=null,"Approval is visible")
  for section in ["Overview","Growth","History","Challenges"]:
   p.select_section(section);await process_frame;await process_frame
   check(p.get_combined_minimum_size().x<=650,"Section remains within phone width: "+section)
  var start=p.find_child("Start_growth",true,false)
  check(start!=null,"Challenge has a clear start action")
  if start!=null:start.pressed.emit()
  check(starts==["growth"],"Start emits the selected challenge only after activation")
  p.select_section("Overview");await process_frame
  var show=p.find_child("Overlay_traffic",true,false)
  if show!=null:show.pressed.emit()
  check(overlays==["traffic"],"Ranked problem can open its actual city overlay")
  p.select_section("History");await process_frame
  var plot=p.find_child("HistoryPlot",true,false)
  check(plot!=null,"History shows a native chart")
  if plot!=null:
   plot.set_series(points,"cash",12);await process_frame
   check(plot.samples.size()==12 and plot.range_min<0 and plot.range_max>0,"History window includes negative cash correctly")
   plot.set_series([{"month":24000,"population":3510},{"month":24001,"population":3530}],"population",12);await process_frame
   check(plot._number(plot.range_min)!=plot._number(plot.range_max),"Close population values retain distinct readable axis labels")
   plot.set_series([],"population",12);await process_frame
   check(plot.samples.is_empty(),"No history remains an empty chart")
   plot.set_series([{ "month":24000,"population":0}],"population",12);await process_frame
   check(plot.range_max>plot.range_min,"A flat or one-point series has valid axes")
  p.queue_free();await process_frame
 root.size=Vector2i(854,394);root.content_scale_size=Vector2i(854,394)
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.paused=true
 await process_frame;await process_frame
 var world_before=game.world.serialize();var rng_before=game.world._rng.state
 game.open_dialog("report");await process_frame;await process_frame
 check(game._report_panel!=null,"Report is reachable through the actual game dialog")
 check(Rect2(Vector2.ZERO,Vector2(854,394)).encloses(game._dialog_panel.get_global_rect()),"Actual Report modal fits landscape phone dimensions")
 for section in ["Overview","Growth","History","Challenges"]:
  game._report_panel.select_section(section);await process_frame;await process_frame
 check(game.world.serialize()==world_before and game.world._rng.state==rng_before,"Opening all actual Report sections does not change simulation/save state")
 var start=game._report_panel.find_child("Start_growth",true,false)
 if start!=null:start.pressed.emit()
 check(game.world.scenario.get("id")=="growth" and game.world.scenario.get("elapsed")==0,"Actual start action creates a challenge without aging it")
 var abandon=game._report_panel.find_child("AbandonChallenge",true,false)
 if abandon!=null:abandon.pressed.emit()
 check(game.world.scenario.is_empty(),"Actual abandon action restores sandbox")
 game.close_dialog();game.queue_free();await process_frame
 for failure in failures:push_error(failure)
 print("City Report UI: %d failures"%failures.size());quit(0 if failures.is_empty() else 1)
