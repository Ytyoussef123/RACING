class_name Player
extends Node3D
## A player on the court: movement (PlayerMotion), look, and links to its team,
## ball handling and AI memory. Controllers write `intent`; the match calls move() then handling.

## Size of the capsule mesh in player.tscn; the mesh is scaled to the configured size.
const MESH_RADIUS := 0.35
const MESH_HEIGHT := 1.75

var motion: PlayerMotion
var radius: float
var height: float
var team: Team
var slot_index: int = 0
var role: String = "MID"
var is_keeper: bool = false
var intent: PlayerIntent = PlayerIntent.new()
var handling: BallHandling = BallHandling.new()
var ai: AiPlayerState = AiPlayerState.new()
## Seconds left slowed down after a missed tackle or a lost shoulder duel.
var stun_timer: float = 0.0
## Physical strength 0..99, used in shoulder duels. Same for everyone until Phase 4 player stats.
var strength: float = 50.0

var _stun_move_factor: float

@onready var _body: Node3D = $Body
@onready var _torso: MeshInstance3D = $Body/Torso
@onready var _ring: Node3D = $SelectionRing


func _ready() -> void:
	motion = PlayerMotion.new()
	radius = float(Config.get_value("player", "radius", MESH_RADIUS))
	height = float(Config.get_value("player", "height", MESH_HEIGHT))
	_stun_move_factor = float(Config.get_value("player", "stun_move_factor", 0.25))
	strength = float(Config.get_value("player", "default_strength", 50.0))
	_torso.scale = Vector3(radius / MESH_RADIUS, height / MESH_HEIGHT, radius / MESH_RADIUS)
	_torso.position.y = height * 0.5
	set_selected(false)


func set_kit(kit_color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = kit_color
	mat.roughness = 0.8
	_torso.material_override = mat


func reset_to(ground_position: Vector3, facing: Vector3) -> void:
	position = Vector3(ground_position.x, 0.0, ground_position.z)
	motion.reset(facing)
	intent = PlayerIntent.new()
	stun_timer = 0.0
	handling.reset()
	ai.reset()
	_update_visual()


## Moves the player with its current intent. dribbling: this player has the ball.
func move(delta: float, court: CourtData, dribbling: bool) -> void:
	stun_timer = maxf(0.0, stun_timer - delta)
	var dir := intent.move
	var sprint := intent.sprint
	if stun_timer > 0.0:
		dir *= _stun_move_factor
		sprint = false
	motion.step(delta, dir, sprint, dribbling)
	position += motion.velocity * delta
	clamp_to_court(court)
	_update_visual()


func set_selected(selected: bool) -> void:
	_ring.visible = selected


func flat_distance_to(pos: Vector3) -> float:
	return Vector2(pos.x - position.x, pos.z - position.z).length()


func clamp_to_court(court: CourtData) -> void:
	var max_x := court.half_length - radius
	var max_z := court.half_width - radius
	if absf(position.x) > max_x:
		position.x = signf(position.x) * max_x
		motion.velocity.x = 0.0
	if absf(position.z) > max_z:
		position.z = signf(position.z) * max_z
		motion.velocity.z = 0.0
	position.y = 0.0


func _update_visual() -> void:
	_body.rotation.y = atan2(motion.facing.x, motion.facing.z)
