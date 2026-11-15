class_name TeamBrain
extends RefCounted
## Team-level AI: every decision tick it picks, when defending, who chases the ball, who covers
## behind him and who marks whom (the most advanced opponents first), or, when attacking, the
## jobs of the players without the ball (AttackRoles); then it writes an intent for every player
## it drives (all except the human's player).

var team: Team
## Outfield player sent to the ball (null when the human's player is the closest).
var chaser: Player = null
## Outfield player covering behind the chaser, between the ball and our goal (or null).
var cover: Player = null
## Attack shape kept between decisions: the support player's angle from straight toward goal
## (degrees), the forward's side (+1 / -1 in z), and the last kick already seen (give-and-go).
var support_angle: float = 90.0
var forward_side: float = 1.0
var kick_seen: int = -1

var _think_timer: float = 0.0


func _init(owner_team: Team) -> void:
	team = owner_team


func reset() -> void:
	_think_timer = 0.0
	chaser = null
	cover = null


func update(delta: float, ctx: MatchContext, human_player: Player) -> void:
	AttackRoles.tick(self, delta, ctx)
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
	chaser = null
	cover = null
	for p in team.players:
		p.ai.mark = null
	if AttackRoles.in_possession(team, ctx):
		AttackRoles.assign(self, ctx, human_player)
		return
	AttackRoles.clear(team)
	var ball_pos := ctx.ball.position
	var closest := team.closest_outfield_to(ball_pos)
	if closest != null and closest != human_player:
		chaser = closest
	cover = _pick_cover(ctx, human_player, closest)
	_assign_marks(ctx, human_player)


## While the other side has the ball (or its pass is on the way) and the ball is far enough from
## our goal (cover_min_goal_distance): the outfield player nearest the cover point behind the ball
## (not the one pressing, never the human's player). A loose ball gets no cover: one player goes.
func _pick_cover(ctx: MatchContext, human_player: Player, presser: Player) -> Player:
	if not AttackRoles.in_possession(team.opponent, ctx):
		return null
	var ball_pos := ctx.ball.position
	var to_goal := Vector2(ball_pos.x - team.own_goal_x(ctx.court), ball_pos.z)
	if to_goal.length() < Steering.num("cover_min_goal_distance", 7.0):
		return null
	var spot := SupportAI.cover_point(team, ctx)
	var best: Player = null
	var best_d := INF
	for p in team.outfield():
		if p == presser or p == human_player:
			continue
		var d := p.flat_distance_to(spot)
		if d < best_d:
			best_d = d
			best = p
	return best


## Marking: the free opponents in our part of the court (mark_zone_frac), the most advanced
## first, each get the nearest outfield player not yet marking, chasing or covering.
func _assign_marks(ctx: MatchContext, human_player: Player) -> void:
	var court := ctx.court
	var zone := Steering.num("mark_zone_frac", 0.62)
	var free_opponents: Array[Player] = []
	for opp in team.opponent.outfield():
		if opp != ctx.possession.holder and team.to_frac(opp.position.x, court) < zone:
			free_opponents.append(opp)
	free_opponents.sort_custom(func(a: Player, b: Player) -> bool:
		return team.to_frac(a.position.x, court) < team.to_frac(b.position.x, court))
	var markers: Array[Player] = []
	for p in team.outfield():
		if p != chaser and p != cover and p != human_player:
			markers.append(p)
	for opp in free_opponents:
		if markers.is_empty():
			return
		var best_i := 0
		var best_d := INF
		for i in range(markers.size()):
			var d := markers[i].flat_distance_to(opp.position)
			if d < best_d:
				best_d = d
				best_i = i
		markers[best_i].ai.mark = opp
		markers.remove_at(best_i)
