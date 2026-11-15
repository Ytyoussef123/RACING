class_name BodyBounce
extends RefCounted
## A loose ball (or an opponent's) bounces off a player's body; it passes through a ghosted player
## (nutmegged, or the kicker just after his kick). Numbers: data/config/player.json body_restitution.


static func apply(player: Player, ctx: MatchContext) -> void:
	var ball := ctx.ball
	if ball.position.y > player.height or player.ghost_timer > 0.0:
		return
	var d := Vector2(ball.position.x - player.position.x, ball.position.z - player.position.z)
	var min_dist := player.radius + ball.radius
	var dist := d.length()
	if dist >= min_dist or dist < 0.0001:
		return
	var n := d / dist
	ball.position.x = player.position.x + n.x * min_dist
	ball.position.z = player.position.z + n.y * min_dist
	var rel := Vector2(ball.velocity.x - player.motion.velocity.x, ball.velocity.z - player.motion.velocity.z)
	var vn := rel.dot(n)
	if vn < 0.0:
		var e := float(Config.get_value("player", "body_restitution", 0.3))
		ball.velocity.x -= (1.0 + e) * vn * n.x
		ball.velocity.z -= (1.0 + e) * vn * n.y
		ctx.possession.touched(player)
