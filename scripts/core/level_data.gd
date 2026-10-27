class_name LevelData
extends RefCounted
## Loads level JSON and builds boards. Always validates before use.


## Result: {level: Dictionary (empty on failure), errors: Array[String]}
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"level": {}, "errors": ["file not found: %s" % path]}
	var text := FileAccess.get_file_as_string(path)
	return parse(text)


static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"level": {}, "errors": ["invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]]}
	var errors := LevelValidator.validate(json.data)
	if not errors.is_empty():
		return {"level": {}, "errors": errors}
	return {"level": json.data, "errors": errors}


## Builds a board from an already validated level dictionary.
static func to_board(level: Dictionary) -> PuzzleBoard:
	var board := PuzzleBoard.new(int(level["width"]), int(level["height"]))
	for a in level["arrows"]:
		board.add_arrow(ArrowPath.from_dict(a))
	return board


static func solution_of(level: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s in level.get("solution", []):
		out.append(str(s))
	return out
