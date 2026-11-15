class_name Player
extends Node3D
## A player on the court: movement (PlayerMotion), look, identity (PlayerProfile + stat sheet),
## stamina, and links to its team, ball handling and AI memory.
## Controllers write `intent`; the match calls move() then handling.

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
## Seconds left slowed down after a missed tackle or a lost shoulder duel (or fooled by a skill).
var stun_timer: float = 0.0
## Seconds left during which the ball passes through this player (nutmegged).
var ghost_timer: float = 0.0
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
## Keeper only: the ball is in his hands (KeeperHands), and for how long (seconds).
var ball_in_hands: bool = false
var hands_time: float = 0.0

var _stun_move_factor: float
## Jointed body (look only): joints and meshes built under Body/Pose.
var _rig: PlayerRig
var _animator: PlayerAnimator

@onready var _body: Node3D = $Body
@onready var _ring: Node3D = $SelectionRing


func _ready() -> void:
	motion = PlayerMotion.new()
	radius = float(Config.get_value("player", "radius", 0.35))
	height = float(Config.get_value("player", "height", 1.75))
	_stun_move_factor = float(Config.get_value("player", "stun_move_factor", 0.25))
	strength = float(Config.get_value("player", "default_strength", 50.0))
	balance = strength
	_rig = PlayerRig.new()
	_rig.build($Body/Pose)
	_animator = PlayerAnimator.new(_rig)
	_scale_body()
	set_selected(false)


func _process(delta: float) -> void:
	update_look(delta)


## Builds the body meshes if needed and animates the body for `delta` seconds (look only).
## Called every frame; tests that step the match by hand call it themselves.
func update_look(delta: float) -> void:
	_rig.refresh()
	_animator.keeper = is_keeper
	_animator.holding = ball_in_hands
	_animator.update(delta, motion.velocity, motion.facing, motion.turn_rate, motion.top_speed(true))


## Plays a short animation: "kick", "tackle", "shoulder", "dive", "skill", "celebrate".
## side: +1 right / -1 left (dive and shoulder direction); kicks use the preferred foot.
## reach: for a kick, how far the ball is (the body lunges toward a far ball).
func animate(action: String, side: float = 1.0, reach: float = 0.0) -> void:
	if action == "kick":
		side = -1.0 if preferred_foot == "left" else 1.0
	_animator.play(action, side, reach)


## Dribble touch with the right (+1) or left (-1) foot: the foot reaches the ball in `lead` seconds.
func animate_touch(side: float, lead: float) -> void:
	_animator.play_touch(side, lead)


## Keeper dive toward a point: rolls to the side where it is.
func animate_dive(toward: Vector3) -> void:
	var right_dir := Vector3(-motion.facing.z, 0.0, motion.facing.x)
	animate("dive", 1.0 if (toward - position).dot(right_dir) >= 0.0 else -1.0)


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


## Dresses the player: shirt in the kit color, darker shorts, socks; keepers wear gloves.
func set_kit(kit_color: Color) -> void:
	_rig.set_kit(kit_color, is_keeper)


func reset_to(ground_position: Vector3, facing: Vector3) -> void:
	position = Vector3(ground_position.x, 0.0, ground_position.z)
	motion.reset(facing)
	intent = PlayerIntent.new()
	stun_timer = 0.0
	ghost_timer = 0.0
	ball_in_hands = false
	hands_time = 0.0
	handling.reset()
	ai.reset()
	_update_visual()


## Moves the player with its current intent. dribbling: this player has the ball.
func move(delta: float, court: CourtData, dribbling: bool) -> void:
	stun_timer = maxf(0.0, stun_timer - delta)
	ghost_timer = maxf(0.0, ghost_timer - delta)
	var dir := intent.move
	var sprint := intent.sprint
	var walk := intent.walk
	var knock_on := intent.knock_on and dribbling
	if stun_timer > 0.0:
		dir *= _stun_move_factor
		sprint = false
		walk = false
		knock_on = false
	_update_energy(delta, (sprint or knock_on) and dir.length() > 0.2, walk or dir.length() < 0.2)
	motion.step(delta, dir, sprint, dribbling, walk, knock_on)
	position += motion.velocity * delta
	if ball_in_hands:
		KeeperHands.clamp_to_area(self, court)
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


## Sprinting (and the knock-on) drains stamina (less for high stamina), otherwise it comes back,
## faster when walking or standing (resting). Below low_energy_threshold the top speed drops, down
## to low_energy_speed_mult when empty.
func _update_energy(delta: float, sprinting: bool, resting: bool = false) -> void:
	var moving := Vector2(motion.velocity.x, motion.velocity.z).length() > StatEffects.num("sprint_drain_min_speed", 1.0)
	if sprinting and moving:
		energy = maxf(0.0, energy - stat("stamina_drain", 0.06) * delta)
	else:
		var recover := StatEffects.num("energy_recover_per_second", 0.04)
		if resting:
			recover *= StatEffects.num("walk_recover_mult", 1.6)
		energy = minf(1.0, energy + recover * delta)
	var threshold := maxf(0.01, StatEffects.num("low_energy_threshold", 0.4))
	motion.energy_mult = lerpf(StatEffects.num("low_energy_speed_mult", 0.85), 1.0, clampf(energy / threshold, 0.0, 1.0))


## The body is built for reference_height (data/config/body.json) and scaled to the player's height.
func _scale_body() -> void:
	_body.scale = Vector3.ONE * height / float(Config.get_value("body", "reference_height", 1.75))


func _apply_look() -> void:
	var skin := profile.look_color("skin", Color.html(str(Config.get_value("body", "default_skin", "#c68a5e"))))
	var hair := profile.look_color("hair", Color.html(str(Config.get_value("body", "default_hair", "#1e1610"))))
	var style := str(profile.look.get("hair_style", "short"))
	_rig.set_look(skin, hair, style, PlayerRig.boot_color_for(profile.id))


func _update_visual() -> void:
	_body.rotation.y = atan2(motion.facing.x, motion.facing.z)
