extends RefCounted
## Clean terrain colors share the original cliff palette. No geometry mutation.
const ROCK_TOP = Color("b59b6b")
const WALL_EAST = Color("8b7954")
const WALL_SOUTH = Color("a18b62")

static func cap_color(base: Color, gradient: Vector2, edge_rock: float = 0., rock_kind: String = "brown") -> Color:
 var normal := Vector3(-gradient.x*.35,-gradient.y*.35,1).normalized()
 var weights := Vector3(absf(normal.x),absf(normal.y),normal.z)
 weights/=weights.x+weights.y+weights.z
 var top: Color = rock_color(rock_kind)
 var east: Color = wall_color({"surfaceRock":rock_kind},0) if normal.x>=0 else top*1.03
 var south: Color = wall_color({"surfaceRock":rock_kind},1) if normal.y>=0 else top*.97
 var rock: Color = top*weights.z+east*weights.x+south*weights.y
 var shade: float = weights.z+weights.x*(.77 if normal.x>=0 else 1.03)+weights.y*(.89 if normal.y>=0 else .97)
 var exposure: float = maxf(edge_rock,smoothstep(.35,.60,gradient.length()*.15))
 var color: Color = (base*shade).lerp(rock,clampf(exposure,0,1))
 color.a=1.
 return color

static func rock_color(kind: String) -> Color:
 return {"brown":ROCK_TOP,"gray":Color("9c9da0"),"sand":Color("d8d19e"),"grass":Color("8ab549")}.get(kind,ROCK_TOP)

static func top_color(tile: Dictionary, fallback: Color) -> Color:
 return {"grass":Color("8ab549"),"sand":Color("d8d19e"),"rock":ROCK_TOP,"snow":Color("eff5f6")}.get(tile.get("surfaceTop","auto"),fallback)

static func wall_color(tile: Dictionary, side: int) -> Color:
 var kind: String = tile.get("surfaceRock","brown")
 if kind=="brown":return WALL_EAST if side==0 else WALL_SOUTH
 var color: Color = rock_color(kind)*(.77 if side==0 else .89)
 color.a=1
 return color

static func cover_weight(kind: String, height: float, base: float, peak: float) -> float:
 if kind=="auto":return 1.
 var span: float = maxf(.1,peak-base)
 return smoothstep(base+span*(.55 if kind=="snow" else .10),base+span*(.80 if kind=="snow" else .35),height)
