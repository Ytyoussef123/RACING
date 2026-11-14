class_name Player
extends Node3D
## A player on the court: movement (PlayerMotion), look, identity (PlayerProfile + stat sheet),
## stamina, and links to its team, ball handling and AI memory.
## Controllers write `intent`; the match calls move() then handling.

## Size of the body in player.tscn (capsule radius, total height with the head);
## the body is scaled to the configured or real height.
const MESH_RADIUS := 0.35
const MESH_HEIGHT := 1.75
## Hair shapes by style (scale of the hair cap; ZERO hides it). Visual only.
const HAIR_STYLES := {
	"bald": Vector3.ZERO,
	"buzz": Vector3(1.0, 0.75, 1.0),
	"short": Vector3(1.03, 1.0, 1.03),
	"afro": Vector3(1.45, 1.35, 1.45),
	"long": Vector3(1.08, 1.15, 1.08),
	"mohawk": Vector3(0.45, 1.5, 1.1),
}

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
## Identity and attributes; null for anonymous test players.
var profile: PlayerProfile = null
var number: int = 0
var display_name: String = ""
## Physical attributes used in shoulder duels (0..99).
var strength: float = 50.0
var balance: float = 50.0
## "right" or "left", and weak foot accuracy 1..4.
var preferred_foot: String = "right"
var weak_foot: int = 4
## Gameplay numbers from the attributes for the current role (StatEffects); empty = neutral.
var sheet: Dictionary = {}
## Stamina left, 0..1: sprinting uses it, the rest of the time it comes back.
var energy: float = 1.0

var _stun_move_factor: float

@onready var _body: Node3D = $Body
@onready var _torso: MeshInstance3D = $Body/Torso
@onready var _head: MeshInstance3D = $Body/Head
@onready var _hair: MeshInstance3D = $Body/Hair
@onready var _ring: Node3D = $SelectionRing


func _ready() -> void:
	motion = PlayerMotion.new()
	radius = float(Config.get_value("player", "radius", MESH_RADIUS))
	height = float(Config.get_value("player", "height", MESH_HEIGHT))
	_stun_move_factor = float(Config.get_value("player", "stun_move_factor", 0.25))
	strength = float(Config.get_value("player", "default_strength", 50.0))
	balance = strength
	_scale_body()
	set_selected(false)


## Gives this player an identity and the stats for his role.
func apply_profile(new_profile: PlayerProfile, new_role: String, shirt_number: int) -> void:
	profile = new_profile
	number = shirt_number
	display_name = profile.short_name
	strength = profile.attr("strength")
	balance = profile.attr("balance")
	preferred_foot = profile.preferred_foot
	weak_foot = profile.weak_foot
	height = profile.height_cm / 100.0
	_scale_body()
	_apply_look()
	set_role(new_role)


## Changes the role (formation slot) and recomputes the stat sheet for it.
func set_role(new_role: String) -> void:
	role = new_role
	if profile != null:
		sheet = StatEffects.build_sheet(profile, role)
		motion.apply_sheet(sheet)


## A gameplay number from the stat sheet, or `fallback` for players without a profile.
func stat(effect: String, fallback: float) -> float:
	return float(sheet.get(effect, fallback))


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
	_update_energy(delta, sprint and dir.length() > 0.2)
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


## Sprinting drains stamina (less for high stamina), otherwise it comes back.
## Below low_energy_threshold the top speed drops, down to low_energy_speed_mult when empty.
func _update_energy(delta: float, sprinting: bool) -> void:
	var moving := Vector2(motion.velocity.x, motion.velocity.z).length() > StatEffects.num("sprint_drain_min_speed", 1.0)
	if sprinting and moving:
		energy = maxf(0.0, energy - stat("stamina_drain", 0.06) * delta)
	else:
		energy = minf(1.0, energy + StatEffects.num("energy_recover_per_second", 0.04) * delta)
	var threshold := maxf(0.01, StatEffects.num("low_energy_threshold", 0.4))
	motion.energy_mult = lerpf(StatEffects.num("low_energy_speed_mult", 0.85), 1.0, clampf(energy / threshold, 0.0, 1.0))


func _scale_body() -> void:
	_body.scale = Vector3(radius / MESH_RADIUS, height / MESH_HEIGHT, radius / MESH_RADIUS)


func _apply_look() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = profile.look_color("skin", Color(0.78, 0.54, 0.37))
	skin.roughness = 0.7
	_head.material_override = skin
	var hair := StandardMaterial3D.new()
	hair.albedo_color = profile.look_color("hair", Color(0.1, 0.08, 0.06))
	hair.roughness = 0.9
	_hair.material_override = hair
	var shape: Vector3 = HAIR_STYLES.get(str(profile.look.get("hair_style", "short")), Vector3.ONE)
	_hair.visible = shape != Vector3.ZERO
	if _hair.visible:
		_hair.scale = shape


func _update_visual() -> void:
	_body.rotation.y = atan2(motion.facing.x, motion.facing.z)
