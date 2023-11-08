extends Node3D

const test_obj = preload("res://effects/mech/mech_explode.tscn")

@onready var mech_list = $Mechs.get_children()
@onready var pov1 = $ArenaUI/POV1/ViewCont/Viewport
@onready var pov2 = $ArenaUI/POV2/ViewCont/Viewport
@onready var pov_cam1 = $ArenaUI/POV1/ViewCont/Viewport/POVCam
@onready var pov_cam2 = $ArenaUI/POV2/ViewCont/Viewport/POVCam

var attack_list = []
var focus_mech_index = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	$ArenaCam.target_mech = mech_list[focus_mech_index]
	reset_arena()
	pov_cam1.transform = mech_list[focus_mech_index].transform
	pov_cam1.global_position = mech_list[focus_mech_index].cam_point.global_position
	pov_cam2.transform = $Mechs/MechActor2.transform
	pov_cam2.global_position = $Mechs/MechActor2.cam_point.global_position


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("ui_home"):
		reset_arena()
	if Input.is_action_just_pressed("ui_end"):
		roll_attack()
		$Mechs/MechActor.anim_attack(attack_list)
	if Input.is_action_just_pressed("ui_page_up"):
		var test_inst = test_obj.instantiate()
		add_child(test_inst)
	if Input.is_action_just_pressed("ui_page_down"):
		focus_mech_index += 1
		if focus_mech_index >= mech_list.size():
			focus_mech_index = 0
		$ArenaCam.target_mech = mech_list[focus_mech_index]
		pov_cam1.transform = mech_list[focus_mech_index].transform
		pov_cam1.global_position = mech_list[focus_mech_index].cam_point.global_position


func reset_arena():
	$Mechs/MechActor.team = randi() % 8
	$Mechs/MechActor.team = randi() % 8
	for mech in $Mechs.get_children():
		roll_stats(mech)
	$Mechs/MechActor.attack_weapon = $Mechs/MechActor.weapon_list[3]
	$Mechs/MechActor.attack_target = $Mechs/MechActor2
	$Mechs/MechActor2.attack_weapon = $Mechs/MechActor2.weapon_list[3]
	$Mechs/MechActor2.attack_target = $Mechs/MechActor


func roll_attack():
	var parts = ["body", "arm_r", "arm_l", "legs"]
	attack_list.clear()
	for i in $Mechs/MechActor.attack_weapon.fire_rate:
		attack_list.append({
			"target":$Mechs/MechActor2,
			"part":parts.pick_random(),
			"type":$Mechs/MechActor.attack_weapon.type,
			"damage":$Mechs/MechActor.attack_weapon.damage, 
			"multiplier":1,
			"effect_type":"none", "effect_duration":0
		})


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
	var wpnSet = "4" #str(randi() % PartDB.weapon.size())
	stats.wpn_r = PartDB.weapon[wpnSet]
	stats.wpn_l = PartDB.weapon[wpnSet]
	var podSet = str(randi() % PartDB.pod.size())
	stats.pod_r = PartDB.pod[podSet]
	stats.pod_l = PartDB.pod[podSet]
	stats.pack = PartDB.pack[str(randi() % PartDB.pack.size())]
	# Attach stat block to mech
	mech.mech_data = stats
	mech.setup_mech()
