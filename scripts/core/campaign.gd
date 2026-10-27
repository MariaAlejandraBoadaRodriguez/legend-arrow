class_name Campaign
extends RefCounted
## Ordered catalog of realms, creatures and their levels (data/campaign.json).

const LEVELS_DIR := "res://data/levels"

var realms: Array = []       # [{id, name_key}]
var creatures: Array = []    # [{id, realm, name_key, levels: [id, id]}] in unlock order
var _creature_index := {}    # creature id -> index
var _level_owner := {}       # level id -> creature id


## Result: {campaign: Campaign or null, errors: Array[String]}
static func load_file(path: String = "res://data/campaign.json") -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {"campaign": null, "errors": ["cannot parse %s" % path]}
	return from_dict(data)


static func from_dict(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var c := Campaign.new()
	if int(data.get("schema_version", 0)) != 1:
		errors.append("campaign schema_version must be 1")
	var realm_ids := {}
	for r in data.get("realms", []):
		realm_ids[str(r.get("id", ""))] = true
		c.realms.append(r)
	for cr in data.get("creatures", []):
		var id := str(cr.get("id", ""))
		if id == "" or c._creature_index.has(id):
			errors.append("creature id missing or duplicated: '%s'" % id)
			continue
		if not realm_ids.has(str(cr.get("realm", ""))):
			errors.append("creature '%s' has unknown realm" % id)
		var levels: Array = cr.get("levels", [])
		if levels.size() != 2:
			errors.append("creature '%s' needs exactly 2 levels" % id)
		for l in levels:
			if c._level_owner.has(l):
				errors.append("level '%s' listed twice" % l)
			c._level_owner[str(l)] = id
		c._creature_index[id] = c.creatures.size()
		c.creatures.append(cr)
	if c.creatures.is_empty():
		errors.append("campaign has no creatures")
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


## 0 or 1: position of the level within its creature.
func level_slot(level_id: String) -> int:
	var cid := creature_of_level(level_id)
	return -1 if cid == "" else (creature(cid).levels as Array).find(level_id)


func level_path(level_id: String) -> String:
	return LEVELS_DIR.path_join(level_id + ".json")


func creatures_in_realm(realm_id: String) -> Array:
	return creatures.filter(func(cr): return cr.realm == realm_id)
