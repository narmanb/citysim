extends RefCounted
## Clean terrain colors share the original cliff palette. No geometry mutation.
const ROCK_TOP = Color("b59b6b")
const WALL_EAST = Color("8b7954")
const WALL_SOUTH = Color("a18b62")

static func cap_color(base: Color, gradient: Vector2, edge_rock: float = 0.) -> Color:
 var normal := Vector3(-gradient.x*.35,-gradient.y*.35,1).normalized()
 var weights := Vector3(absf(normal.x),absf(normal.y),normal.z)
 weights/=weights.x+weights.y+weights.z
 var east: Color = WALL_EAST if normal.x>=0 else ROCK_TOP*1.03
 var south: Color = WALL_SOUTH if normal.y>=0 else ROCK_TOP*.97
 var rock: Color = ROCK_TOP*weights.z+east*weights.x+south*weights.y
 var shade: float = weights.z+weights.x*(.77 if normal.x>=0 else 1.03)+weights.y*(.89 if normal.y>=0 else .97)
 var exposure: float = maxf(edge_rock,smoothstep(.35,.60,gradient.length()*.15))
 var color: Color = (base*shade).lerp(rock,clampf(exposure,0,1))
 color.a=1.
 return color
