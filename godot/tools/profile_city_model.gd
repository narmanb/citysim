## Headless deterministic CPU stage probe; run exclusively, baseline then candidate.
extends SceneTree
func _initialize(): call_deferred("run")
func run():
    if OS.get_cmdline_user_args().size() != 1:
        push_error("--script tools/profile_city_model.gd -- CITY.json")
        quit(1)
        return
    var store=load("res://persistence/city_store.gd")
    var text=FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0])
    var w=store.import_json(text)
    if w==null: push_error(store.last_error);quit(1);return
    var times={}
    for name in ["_terrain_reflow","_parcel_rebuild","_utility_update","_service_update","_environment_update","_population_update","_demand_update","_traffic_prepare","_economy_calculate","recalculate"]:
        var values=[]
        w.call(name)
        for i in range(7):
            var start=Time.get_ticks_usec()
            w.call(name)
            values.append((Time.get_ticks_usec()-start)/1000.0)
        values.sort()
        times[name]=values[values.size()/2]
    var agents=[]
    for i in range(120):
        var start=Time.get_ticks_usec()
        w.advance_agents(1.0/60.0)
        agents.append((Time.get_ticks_usec()-start)/1000.0)
    agents.sort()
    var months=[]
    for i in range(6):
        var start=Time.get_ticks_usec()
        w.step()
        months.append((Time.get_ticks_usec()-start)/1000.0)
    months.sort()
    print("HARBOR_MODEL_CPU_MEDIAN_MS=",JSON.stringify(times))
    print("HARBOR_AGENT_CPU=",JSON.stringify({"median_ms":agents[60],"p95_ms":agents[114],"monthly_step_median_ms":months[3],"monthly_step_max_ms":months[-1],"population":w.stats.population}))
    quit()
