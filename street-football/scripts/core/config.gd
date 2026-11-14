extends Node
## Autoload "Config": the single source of every gameplay / tuning number.
##
## Loads each JSON file in res://data/config/ into a section named after the file
## (performance.json -> "performance"). Read values with:
##     Config.get_value("performance", "target_fps", 60)
## The default is only a safety net; the real value must live in the JSON file.

const CONFIG_DIR := "res://data/config/"

var _sections: Dictionary = {}


func _ready() -> void:
	_load_all()


func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	var data: Dictionary = _sections.get(section, {})
	if not data.has(key):
		push_warning("Config: missing '%s.%s', using default." % [section, key])
		return default_value
	return data[key]


func get_section(section: String) -> Dictionary:
	return _sections.get(section, {})


func _load_all() -> void:
	var dir := DirAccess.open(CONFIG_DIR)
	if dir == null:
		push_error("Config: cannot open %s" % CONFIG_DIR)
		return
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			_load_file(file_name)


func _load_file(file_name: String) -> void:
	var path := CONFIG_DIR + file_name
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config: %s is not a valid JSON object." % path)
		return
	_sections[file_name.get_basename()] = parsed
