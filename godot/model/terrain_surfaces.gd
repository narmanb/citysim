extends RefCounted
const TOPS = ["auto","grass","sand","rock","snow"]
const ROCKS = ["brown","gray","sand","grass"]

static func valid_settings(settings: Dictionary) -> bool:
 return (not settings.has("surface_top") or settings.surface_top in TOPS) and (not settings.has("surface_rock") or settings.surface_rock in ROCKS)

static func valid_tile(tile: Dictionary) -> bool:
 return (not tile.has("surfaceTop") or tile.surfaceTop in TOPS) and (not tile.has("surfaceRock") or tile.surfaceRock in ROCKS)

static func apply(tile: Dictionary, settings: Dictionary) -> void:
 for pair in [["surface_top","surfaceTop","auto"],["surface_rock","surfaceRock","brown"]]:
  if not settings.has(pair[0]):continue
  if settings[pair[0]]==pair[2]:tile.erase(pair[1])
  else:tile[pair[1]]=settings[pair[0]]

static func changed(a: Dictionary,b: Dictionary) -> bool:
 return a.get("surfaceTop","auto")!=b.get("surfaceTop","auto") or a.get("surfaceRock","brown")!=b.get("surfaceRock","brown")
