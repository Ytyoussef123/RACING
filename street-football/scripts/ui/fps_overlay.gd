extends CanvasLayer
## Small frame-rate counter in the top-right corner, above every screen (Settings -> Show FPS).

const REFRESH_SECONDS := 0.5

var _timer := 0.0

@onready var _label: Label = $Label


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_SECONDS
		_label.text = tr("FPS_LABEL") % int(Engine.get_frames_per_second())
