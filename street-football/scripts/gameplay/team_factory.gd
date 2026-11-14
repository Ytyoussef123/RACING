class_name TeamFactory
extends RefCounted
## Creates a team: 5 player nodes from the player scene, placed in their formation slots.


static func build(parent: Node3D, player_scene: PackedScene, index: int, formation_id: String,
		kit: Color, keeper_kit: Color, tuning: AiTuning, speed_factor: float) -> Team:
	var team := Team.new()
	team.index = index
	team.attack_sign = 1.0 if index == 0 else -1.0
	team.color = kit
	team.keeper_color = keeper_kit
	team.tuning = tuning
	team.formation = FormationData.load_formation(formation_id)
	for i in range(team.formation.slots.size()):
		var p: Player = player_scene.instantiate()
		p.name = "T%dP%d" % [index, i]
		parent.add_child(p)
		p.team = team
		p.slot_index = i
		p.role = team.formation.role(i)
		p.is_keeper = p.role == "GK"
		p.set_kit(keeper_kit if p.is_keeper else kit)
		p.motion.speed_factor = speed_factor
		team.players.append(p)
		if p.is_keeper:
			team.keeper = p
	team.brain = TeamBrain.new(team)
	return team
