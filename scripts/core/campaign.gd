class_name Campaign
extends RefCounted
## Ordered catalog of worlds, dragons and their levels (data/campaign.json,
## schema 2, built by tools/build_campaign.py from docs/ART_PROMPTS.md).
## v0.2: 10 worlds x 10 dragons, one level per dragon whose id is the dragon
## id; world order and dragon order are difficulty order (D-41, D-47).

const LEVELS_DIR := "res://data/levels"
const SCHEMA := 2

var worlds: Array = []       # [{id, number, name_key, tone}] in order
var creatures: Array = []    # [{id, world, name_key, levels: [id]}] in unlock order
var _creature_index := {}    # dragon id -> index
var _level_owner := {}       # level id -> dragon id
var _world_index := {}       # world id -> index


## Result: {campaign: Campaign or null, errors: Array[String]}
static func load_file(path: String = "res://data/campaign.json") -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {"campaign": null, "errors": ["cannot parse %s" % path]}
	return from_dict(data)


static func from_dict(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var c := Campaign.new()
	if int(data.get("schema_version", 0)) != SCHEMA:
		errors.append("campaign schema_version must be %d" % SCHEMA)
	for w in data.get("worlds", []):
		var wid := str(w.get("id", ""))
		if wid == "" or c._world_index.has(wid):
			errors.append("world id missing or duplicated: '%s'" % wid)
			continue
		c._world_index[wid] = c.worlds.size()
		c.worlds.append(w)
	for cr in data.get("dragons", []):
		var id := str(cr.get("id", ""))
		if id == "" or c._creature_index.has(id):
			errors.append("dragon id missing or duplicated: '%s'" % id)
			continue
		if not c._world_index.has(str(cr.get("world", ""))):
			errors.append("dragon '%s' has unknown world" % id)
		var levels: Array = cr.get("levels", [])
		if levels.is_empty():
			errors.append("dragon '%s' has no level" % id)
		for l in levels:
			if c._level_owner.has(l):
				errors.append("level '%s' listed twice" % l)
			c._level_owner[str(l)] = id
		c._creature_index[id] = c.creatures.size()
		c.creatures.append(cr)
	if c.creatures.is_empty():
		errors.append("campaign has no dragons")
	return {"campaign": c if errors.is_empty() else null, "errors": errors}


func level_ids() -> Array[String]:
	var out: Array[String] = []
	for cr in creatures:
		for l in cr.levels:
			out.append(str(l))
	return out


func creature(id: String) -> Dictionary:
	return creatures[_creature_index[id]] if _creature_index.has(id) else {}


func creature_ids() -> Array[String]:
	var out: Array[String] = []
	for cr in creatures:
		out.append(str(cr.id))
	return out


func creature_of_level(level_id: String) -> String:
	return _level_owner.get(level_id, "")


func creature_index(id: String) -> int:
	return _creature_index.get(id, -1)


## Position of the level within its dragon (always 0 in v0.2).
func level_slot(level_id: String) -> int:
	var cid := creature_of_level(level_id)
	return -1 if cid == "" else (creature(cid).levels as Array).find(level_id)


func level_path(level_id: String) -> String:
	return LEVELS_DIR.path_join(level_id + ".json")


# --- worlds -----------------------------------------------------------------

func world(id: String) -> Dictionary:
	return worlds[_world_index[id]] if _world_index.has(id) else {}


func world_index(id: String) -> int:
	return _world_index.get(id, -1)


func world_ids() -> Array[String]:
	var out: Array[String] = []
	for w in worlds:
		out.append(str(w.id))
	return out


func world_of(cid: String) -> String:
	return str(creature(cid).get("world", ""))


func creatures_in_world(world_id: String) -> Array:
	return creatures.filter(func(cr): return cr.world == world_id)


func levels_in_world(world_id: String) -> Array[String]:
	var out: Array[String] = []
	for cr in creatures_in_world(world_id):
		for l in cr.levels:
			out.append(str(l))
	return out


## Index of the dragon inside its world (0..9).
func index_in_world(cid: String) -> int:
	return creatures_in_world(world_of(cid)).map(func(cr): return cr.id).find(cid)
