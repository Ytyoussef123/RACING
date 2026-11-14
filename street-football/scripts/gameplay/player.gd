class_name Player
extends Node3D
## A player on the court: movement (PlayerMotion) and look. Ball work is in BallHandling.

## Size of the capsule mesh in player.tscn; the mesh is scaled to the configured size.
const MESH_RADIUS := 0.35
const MESH_HEIGHT := 1.75

var motion: PlayerMotion
var radius: float
var height: float

@onready var _body: Node3D = $Body
@onready var _torso: Node3D = $Body/Torso
@onready var _ring: Node3D = $SelectionRing


func _ready() -> void:
	motion = PlayerMotion.new()
	radius = float(Config.get_value("player", "radius", MESH_RADIUS))
	height = float(Config.get_value("player", "height", MESH_HEIGHT))
	_torso.scale = Vector3(radius / MESH_RADIUS, height / MESH_HEIGHT, radius / MESH_RADIUS)
	_torso.position.y = height * 0.5


func reset_to(ground_position: Vector3, facing: Vector3) -> void:
	position = Vector3(ground_position.x, 0.0, ground_position.z)
	motion.reset(facing)
	_update_visual()


func move(delta: float, move_dir: Vector3, sprint: bool, dribbling: bool, court: CourtData) -> void:
	motion.step(delta, move_dir, sprint, dribbling)
	position += motion.velocity * delta
	_clamp_to_court(court)
	_update_visual()


func set_selected(selected: bool) -> void:
	_ring.visible = selected


func _clamp_to_court(court: CourtData) -> void:
	var max_x := court.half_length - radius
	var max_z := court.half_width - radius
	if absf(position.x) > max_x:
		position.x = signf(position.x) * max_x
		motion.velocity.x = 0.0
	if absf(position.z) > max_z:
		position.z = signf(position.z) * max_z
		motion.velocity.z = 0.0


func _update_visual() -> void:
	_body.rotation.y = atan2(motion.facing.x, motion.facing.z)
