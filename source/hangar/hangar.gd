extends Node3D

enum HangarState {WORKSHOP, HANGAR}

const cam_home_workshop = {"pos":Vector3(-2.5, 2, 17), "rot":Vector3(0, -15, 0)}
const cam_home_hangar = {"pos":Vector3(0, 3, -0.5), "rot":Vector3(-15, 0, 0)}
const cam_points = [
	{"pos":Vector3(-1, 2, -4.5), "rot":Vector3(-15, 90, 0)},
	{"pos":Vector3(-1, 2, -8.5), "rot":Vector3(-15, 90, 0)},
	{"pos":Vector3(-1, 2, -12.5), "rot":Vector3(-15, 90, 0)},
	{"pos":Vector3(-1, 2, -16.5), "rot":Vector3(-15, 90, 0)},
	{"pos":Vector3(1, 2, -14), "rot":Vector3(-15, -90, 0)},
	{"pos":Vector3(1, 2, -10), "rot":Vector3(-15, -90, 0)},
	{"pos":Vector3(1, 2, -6), "rot":Vector3(-15, -90, 0)},
	{"pos":Vector3(1, 2, -2), "rot":Vector3(-15, -90, 0)},
]

@onready var arms_top = $ArmsTop.get_children()
@onready var arms_side = $ArmsSide.get_children()
@onready var hangar_lights = $LightsHangar.get_children()
@onready var workshop_lights = $LightsWorkshop.get_children()
@onready var team1 = $Team1.get_children()
@onready var team2 = $Team2.get_children()
@onready var signs = $Signs.get_children()
@onready var hangar_cam = $HangarCam

@export var debug = true

var state = HangarState.WORKSHOP
var cam_tween
var cam_point = 0

signal left_workshop
signal mechs_deployed


func _ready():
	reset_scene("workshop")
	reroll_all()


func _process(_delta):
	if debug:
		if Input.is_action_just_pressed("ui_screenshot"):
			GameData.screenshot()
		if Input.is_action_just_pressed("ui_end"):
			reroll_all()
		if Input.is_action_just_pressed("ui_page_up"):
			move_out()
		if Input.is_action_just_pressed("ui_home"):
			move_cam(cam_point)
			cam_point += 1
			if cam_point >= cam_points.size():
				cam_point = 0
		if Input.is_action_just_pressed("ui_accept"):
			match state:
				HangarState.WORKSHOP:
					workshop_out()
				HangarState.HANGAR:
					move_out()


func reset_scene(type):
	if cam_tween is Tween:
		cam_tween.kill()
	#$Anims.play("RESET")
	match type:
		"workshop":
			state = HangarState.WORKSHOP
			hangar_cam.position = cam_home_workshop.pos
			hangar_cam.rotation_degrees = cam_home_workshop.rot
			for light in hangar_lights:
				light.get_node("Anims").play("off")
		"hangar":
			state = HangarState.HANGAR
			hangar_cam.position = cam_home_hangar.pos
			hangar_cam.rotation_degrees = cam_home_hangar.rot
			for light in hangar_lights:
				light.get_node("Anims").play("normal")
	$HangarSign.message = "READY"
	for arm in arms_top:
		arm.is_horizontal = true
	for mech in (team1 + team2):
		for part in mech.mech_parts:
			if is_instance_valid(mech.mech_parts[part].anim):
				mech.mech_parts[part].anim.stop()


func load_mechs(team_list):
	var all_mechs = (team1 + team2)
	var all_data = (team_list[0].mechs + team_list[1].mechs)
	for i in all_mechs.size():
		all_mechs[i].team = all_data[i].team
		all_mechs[i].mech_data = all_data[i]
		all_mechs[i].state = all_mechs[i].MechState.DONE
		all_mechs[i].setup_mech()
		signs[i].update_sign(all_data[i])
	for arm in (arms_side + arms_top):
		arm._ready()


func update_hp(hp_list):
	var all_mechs = (team1 + team2)
	for i in all_mechs.size():
		if hp_list[i].body <= 0:
			all_mechs[i].bodyHP = 1
		else:
			all_mechs[i].bodyHP = hp_list[i].body
		all_mechs[i].armRHP = hp_list[i].arm_r
		all_mechs[i].armLHP = hp_list[i].arm_l
		all_mechs[i].legsHP = hp_list[i].legs
	for arm in (arms_side + arms_top):
		arm._ready()


func workshop_out():
	for arm in (arms_top + arms_side):
		arm.reset_arm()
	$Anims.play("leave_workshop")
	await $Anims.animation_finished
	for light in hangar_lights:
		light.get_node("Anims").play("off")
	$LightsHangar/HangarLight/Anims.play("turn_on")
	$LightsHangar/HangarLight2/Anims.play("turn_on")
	await $LightsHangar/HangarLight2/Anims.animation_finished
	$LightsHangar/HangarLight3/Anims.play("turn_on")
	$LightsHangar/HangarLight4/Anims.play("turn_on")
	await $LightsHangar/HangarLight4/Anims.animation_finished
	$LightsHangar/HangarLight5/Anims.play("turn_on")
	$LightsHangar/HangarLight6/Anims.play("turn_on")
	await $LightsHangar/HangarLight6/Anims.animation_finished
	$LightsHangar/HangarLight7/Anims.play("turn_on")
	$LightsHangar/HangarLight8/Anims.play("turn_on")
	await $LightsHangar/HangarLight8/Anims.animation_finished
	left_workshop.emit()


func move_out():
	cam_tween = create_tween()
	cam_tween.set_parallel()
	cam_tween.tween_property(hangar_cam, "position", cam_home_hangar.pos, 0.5)
	cam_tween.tween_property(hangar_cam, "rotation_degrees", cam_home_hangar.rot, 0.5)
	cam_tween.play()
	for light in hangar_lights:
		light.get_node("Anims").play("warning")
	for arm in (arms_top + arms_side):
		arm.reset_arm()
	$Anims.play("open_hangar")
	await $Anims.animation_finished
	$HangarSign.message = "DEPLOY"
	for mech in (team1 + team2):
		mech.anim_walk()
	$Anims.play("mechs_out")
	await $Anims.animation_finished
	mechs_deployed.emit()


func move_cam(point):
	cam_tween = create_tween()
	cam_tween.set_parallel()
	cam_tween.tween_property(hangar_cam, "position", cam_points[point].pos, 0.5)
	cam_tween.tween_property(hangar_cam, "rotation_degrees", cam_points[point].rot, 0.5)
	cam_tween.play()


func reroll_all():
	var all_mechs = team1 + team2
	for i in all_mechs.size():
		roll_stats(all_mechs[i])
		signs[i].update_sign(all_mechs[i].mech_data)


func roll_stats(mech):
	var stats = MechStats.new()
	stats.id = 0
	stats.pilot = PartDB.drone[PartDB.drone.keys()[randi() % PartDB.drone.keys().size()]]
	var partSet = str(randi() % PartDB.body.size())
	stats.body = PartDB.body[partSet]
	stats.arm_r = PartDB.arm[partSet]
	stats.arm_l = PartDB.arm[partSet]
	stats.legs = PartDB.legs[partSet]
	var wpnSet = str(randi() % PartDB.weapon.size())
	stats.wpn_r = PartDB.weapon[wpnSet]
	stats.wpn_l = PartDB.weapon[wpnSet]
	var podSet = str(randi() % PartDB.pod.size())
	stats.pod_r = PartDB.pod[podSet]
	stats.pod_l = PartDB.pod[podSet]
	stats.pack = PartDB.pack[str(randi() % PartDB.pack.size())]
	# Attach stat block to mech
	mech.mech_data = stats
	mech.setup_mech()

