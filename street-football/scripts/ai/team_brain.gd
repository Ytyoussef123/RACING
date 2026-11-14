class_name TeamBrain
extends RefCounted
## Team-level AI: every decision tick it picks who chases the ball and who marks whom,
## then writes an intent for every player it drives (all except the human's player).

var team: Team
## Outfield player sent to the ball (null when the human's player is the closest).
var chaser: Player = null

var _think_timer: float = 0.0


func _init(owner_team: Team) -> void:
	team = owner_team


func reset() -> void:
	_think_timer = 0.0
	chaser = null


func update(delta: float, ctx: MatchContext, human_player: Player) -> void:
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = team.tuning.decision_interval
		_assign_roles(ctx, human_player)
	for p in team.players:
		if p == human_player:
			continue
		p.intent = _intent_for(p, delta, ctx)


func _intent_for(p: Player, delta: float, ctx: MatchContext) -> PlayerIntent:
	if p.is_keeper:
		return KeeperAI.intent_for(p, delta, ctx)
	if ctx.possession.holder == p:
		return CarrierAI.intent_for(p, delta, ctx)
	return SupportAI.intent_for(p, delta, ctx, self)


func _assign_roles(ctx: MatchContext, human_player: Player) -> void:
	var possession := ctx.possession
	var holder := possession.holder
	var attacking := holder != null and holder.team == team
	chaser = null
	for p in team.players:
		p.ai.mark = null
	if attacking:
		return
	var ball_pos := ctx.ball.position
	var closest := team.closest_outfield_to(ball_pos)
	if closest != null and closest != human_player:
		chaser = closest
	_assign_marks(ctx, human_player)


## Greedy marking: each free outfield player takes the nearest unmarked opponent in our half.
func _assign_marks(ctx: MatchContext, human_player: Player) -> void:
	var court := ctx.court
	var zone := Steering.num("mark_zone_frac", 0.62)
	var free_opponents: Array[Player] = []
	for opp in team.opponent.outfield():
		if opp != ctx.possession.holder and team.to_frac(opp.position.x, court) < zone:
			free_opponents.append(opp)
	for p in team.outfield():
		if p == chaser or p == human_player or free_opponents.is_empty():
			continue
		var best_i := -1
		var best_d := INF
		for i in range(free_opponents.size()):
			var d := p.flat_distance_to(free_opponents[i].position)
			if d < best_d:
				best_d = d
				best_i = i
		p.ai.mark = free_opponents[best_i]
		free_opponents.remove_at(best_i)
