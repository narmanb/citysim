# Deterministic desktop CPU probe: two warmups, eleven samples per workload.
# Run headlessly; compare state hashes and medians between source revisions.
extends SceneTree
const Model = preload("res://model/city_world.gd")
func _initialize(): call_deferred("run")
func make_world(kind):
    var w = Model.new(4242)
    if kind == "fresh_seed4242": return w
    for i in range(w.COUNT): w.tiles[i] = w.blank_tile()
    if kind == "empty_seed4242":
        w.recalculate()
        return w
    w.tiles[19*52+3].terrain = "water"
    w.tiles[19*52+3].waterSource = true
    w.place(19*52+4,"plant")
    w.place(20*52+3,"pump")
    for x in range(4,35):
        w.place(20*52+x,"line")
        w.place(20*52+x,"pipe")
        w.place(22*52+x,"road")
    var sections = [[4,7,"apt",200],[8,9,"shop",201],[10,13,"light",202],[14,17,"apt",203],[18,19,"office",204],[20,22,"logistics",205],[23,26,"apt",206],[27,30,"heavy",207],[31,34,"apt",208]]
    for section in sections:
        for x in range(section[0],section[1]+1): w.place(21*52+x,section[2],false,section[3])
    for service in [[20,"hospital"],[18,"school"],[16,"police"],[14,"fire"]]: w.place(19*52+service[0],service[1])
    w.recalculate()
    for step in range(12): w.step()
    return w
func digest(w):
    return JSON.stringify({"save":w.serialize(),"fields":w.fields,"demand":w.demand,"network":w.network}).sha256_text()
func run():
    for kind in ["fresh_seed4242", "empty_seed4242", "populated_seed4242_month12"]:
        var w = make_world(kind)
        print("MODEL_SNAPSHOT=", kind, " SHA256=", digest(w))
        var timings = {}
        for method in ["_utility_update", "_environment_update", "recalculate"]:
            for warmup in range(2): w.call(method)
            var values = []
            for repeat in range(11):
                var start = Time.get_ticks_usec()
                w.call(method)
                values.append((Time.get_ticks_usec()-start)/1000.0)
            values.sort()
            timings[method] = {"median_ms":values[5], "min_ms":values[0], "max_ms":values[-1]}
        print("MODEL_DESKTOP_CPU=", kind, " ", JSON.stringify(timings))
        print("MODEL_POST_SNAPSHOT=", kind, " SHA256=", digest(w))
    quit()
