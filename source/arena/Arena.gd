extends Node3D

var attack_list = []

# Called when the node enters the scene tree for the first time.
func _ready():
	reset_arena()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("ui_home"):
		reset_arena()
	if Input.is_action_just_pressed("ui_page_up"):
		$Mechs/MechActor.anim_attack(attack_list)


func reset_arena():
	$Mechs/MechActor.team = randi() % 8
	$Mechs/MechActor.team = randi() % 8
	for mech in $Mechs.get_children():
		roll_stats(mech)
	$Mechs/MechActor.attack_weapon = $Mechs/MechActor.weapon_list[0]
	attack_list.clear()
	for i in $Mechs/MechActor.weapon_list[3].fire_rate:
		attack_list.append(
			{"target":$Mechs/MechActor2, "part":"body", "type":"mgun", "damage":0, "multiplier":1, "effect_type":"none", "effect_duration":0},
		)
	$Mechs/MechActor.attack_target = $Mechs/MechActor2
	$Mechs/MechActor2.attack_weapon = $Mechs/MechActor2.weapon_list[3]
	$Mechs/MechActor2.attack_target = $Mechs/MechActor


func roll_stats(mech):
	var stats = MechStats.new()
	stats.id = 0
	stats.pilot = PartDB.drone[PartDB.drone.keys()[randi() % PartDB.drone.keys().size()]]
	var partSet = str(randi() % PartDB.body.size())
	stats.body = PartDB.body[partSet]
	stats.arm_r = PartDB.arm[partSet]
	stats.arm_l = PartDB.arm[partSet]
	stats.legs = PartDB.legs[partSet]
	# sgun = 0, mgun = 4, flame = 9, rifle = 12, melee = 19
	var wpnSet = "0" #str(randi() % PartDB.weapon.size())
	stats.wpn_r = PartDB.weapon[wpnSet]
	stats.wpn_l = PartDB.weapon[wpnSet]
	var podSet = str(randi() % PartDB.pod.size())
	stats.pod_r = PartDB.pod[podSet]
	stats.pod_l = PartDB.pod[podSet]
	stats.pack = PartDB.pack[str(randi() % PartDB.pack.size())]
	# Attach stat block to mech
	mech.mech_data = stats
	mech.setup_mech()
