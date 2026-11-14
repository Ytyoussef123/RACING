class_name SkillMoves
extends RefCounted
## Skill moves, done by flicking the joystick with the ball. The flick direction compared to the
## player's facing picks the move:
##   forward: rainbow flick over a close defender (special skill), nutmeg through a defender right
##            in front (special skill), otherwise a knock-on (big touch ahead to run onto);
##   side:    elastico / flip-flap (special skill) or step-over: the ball is cut sideways;
##   back:    heel-flick pass to a teammate behind (special skill), roulette (special skill) or
##            drag-back.
## Success depends on skill-move stars and dribbling; a miss is a bad touch. A successful move can
## fool nearby defenders (they freeze for a moment). After the move the ball is played to the
## player himself, so the receive assist runs him onto it. Numbers: data/config/skills.json.

## Returns the move done ("" when the player cannot do any), and emits a "skill" match event.
static func perform(player: Player, ctx: MatchContext, flick: Vector3, roll: float = -1.0) -> String:
	var facing := player.motion.facing
	var dir := Steering.flat(flick).normalized()
	if dir == Vector3.ZERO:
		return ""
	var angle := rad_to_deg(facing.angle_to(dir))
	var move := _choose(player, ctx, dir, angle)
	if move.is_empty():
		return ""
	var success_roll := roll if roll >= 0.0 else ctx.rng.randf()
	if success_roll >= success_chance(player):
		_bad_touch(player, ctx)
		ctx.emit_event("skill", player.position, 0.0, "SKILL_FAILED")
		return "failed"
	_do(move, player, ctx, dir)
	_fool_defenders(player, ctx)
	player.animate("skill", 1.0 if dir.dot(Vector3(-facing.z, 0.0, facing.x)) >= 0.0 else -1.0)
	ctx.emit_event("skill", player.position, 1.0, "SKILL_" + move.to_upper())
	return move


## Stars and dribbling decide how often a move works.
static func success_chance(player: Player) -> float:
	var stars := player.profile.skill_moves if player.profile != null else 3
	var dribbling := player.profile.attr("dribbling") if player.profile != null else _num("dribbling_reference", 75.0)
	var chance := _num("base_success", 0.45) + stars * _num("success_per_star", 0.1) \
		+ (dribbling - _num("dribbling_reference", 75.0)) * _num("success_per_dribbling_point", 0.004)
	return clampf(chance, 0.05, _num("max_success", 0.97))


static func _choose(player: Player, ctx: MatchContext, dir: Vector3, angle: float) -> String:
	if angle < _num("forward_degrees", 50.0):
		var ahead := _nearest_opponent_ahead(player, ctx)
		if ahead != null:
			var d := player.flat_distance_to(ahead.position)
			if d < _num("nutmeg_defender_distance", 1.6) and _can(player, "nutmeg"):
				return "nutmeg"
			if d < _num("rainbow_defender_distance", 3.0) and _can(player, "rainbow"):
				return "rainbow"
		return "knock_on" if _can(player, "knock_on") else ""
	if angle > _num("back_degrees", 130.0):
		if _can(player, "heel_flick") and _teammate_behind(player, ctx, dir) != null:
			return "heel_flick"
		if _can(player, "roulette"):
			return "roulette"
		return "drag_back" if _can(player, "drag_back") else ""
	if _can(player, "elastico"):
		return "elastico"
	return "step_over" if _can(player, "step_over") else ""


## Enough stars, and the special skill for the special moves.
static func _can(player: Player, move: String) -> bool:
	var stars := player.profile.skill_moves if player.profile != null else 3
	var min_stars: Dictionary = Config.get_value("skills", "min_stars", {})
	if stars < int(min_stars.get(move, 1)):
		return false
	var special := {"elastico": "flip_flap", "roulette": "roulette", "rainbow": "rainbow", "nutmeg": "nutmeg",
		"heel_flick": "heel_flick"}
	if special.has(move):
		return player.profile != null and player.profile.special_skills.has(str(special[move]))
	return true


static func _do(move: String, player: Player, ctx: MatchContext, dir: Vector3) -> void:
	var ball := ctx.ball
	var facing := player.motion.facing
	var run := Steering.flat(player.motion.velocity)
	var blocks: Dictionary = Config.get_value("skills", "retake_block_seconds", {})
	var block := float(blocks.get(move, 0.15))
	match move:
		"knock_on":
			_play_to_self(player, ctx, facing * (run.length() + _num("knock_on_speed", 6.0)), block)
		"nutmeg":
			var victim := _nearest_opponent_ahead(player, ctx)
			if victim != null:
				victim.ghost_timer = _num("nutmeg_ghost_seconds", 0.45)
			_play_to_self(player, ctx, facing * _num("nutmeg_speed", 6.5), block)
		"rainbow":
			_play_to_self(player, ctx, facing * _num("rainbow_forward_speed", 7.0) + Vector3.UP * _num("rainbow_lift", 5.5), block)
		"step_over", "elastico":
			var side := dir - facing * dir.dot(facing)
			side = side.normalized() if side.length() > 0.01 else Vector3(-facing.z, 0.0, facing.x)
			var speed := _num("elastico_side_speed", 4.5) if move == "elastico" else _num("step_over_side_speed", 3.5)
			player.motion.facing = (facing + side).normalized()
			_play_to_self(player, ctx, run * 0.5 + side * speed, block)
		"drag_back", "roulette":
			player.motion.facing = -facing
			player.motion.velocity = -facing * 0.5
			_play_to_self(player, ctx, -facing * _num("drag_back_speed", 3.0), block)
		"heel_flick":
			var mate := _teammate_behind(player, ctx, dir)
			if mate != null:
				var to := Steering.flat(mate.position - player.position).normalized()
				ctx.possession.kicked(player, mate, ball, "pass")
				ball.kick(to * _num("heel_flick_speed", 9.0), 0.0)
				ctx.stats.passes[player.team.index] += 1


## The ball is played to the player himself: he stays the "pass target", so the receive assist and
## the AI run onto it, and nobody of his team blocks it.
static func _play_to_self(player: Player, ctx: MatchContext, kick_velocity: Vector3, block: float) -> void:
	ctx.possession.kicked(player, player, ctx.ball, "skill")
	ctx.ball.kick(kick_velocity, 0.0)
	player.handling.block_control(block)


static func _bad_touch(player: Player, ctx: MatchContext) -> void:
	var angle := ctx.rng.randf_range(-PI, PI)
	ctx.possession.release(ctx.ball)
	ctx.possession.touched(player)
	ctx.ball.kick(Vector3(cos(angle), 0.0, sin(angle)) * _num("bad_touch_speed", 3.0), 0.0)
	player.handling.block_control(0.4)


## Defenders close in front may be fooled: they freeze for a moment.
static func _fool_defenders(player: Player, ctx: MatchContext) -> void:
	var stars := player.profile.skill_moves if player.profile != null else 3
	var chance := clampf(_num("fool_base", 0.3) + stars * _num("fool_per_star", 0.12), 0.0, 0.95)
	if player.team.opponent == null:
		return
	for opp in player.team.opponent.players:
		if opp.is_keeper or player.flat_distance_to(opp.position) > _num("fool_radius", 2.6):
			continue
		if ctx.rng.randf() < chance:
			opp.stun_timer = maxf(opp.stun_timer, _num("fool_seconds", 0.55))
			opp.handling.block_control(_num("fool_seconds", 0.55) * 0.8)


static func _nearest_opponent_ahead(player: Player, ctx: MatchContext) -> Player:
	if player.team.opponent == null:
		return null
	var best: Player = null
	var best_d := INF
	for opp in player.team.opponent.outfield():
		var to := Steering.flat(opp.position - player.position)
		var d := to.length()
		if d < 0.01 or to.normalized().dot(player.motion.facing) < 0.7:
			continue
		if d < best_d:
			best_d = d
			best = opp
	return best


static func _teammate_behind(player: Player, ctx: MatchContext, dir: Vector3) -> Player:
	var best: Player = null
	var best_d := _num("heel_flick_max_distance", 10.0)
	for mate in player.team.players:
		if mate == player:
			continue
		var to := Steering.flat(mate.position - player.position)
		var d := to.length()
		if d < 1.0 or d > best_d or to.normalized().dot(dir) < 0.6:
			continue
		best_d = d
		best = mate
	return best


static func _num(key: String, fallback: float) -> float:
	return float(Config.get_value("skills", key, fallback))
