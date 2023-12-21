extends Node3D

const test_obj = preload("res://effects/mech/mech_explode.tscn")
const map_default = "res://maps/map.tscn"

@onready var mech_list = $Mechs.get_children()
@onready var pov_cam = $ArenaUI/ActionBar/POV/Content/ViewCont/Viewport/POVCam
@onready var combat_pov_cam1 = $ArenaUI/POV1/ViewCont/Viewport/POVCam
@onready var combat_pov_cam2 = $ArenaUI/POV2/ViewCont/Viewport/POVCam
@onready var top_bar = $ArenaUI/TopBar
@onready var team_info_list = $ArenaUI/Team1Info.get_children() + $ArenaUI/Team2Info.get_children()

var match_data : Dictionary
var map_node = null
var start_points = []
var attack_list = []
var focus_mech_index = 0
var focus_mech = null

var turn_queue = []

signal match_ended


func _ready():
	$ArenaCam.target_mech = mech_list[focus_mech_index]
	load_map(map_default)


func _process(_delta):
	if Input.is_action_just_pressed("ui_end"):
		end_match()
	if Input.is_action_just_pressed("ui_page_up"):
		roll_attack()
		$Mechs/MechActor.anim_attack(attack_list)
	if Input.is_action_just_pressed("ui_page_down"):
		focus_mech_index += 1
		if focus_mech_index >= mech_list.size():
			focus_mech_index = 0
		$ArenaCam.target_mech = mech_list[focus_mech_index]
		update_markers(mech_list[focus_mech_index])
		pov_cam.transform = mech_list[focus_mech_index].transform
		pov_cam.global_position = mech_list[focus_mech_index].cam_point.global_position


func load_map(map_path):
	var map_obj = load(map_path)
	if is_instance_valid(map_node):
		map_node.free()
	map_node = map_obj.instantiate()
	add_child(map_node)


func setup_map():
	# Setup mech data and actors
	var this_team
	var this_mech
	for i in match_data.teams.size():
		this_team = match_data.teams[i]
		for j in this_team.mechs.size():
			this_mech = this_team.mechs[j]
			this_mech.reset_data()
			this_mech.team = this_team.index
			this_mech.num = j
			this_mech.actor_node = mech_list[(i * 4) + j]
			mech_list[(i * this_team.size()) + j].mech_data = this_mech
			mech_list[(i * this_team.size()) + j].setup_mech()
	# Place actors at start positions
	var spawn_groups = map_node.get_node("Spawns").get_children()
	spawn_groups.shuffle()
	var spawn_points = []
	for i in match_data.teams.size():
		spawn_points.append_array(spawn_groups[i].get_children())
	for j in spawn_points.size():
		mech_list[j].global_transform = spawn_points[j].global_transform
	# Update UI
	top_bar.match_info = match_data
	for i in team_info_list.size():
		team_info_list[i].focus_mech = mech_list[i].mech_data
		team_info_list[i].update_info()
	focus_mech_index = 0
	update_markers(mech_list[focus_mech_index])
	pov_cam.transform = mech_list[focus_mech_index].transform
	pov_cam.global_position = mech_list[focus_mech_index].cam_point.global_position


func end_match():
	if is_instance_valid(map_node):
		map_node.queue_free()
	hide()
	match_ended.emit()


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
	var wpn_type = "mgun"
	stats.wpn_r = PartDB.get_rand_weapon_type(wpn_type)
	stats.wpn_l = PartDB.get_rand_weapon_type(wpn_type)
	var podSet = str(randi() % PartDB.pod.size())
	stats.pod_r = PartDB.pod[podSet]
	stats.pod_l = PartDB.pod[podSet]
	stats.pack = PartDB.pack[str(randi() % PartDB.pack.size())]
	# Attach stat block to mech
	mech.mech_data = stats
	mech.setup_mech()


func hide_markers():
	$Markers/Select.visible = false
	$Markers/Move.visible = false
	$Markers/Attack.visible = false


func update_markers(mech):
	focus_mech = mech
	if is_instance_valid(focus_mech):
		$Markers/Select.position = focus_mech.get_position() + Vector3(0, 0.02, 0)
		$Markers/Select.visible = true
		if is_instance_valid(focus_mech.move_target):
			$Markers/Move.position = focus_mech.move_target.get_position() + Vector3(0, 0.02, 0)
			$Markers/Move.visible = true
		else:
			$Markers/Move.visible = false
		if is_instance_valid(focus_mech.attack_target):
			$Markers/Attack.position = focus_mech.attack_target.get_position() + Vector3(0, 0.02, 0)
			$Markers/Attack.visible = true
		else:
			$Markers/Attack.visible = false
	else:
		hide_markers()


func update_ui():
	pass


func _on_visibility_changed():
	$ArenaUI.visible = visible
	$ArenaCam.cam_node.current = visible

