extends SceneTree
const W=preload("res://model/city_world.gd")
const E=preload("res://model/terrain_editor.gd")
const S=preload("res://persistence/city_store.gd")
const F=preload("res://view/street_furniture.gd")
var game
var out="/workspace/artifacts/MetroForge-0.3.17"
func _initialize():call_deferred("run")
func shot(name):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image();assert(image.save_png(out+"/"+name)==OK);return image
func run():
 var args=OS.get_cmdline_user_args()
 if not args.is_empty():out=args[0]
 DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(854,480);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var w=W.new(41)
 for i in W.COUNT:w.tiles[i]=W.blank_tile()
 w.cash=1000000
 var c=18*52+22
 assert(E.commit(w,E.plan(w,E.footprint(c,1),"raise",4,null,{"smooth_edges":true})).changed)
 for x in range(8,31):assert(w.place(18*52+x,"road"))
 for y in range(7,32):
  if not w.tiles[y*52+14].road:assert(w.place(y*52+14,"road"))
 for x in [10,12,16,18,20,24]:assert(w.place(17*52+x,"park"))
 assert(w.place(19*52+11,"police"));assert(w.place(19*52+13,"hospital"))
 var r=19*52+8
 for i in [r,r+1,r+52,r+53]:assert(w.place(i,"light",false,77));w.tiles[i].level=2;w.tiles[i].occupancy=10
 while F.parked_role(w.tiles[r],r,w.seed).is_empty():w.seed+=1
 w.recalculate();w.cars=[{"path":range(c-5,c+6),"p":2.4,"speed":.5},{"path":[c+5,c+4,c+3,c+2,c+1,c,c-1,c-2,c-3,c-4,c-5],"p":2.4,"speed":.5}];w.trains=[]
 assert(S.import_json(S.export_json(w))!=null)
 var before=S.export_json(w)
 game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.set_process(false);game.set_world(w);game.view.set_process(false)
 game.find_child("PerformanceDisplay",true,false)._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 game.choose_tool("pan");game._toast.hide()
 await process_frame;await process_frame
 game.view.tile_scale=32;game.view.camera=game.view.size*.5-game.view._point(18,19,2)*32/28.
 var cached=await shot("parks-streets-and-vehicles.png")
 game.view._cached_world=null;game.view.refresh()
 var full=await shot("full-rebuild.png")
 assert(cached.get_data()==full.get_data(),"Retained/full pixels differ")
 assert(S.export_json(w)==before,"Rendering changed saved city")
 game.view.tile_scale=45;game.view.camera=game.view.size*.5-game.view._point(15,29,0)*45/28.
 await shot("street-details-close.png")
 game.view.tile_scale=55;game.view.camera=game.view.size*.5-game.view._point(12,19,0)*55/28.
 await shot("parked-service-vehicles.png")
 game.choose_tool("mountain");await shot("free-terraform-controls.png")
 var layercounts={"objects":game.view.metrics.static_objects,"layers":game.view.metrics.static_layers}
 var f=FileAccess.open(out+"/capture-results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"cached_full_equal":true,"saved_city_unchanged":true,"import_roundtrip":true,"metrics":layercounts},"  "))
 print("PASS native art/ground contacts, import, unchanged saved city, exact cached/full pixels")
 game.queue_free();await process_frame;quit()
