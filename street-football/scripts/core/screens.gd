extends Node
## Autoload "Screens": moves between screens by id (paths in data/config/ui.json -> screens).
## In tests, test_mode records the requested screen instead of changing scene.

var test_mode: bool = false
var last_requested: String = ""


func go(screen_id: String) -> void:
	last_requested = screen_id
	if test_mode:
		return
	var screens: Dictionary = Config.get_value("ui", "screens", {})
	var path := str(screens.get(screen_id, ""))
	if path.is_empty():
		push_error("Screens: unknown screen '%s'" % screen_id)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
