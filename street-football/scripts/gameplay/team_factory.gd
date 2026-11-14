class_name TeamFactory
extends RefCounted
## Creates a team on the court: one player node per crew member (data/teams), each given his
## profile, placed in the formation slot that suits him (SlotAssigner) and dressed in the kit.


static func build(parent: Node3D, player_scene: PackedScene, index: int, data: TeamData,
		formation_id: String, alt_kit: bool, tuning: AiTuning, speed_factor: float) -> Team:
	var team := Team.new()
	team.index = index
	team.data = data
	team.attack_sign = 1.0 if index == 0 else -1.0
	team.color = data.color("alt_kit" if alt_kit else "kit", Color.WHITE)
	team.keeper_color = data.color("alt_keeper" if alt_kit else "keeper", Color.GRAY)
	team.tuning = tuning
	team.formation = FormationData.load_formation(formation_id)
	for i in range(data.players.size()):
		var entry: Dictionary = data.players[i]
		var p: Player = player_scene.instantiate()
		p.name = "T%dP%d" % [index, i]
		parent.add_child(p)
		p.team = team
		p.motion.speed_factor = speed_factor
		p.profile = Roster.player(str(entry.get("id", "")))
		p.number = int(entry.get("number", i + 1))
		team.players.append(p)
	team.assign_slots()
	for p in team.players:
		p.set_kit(team.keeper_color if p.is_keeper else team.color)
	team.brain = TeamBrain.new(team)
	return team


## True when two kits are too alike to tell apart (the away team then wears its alternate kit).
static func kits_clash(a: Color, b: Color) -> bool:
	var threshold := float(Config.get_value("match", "kit_clash_distance", 0.35))
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < threshold
