class_name LoftedAI
extends RefCounted
## The AI carrier's ball in the air (switch of play) when no ground pass is on: to a teammate in
## range (lofted_ai_min/max_distance) with nobody within lofted_ai_open_distance of him, not much
## further back (lofted_ai_max_back_frac); the most open and most advanced one. The power is the
## one that lands the ball where he will be, give or take lofted_power_error (by difficulty).
## Numbers: data/config/ai.json.


static func target(player: Player, ctx: MatchContext) -> Player:
	var team := player.team
	var court := ctx.court
	var my_frac := team.to_frac(player.position.x, court)
	var best: Player = null
	var best_score := -INF
	for mate in team.outfield():
		if mate == player:
			continue
		var d := player.flat_distance_to(mate.position)
		if d < Steering.num("lofted_ai_min_distance", 9.0) or d > Steering.num("lofted_ai_max_distance", 26.0):
			continue
		var open := team.opponent.nearest_distance_to(mate.position)
		if open < Steering.num("lofted_ai_open_distance", 3.5):
			continue
		var progress := team.to_frac(mate.position.x, court) - my_frac
		if progress < -Steering.num("lofted_ai_max_back_frac", 0.1):
			continue
		var score := minf(open, Steering.num("pass_open_cap", 5.0)) * Steering.num("pass_open_weight", 0.3) \
			+ progress * Steering.num("pass_progress_weight", 3.0)
		if score > best_score:
			best_score = score
			best = mate
	return best


static func intent(player: Player, mate: Player, ctx: MatchContext) -> PlayerIntent:
	var flight := LoftedKick.flight_time(player.flat_distance_to(mate.position))
	var lead := Steering.flat(mate.motion.velocity) * flight * float(Config.get_value("player", "pass_lead_factor", 0.8))
	var landing := player.flat_distance_to(mate.position + lead)
	var error := player.team.tuning.lofted_power_error
	var result := PlayerIntent.new()
	result.move = Steering.flat(mate.position - player.position).normalized()
	result.pass_pressed = true
	result.pass_lofted = true
	result.kick_power = clampf(LoftedKick.power_for(landing) + ctx.rng.randf_range(-error, error), 0.0, 1.0)
	return result
