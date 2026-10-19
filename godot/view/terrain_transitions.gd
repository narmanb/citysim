extends RefCounted
## Shared natural-biome colors; water and authored terrain paint stay distinct.
const N=52
const GRASS=Color("8ab549")
const SAND=Color("d8d19e")
const WATER=Color("9cd4e2")
const SHALLOW=Color("b0dee5")

static func natural(tile: Dictionary) -> bool:
	return tile.get("terrain","grass")!="water" and not tile.get("channel",false) and tile.get("surfaceTop","auto")=="auto" and not tile.get("road",false) and not tile.get("rail",false) and not tile.get("zone") and not tile.get("civic")

static func _corner(tiles: Array,x: int,y: int) -> Color:
	var color:=Color(0,0,0,0)
	var count:=0
	for yy in range(maxi(0,y-1),mini(N,y+1)):
		for xx in range(maxi(0,x-1),mini(N,x+1)):
			var tile: Dictionary=tiles[yy*N+xx]
			if not natural(tile):continue
			color+=SAND if tile.get("biome","grass")=="desert" else GRASS
			count+=1
	return color/float(count) if count else GRASS

static func biome_corners(tiles: Array,index: int) -> PackedColorArray:
	var tile: Dictionary=tiles[index]
	if not natural(tile):return PackedColorArray()
	var x: int=index%N
	var y: int=index/N
	var mixed:=false
	for yy in range(maxi(0,y-1),mini(N,y+2)):
		for xx in range(maxi(0,x-1),mini(N,x+2)):
			var other: Dictionary=tiles[yy*N+xx]
			if natural(other) and other.get("biome","grass")!=tile.get("biome","grass"):mixed=true
	if not mixed:return PackedColorArray()
	return PackedColorArray([_corner(tiles,x,y),_corner(tiles,x+1,y),_corner(tiles,x+1,y+1),_corner(tiles,x,y+1)])

static func interpolate(colors: PackedColorArray,u: float,v: float,fallback: Color) -> Color:
	if colors.is_empty():return fallback
	return colors[0].lerp(colors[1],u).lerp(colors[3].lerp(colors[2],u),v)

static func water_corners(tiles: Array,index: int) -> PackedColorArray:
	var x: int=index%N
	var y: int=index/N
	var colors:=PackedColorArray()
	for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
		var shore:=false
		for yy in range(maxi(0,y+offset.y-1),mini(N,y+offset.y+1)):
			for xx in range(maxi(0,x+offset.x-1),mini(N,x+offset.x+1)):
				if tiles[yy*N+xx].get("terrain","grass")!="water":shore=true
		colors.append(SHALLOW if shore else WATER)
	return colors
