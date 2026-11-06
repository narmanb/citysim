extends SceneTree
## Actual native import and phone-layout captures of the new reporting interface.
const S=preload("res://persistence/city_store.gd")
var game
var out:String
func _initialize():call_deferred("run")
func shot(name:String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var pixels=root.get_texture().get_image();assert(pixels.save_png(out+"/"+name)==OK)
func run():
 var args=OS.get_cmdline_user_args();assert(args.size()==1 and DisplayServer.get_name()!="headless")
 out=args[0];DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,591);root.content_scale_size=Vector2i(854,394);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var source=ProjectSettings.globalize_path("res://../examples/summit-bay/MetroForge-Summit-Bay-0.3.17.json").simplify_path()
 var city=S.import_json(FileAccess.get_file_as_string(source));assert(city!=null)
 for month in range(12):city.step()
 var demo=out+"/Report-Demo.json";var f=FileAccess.open(demo,FileAccess.WRITE);f.store_string(S.export_json(city));f.close()
 game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.paused=true
 game._native_action="import";game._on_file_selected(demo)
 assert(game.world.cityHistory==city.cityHistory and game.world.cityHistory.size()==13,"Native import preserves all real recorded months")
 game.view.set_process(false);game._toast.hide();game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 game.view.fit_city();await shot("city-traffic.png")
 var selected=-1
 for i in game.world.tiles.size():
  if game.world.tiles[i].zone=="res" and game.world.tiles[i].level>0:selected=i;break
 game._on_selection(selected);game.open_dialog("report")
 var before=game.world.serialize();var rng=game.world._rng.state
 for section in ["Overview","Growth","History","Challenges"]:
  game._report_panel.select_section(section)
  await shot("report-"+section.to_lower()+".png")
 assert(before==game.world.serialize() and rng==game.world._rng.state,"Report viewing mutates neither city nor randomness")
 game._start_challenge("commutes");game._toast.hide();game._report_panel.select_section("Challenges")
 var challenge=game.world.serialize();await shot("report-active-challenge.png")
 assert(challenge==game.world.serialize() and game.world.scenario.elapsed==0,"Preview cannot age the active challenge")
 var result={"native_file_import":true,"save_version":game.world.serialize().version,"real_history_months":game.world.cityHistory.size(),"all_sections_read_only":true,"challenge_no_view_progress":true,"population":game.world.stats.population,"renderer":RenderingServer.get_video_adapter_name()}
 f=FileAccess.open(out+"/report-capture-results.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("PASS native Report, growth, history, challenges, phone layout and read-only UI")
 game.queue_free();await process_frame;quit()
