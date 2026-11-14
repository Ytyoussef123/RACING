class_name HumanControl
extends RefCounted
## Which player the human controls, and switching: on request, when a pass leaves for a
## teammate, when a teammate gets the ball, and automatically when defending.
## Numbers: data/config/match.json (auto_switch*, switch_cooldown).

var team: Team
var controlled: Player = null

var _switch_timer: float = 0.0


func _init(human_team: Team) -> void:
	team = human_team


func select(player: Player) -> void:
	if player == null or player == controlled:
		return
	if controlled != null:
		controlled.set_selected(false)
	controlled = player
	controlled.set_selected(true)
	_switch_timer = float(Config.get_value("match", "switch_cooldown", 0.8))


func update(delta: float, intent: PlayerIntent, ctx: MatchContext) -> void:
	_switch_timer = maxf(0.0, _switch_timer - delta)
	var possession := ctx.possession
	var holder := possession.holder
	var ball_pos := ctx.ball.position
	if holder != null and holder.team == team and not holder.is_keeper:
		select(holder)
		return
	var target := possession.pass_target
	if holder == null and target != null and target.team == team and not target.is_keeper:
		select(target)
		return
	if intent.switch_pressed:
		select(team.closest_outfield_to(ball_pos, controlled))
		return
	var defending := holder == null or holder.team != team
	if defending and _switch_timer <= 0.0 and bool(Config.get_value("match", "auto_switch", true)):
		var nearest := team.closest_outfield_to(ball_pos)
		var margin := float(Config.get_value("match", "auto_switch_margin", 2.5))
		if nearest != null and nearest != controlled \
				and controlled.flat_distance_to(ball_pos) - nearest.flat_distance_to(ball_pos) > margin:
			select(nearest)


## The human's PASS button becomes TACKLE when an opponent has the ball.
func opponent_has_ball(ctx: MatchContext) -> bool:
	var holder := ctx.possession.holder
	return holder != null and holder.team != team
