class_name Ratings
extends RefCounted
## Overall rating per role and position fitness, from data/config/ratings.json.


## 1.0 in a natural position, less elsewhere (adjacent, other, keeper outfield, outfielder in goal).
static func position_fitness(profile: PlayerProfile, role: String) -> float:
	var fit: Dictionary = Config.get_value("ratings", "position_fitness", {})
	if profile.positions.has(role):
		return float(fit.get("natural", 1.0))
	if role == "GK":
		return float(fit.get("outfield_in_goal", 0.6))
	if profile.is_keeper():
		return float(fit.get("keeper_outfield", 0.75))
	var adjacent: Dictionary = Config.get_value("ratings", "adjacent", {})
	for pos in profile.positions:
		var near: Array = adjacent.get(str(pos), [])
		if near.has(role):
			return float(fit.get("adjacent", 0.95))
	return float(fit.get("other", 0.88))


static func overall(profile: PlayerProfile, role: String) -> int:
	var all_weights: Dictionary = Config.get_value("ratings", "weights", {})
	var weights: Dictionary = all_weights.get(role, {})
	var total := 0.0
	var weight_sum := 0.0
	for key in weights:
		var w := float(weights[key])
		total += profile.attr(str(key)) * w
		weight_sum += w
	if weight_sum <= 0.0:
		return 0
	return roundi(total / weight_sum * position_fitness(profile, role))


## Best overall over the player's natural positions.
static func best_overall(profile: PlayerProfile) -> int:
	var best := 0
	for pos in profile.positions:
		best = maxi(best, overall(profile, str(pos)))
	return best
