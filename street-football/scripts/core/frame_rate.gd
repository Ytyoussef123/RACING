extends Node
## Autoload "FrameRate": applies the frame-rate settings from data/config/performance.json.
## Phase 8 will add the automatic fallback to fallback_fps on slow phones here.


func _ready() -> void:
	Engine.max_fps = int(Config.get_value("performance", "target_fps", 60))
	Engine.physics_ticks_per_second = int(Config.get_value("performance", "physics_ticks_per_second", 60))
