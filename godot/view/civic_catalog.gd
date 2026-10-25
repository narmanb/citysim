extends RefCounted
## Appearance-only identities: no simulation RNG, new roles or save fields.
const ROLES=["police","fire","school","hospital","plant","pump","tower","station"]
static func sprite_for(kind:String,_seed:int,_index:int)->String:
 return "civic_"+kind if kind in ROLES else ""
