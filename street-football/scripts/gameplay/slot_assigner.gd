class_name SlotAssigner
extends RefCounted
## Puts each player in the formation slot that suits him: the best keeper in goal (slot 0), then
## the 4 outfield players in the order that gives the highest total overall rating for the roles.


## Returns, for each slot, the index of the profile placed there.
static func assign(profiles: Array[PlayerProfile], formation: FormationData) -> Array[int]:
	var count := mini(profiles.size(), formation.slots.size())
	var result: Array[int] = []
	result.resize(count)
	if count == 0:
		return result
	var keeper := 0
	var best_keeper := -1
	for i in range(profiles.size()):
		var rating := Ratings.overall(profiles[i], "GK")
		if rating > best_keeper:
			best_keeper = rating
			keeper = i
	result[0] = keeper
	var rest: Array[int] = []
	for i in range(profiles.size()):
		if i != keeper:
			rest.append(i)
	var best_order: Array[int] = rest.duplicate()
	var best_score := -1
	for order in _permutations(rest):
		var score := 0
		for s in range(1, count):
			score += Ratings.overall(profiles[order[s - 1]], formation.role(s))
		if score > best_score:
			best_score = score
			best_order.assign(order)
	for s in range(1, count):
		result[s] = best_order[s - 1]
	return result


static func _permutations(items: Array[int]) -> Array[Array]:
	var out: Array[Array] = []
	if items.size() <= 1:
		out.append(items.duplicate())
		return out
	for i in range(items.size()):
		var rest: Array[int] = items.duplicate()
		var first: int = rest[i]
		rest.remove_at(i)
		for tail in _permutations(rest):
			var perm: Array[int] = [first]
			for v in tail:
				perm.append(int(v))
			out.append(perm)
	return out
