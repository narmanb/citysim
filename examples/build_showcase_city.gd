extends SceneTree
## Builds a complete showcase save using the current native simulation.
## From repo root: godot --headless --path godot --script <absolute path to this file> -- <output folder>
const World = preload("res://model/city_world.gd")
const Store = preload("res://persistence/city_store.gd")
var city
var parcels: Array = []
var districts: Dictionary = {}
var checks: Array = []
var output: String
var failed = false

func _initialize(): call_deferred("run")
func index(x: int, y: int) -> int: return y * 52 + x
func tile(x: int, y: int) -> Dictionary: return city.tiles[index(x, y)]
func river_start(x: int) -> int: return 34 if x >= 32 else 33
func require(condition: bool, message: String) -> bool:
    if not condition:
        push_error(message)
        failed = true
    checks.append(message)
    return condition
func put_road(x: int, y: int):
    var t = tile(x, y)
    require(not t.zone and not t.civic, "Road footprint is clear")
    t.road = true
    t.tree = false
func put_rail(x: int, y: int):
    tile(x, y).rail = true
    tile(x, y).tree = false
func utility(x: int, y: int):
    var t = tile(x, y)
    t.pipe = true
    if t.terrain != "water" and not t.civic and not t.zone:
        t.line = true
        t.tree = false
func park(x: int, y: int):
    var t = tile(x, y)
    if t.terrain == "water" or t.zone or t.civic or t.road or t.rail or t.line: return
    t.civic = "park"
    t.tree = false
func tree(x: int, y: int):
    var t = tile(x, y)
    if t.terrain == "grass" and not (t.zone or t.civic or t.road or t.rail or t.line): t.tree = true
func lot(x: int, y: int, width: int, depth: int, tool: String, level: int, district: String):
    var members: Array = []
    var elevation = tile(x,y).elev
    for yy in range(y, y + depth):
        for xx in range(x, x + width):
            var t = tile(xx, yy)
            if not require(t.terrain != "water" and not (t.road or t.rail or t.civic or t.zone or t.line), "Parcel footprint is clear at %d,%d" % [xx,yy]): return
            require(t.elev == elevation, "Showcase building foundations are flat")
            var meta = World.ZONE_TOOL[tool]
            t.zone = meta.zone
            t.zoneType = meta.type
            t.resType = meta.type if meta.zone == "res" else null
            t.parcel = city.nextParcelId
            t.level = level
            t.tree = false
            members.append(index(xx, yy))
    city.nextParcelId += 1
    parcels.append({"root": members[0], "members":members,"district":district,"tool":tool})
    districts[district] = districts.get(district, 0) + 1
func civic(x: int, y: int, kind: String):
    var t = tile(x, y)
    require(not t.zone and not t.civic and t.terrain != "water", "Civic footprint is clear")
    require(kind == "station" or not (t.road or t.rail), "Civic layers are legal")
    require(kind != "station" or t.rail, "Stations sit on rail")
    t.civic = kind
    t.tree = false
    t.line = false
    t.pipe = true
    if kind == "tower": t.storage = 180
    # Connect to the nearest service alley without crossing buildings or water.
    var queue: Array = [index(x, y)]
    var previous: Dictionary = {index(x,y):-1}
    var found = -1
    var head = 0
    while head < queue.size():
        var at = queue[head]
        head += 1
        if city.tiles[at].line:
            found = at
            break
        for n in city.neighbors(at):
            var q = city.tiles[n]
            if previous.has(n) or q.terrain == "water" or q.zone or q.civic: continue
            previous[n] = at
            queue.append(n)
    if not require(found >= 0, "Civic utility connection exists"): return
    while found != index(x,y):
        utility(found % 52, int(found / 52))
        found = previous[found]
func campus(bx: int, by: int):
    var slots = [[1,1,"police"],[4,1,"fire"],[1,4,"school"],[4,4,"hospital"]]
    for s in slots: civic(bx+s[0],by+s[1],s[2])
    for yy in range(by+1,by+6):
        for xx in range(bx+1,bx+6):
            if (xx+yy)%2 == 0: park(xx,yy)
func service_strip():
    # Compact municipal clusters cover each neighborhood rather than one remote depot.
    for origin in [[10,6],[16,18],[34,6],[40,18],[10,24]]:
        campus(origin[0],origin[1])
func block(bi: int, bj: int):
    var bx=10+bi*6
    var by=6+bj*6
    if [bi,bj] in [[0,0],[1,2],[4,0],[5,2],[0,3]]: return # Civic campuses.
    if bi==2 and bj==1: return # Central Park.
    if bi==5 and bj==0: return # Terrace lake and woodland.
    var corners=[[1,1],[4,1],[1,4],[4,4]]
    if bi==0 or (bi>=4 and bj==1):
        # Individual homes and gardens on the low-rise edges.
        for s in corners:
            var yy = by + (1 if s[1]==1 else 5)
            lot(bx+s[0],yy,1,1,"res",1+(bi+bj+s[0])%3,"Garden neighborhoods")
            lot(bx+s[0]+1,yy,1,1,"res",1+(bj+s[1])%3,"Garden neighborhoods")
            tree(bx+s[0],by+(2 if s[1]==1 else 4))
        return
    for c in range(4):
        var x = bx + (1 if c%2==0 else 4)
        var y = by + (1 if c<2 else 4)
        # The right-hand lots occupy offsets 4 and 5; both touch a boundary road.
        if bi==1:
            lot(x,y,2,2,"shop" if c==3 else "apt",2 if bj==0 else 3,"Midtown")
        elif bi in [2,3]:
            if bj==0:
                lot(x,y,2,2,"apt" if c<3 else "shop",2+(c%2),"North Quarter")
            elif bj==1:
                lot(x,y,2,2,"apt" if c%2==0 else "office",3,"Parkside")
            else:
                lot(x,y,2,2,"office" if (bi==2 or c%2==1) else "apt",4,"Downtown")
        elif bj==3:
            lot(x,y,2,2,"office" if bi==5 else "shop",3,"Eastbank Quays")
        else:
            lot(x,y,2,2,"apt" if c<2 else "shop",2+(c%2),"Hillcrest")
func build_landscape():
    for y in range(52):
        for x in range(52):
            var water = x<7 or y in range(river_start(x),river_start(x)+3)
            var t = World.blank_tile("water" if water else "grass")
            # A flat, raised northeast terrace with a stepped forested edge.
            if not water and x>=40 and y>=5 and y<=17: t.elev = 2
            if not water and x>=46 and y<=3: t.elev = 3
            if not water and x>=49 and y>=6 and y<=18: t.elev = 3
            if not water and (y>=49 or (x>=49 and y<24)) and World._hash(x,y,city.seed)>0.28: t.tree = true
            city.tiles[index(x,y)] = t
    # An elevated ornamental lake in Hillcrest; the entire rim stays level.
    for y in range(8,11):
        for x in range(42,46):
            var t=tile(x,y)
            t.terrain="water"
            t.waterSource=true
            t.elev=2
    # Waterfront beaches and irregular woodland at the map edges.
    for y in range(3,49):
        if tile(7,y).terrain=="grass": tile(7,y).biome="desert"
    for y in range(0,4):
        for x in range(9,48):
            if (x+y)%3!=0: tree(x,y)
func build_networks():
    for y in [6,12,18,24,30]:
        for x in range(10,47): put_road(x,y)
    for x in [10,16,22,28,34,40,46]:
        for y in range(6,31): put_road(x,y)
    for y in [38,44,48]:
        for x in range(10,47): put_road(x,y)
    for x in [10,16,22,28,34,40,46]:
        for y in range(38,49): put_road(x,y)
    for x in [16,28,40]:
        for y in range(30,39): put_road(x,y)
    # Six stops on a continuous ring; both river crossings are three tiles long.
    for x in range(9,49):
        put_rail(x,4)
        put_rail(x,47)
    for y in range(4,48):
        put_rail(9,y)
        put_rail(48,y)
    for x in [16,28,40]:
        for y in range(4,7): put_road(x,y)
    for y in [12,24,30]: put_road(9,y)
    for y in [18,41]:
        for x in range(46,49): put_road(x,y)
    # Service alleys pass between buildings, preserving clear main roads.
    for y in [9,15,21,27]:
        for x in range(8,51):
            if y==15 and x in range(23,28): continue
            utility(x,y)
    for x in [13,19,25,31,37,43]:
        for y in range(6,31):
            if x==25 and y in range(13,18): continue
            utility(x,y)
    for y in [41,46]:
        for x in range(10,47): utility(x,y)
    for x in [13,19,25,31,37,43]:
        for y in range(38,49): utility(x,y)
    # Water can run beneath the river. Electricity has generators on both banks.
    for y in range(27,47):
        tile(28,y).pipe=true
        if tile(28,y).terrain!="water": utility(28,y)
    for y in range(5,33): utility(8,y)
func build_places():
    service_strip()
    for bj in range(4):
        for bi in range(6): block(bi,bj)
    # A municipal cluster on the Central Park square also covers Parkside.
    for p in [[23,13,"school"],[27,13,"hospital"],[23,17,"police"],[27,17,"fire"]]: civic(p[0],p[1],p[2])
    for y in range(13,18):
        for x in range(23,28):
            if not tile(x,y).civic:
                if x in [24,25,26] and y in [14,15,16] and not (x==24 and y==14 or x==26 and y==16):
                    tile(x,y).terrain="water"
                    tile(x,y).waterSource=true
                elif (x+y)%2==0: park(x,y)
                else: tree(x,y)
    # Southbank: a small residential quarter near the coast and a manufacturing district east.
    for bx in [10,16,22]:
        for c in range(4):
            var x=bx+(1 if c%2==0 else 4)
            var y=39 if c<2 else 42
            lot(x,y,2,2,"apt" if bx==22 and c<2 else "shop" if c==3 else "res",2,"Southbank")
    for bx in [28,34,40]:
        for c in range(4):
            lot(bx+(1 if c%2==0 else 4),39 if c<2 else 42,2,2,"heavy" if bx==40 else "light",3,"Industry and manufacturing")
    for p in [[11,45,"fire"],[15,45,"police"],[17,45,"hospital"],[21,45,"school"]]: civic(p[0],p[1],p[2])
    for p in [[49,26],[49,28],[49,30],[41,45],[45,45]]: civic(p[0],p[1],"plant")
    for p in [[7,9],[7,15],[7,21],[7,27],[25,32]]: civic(p[0],p[1],"pump")
    for p in [[14,5],[31,11],[43,23],[24,45]]: civic(p[0],p[1],"tower")
    for p in [[9,12],[28,4],[48,18],[9,30],[48,41],[40,47]]: civic(p[0],p[1],"station")
    for y in [31,32]:
        for x in range(10,47):
            if (x+y)%3==0: park(x,y)
            elif (x+y)%3==1: tree(x,y)
    for x in range(10,47):
        if x%2==0: tree(x,37)
    for y in range(7,18):
        for x in range(41,47):
            if not tile(x,y).zone and (x+y)%3==0: park(x,y)
    for x in range(10,47):
        if x%3==0: tree(x,49)
    # The forested edge forms a green buffer around the energy campus.
    for y in range(24,33):
        for x in range(47,52):
            if (x+y)%2==0: tree(x,y)
func verify(c, label: String):
    require(c.tiles.size()==2704,label+": full map")
    require(c.stats.population>=2500,label+": substantial population")
    require(c.stats.unpowered==0 and c.stats.unwatered==0,label+": all developed buildings have utilities")
    require(c.stats.net>0,label+": positive monthly budget")
    require(c.stats.unemployment<=15,label+": employment available")
    require(c.network.stations.size()==6 and c.network.railRoutes.size()>=6,label+": connected railway")
    for p in c._parcels.values(): require(c.road_near(p.root),label+": every parcel has road access")
    for t in c.tiles:
        require(not t.fire and not t.abandoned,label+": undamaged city")
        require(not (t.tree and (t.zone or t.line or t.road or t.rail or t.civic)),label+": clear construction footprints")
    print(label+" ",JSON.stringify({"population":c.stats.population,"jobs":c.stats.jobs,"net":c.stats.net,"unemployment":c.stats.unemployment,"power":[c.stats.powerUsed,c.stats.powerGenerated],"water":[c.stats.waterUsed,c.stats.waterCapacity],"developed":c.stats.developed,"stations":c.network.stations.size(),"rail_routes":c.network.railRoutes.size(),"cars":c.cars.size(),"trains":c.trains.size()}))
func run():
    output=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/tmp/metroforge-showcase"
    DirAccess.make_dir_recursive_absolute(output)
    city=World.new(803621)
    city.cash=425000
    city.year=2012
    city.month=6
    city.tick=149
    city.randomDisasters=false
    city.funding={"road":115,"police":110,"fire":120,"school":110,"hospital":110}
    build_landscape()
    build_networks()
    build_places()
    if failed:
        quit(1)
        return
    city.recalculate()
    # Settle derived quality/occupancy, then populate actual moving road/rail agents.
    for repeat in range(3): city.recalculate()
    for repeat in range(90): city.advance_agents(0.6)
    city.recalculate()
    city.stats.yearToDate=city.stats.net*5
    city.messages.clear()
    city.notify("Harbor City: explore Downtown, Central Park, Hillcrest and the Southbank freight district.","good")
    city.notify("Six rail stops connect both riverbanks. Waterfront promenades and raised residential terraces frame the city.")
    city.events.clear()
    city.milestones=[500,1000,2500]
    verify(city,"SHOWCASE")
    if failed:
        quit(1)
        return
    var text=Store.export_json(city)
    var saved=Store.import_json(text)
    if not require(saved!=null,"Native export reimports: "+Store.last_error):
        quit(1)
        return
    verify(saved,"REIMPORTED")
    require(saved.stats.population==city.stats.population and saved.cash==city.cash,"Import preserves occupancy and treasury")
    var file=FileAccess.open(output+"/MetroForge-Harbor-City.json",FileAccess.WRITE)
    if not require(file!=null,"Output can be written"):
        quit(1)
        return
    file.store_string(text)
    file.close()
    for month in range(24):
        saved.step()
        for repeat in range(3): saved.advance_agents(0.6)
    verify(saved,"AFTER_24_MONTHS")
    require(saved.cash>city.cash,"Treasury grows while simulation runs")
    var report={"seed":city.seed,"map_size":[52,52],"district_parcels":districts,"initial_stats":city.stats,"after_24_months_stats":saved.stats,"initial_cash":city.cash,"after_24_months_cash":saved.cash,"initial_agents":{"cars":city.cars.size(),"trains":city.trains.size()},"validation_checks":checks.size(),"city_sha256":text.sha256_text()}
    file=FileAccess.open(output+"/validation.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    file.close()
    if failed:
        quit(1)
        return
    print("SHOWCASE SAVE VERIFIED: "+output+"/MetroForge-Harbor-City.json")
    quit()
