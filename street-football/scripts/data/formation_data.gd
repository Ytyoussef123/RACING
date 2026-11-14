class_name FormationData
extends RefCounted
## One formation, loaded from res://data/formations/<id>.json: 5 slots, slot 0 is the goalkeeper.
## Slot x: 0 = own goal line, 1 = opponent goal line. Slot z: -1..1 across the court.

const FORMATIONS_DIR := "res://data/formations/"

var id: String = ""
var slots: Array = []


static func load_formation(formation_id: String) -> FormationData:
	var formation := FormationData.new()
	formation.id = formation_id
	var path := FORMATIONS_DIR + formation_id + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("FormationData: cannot read %s" % path)
		return formation
	var data: Dictionary = parsed
	formation.slots = data.get("slots", [])
	return formation


## All formation ids in menu order (data/config/match.json).
static func all_ids() -> Array:
	return Config.get_value("match", "formations", ["2-1-1"])


static func next_id(current: String) -> String:
	var ids := all_ids()
	var index := ids.find(current)
	return str(ids[(index + 1) % ids.size()])


func slot(index: int) -> Dictionary:
	if index >= 0 and index < slots.size():
		return slots[index]
	return {}


func role(index: int) -> String:
	return str(slot(index).get("role", "MID"))
