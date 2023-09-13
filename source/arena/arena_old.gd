extends Node3D

enum MapState {IDLE, INTRO, FIGHT, OUTRO}
enum HitTable {Body = 20, ArmR = 20, ArmL = 20, Leg = 40}

const MSG_TIME = 2.0
const msg_match_info = "Tournament %d, %s\n%s - VS - %s"
const msg_map_info = "%s\n%s, %s"
const TILE_WIDTH = 2
const X_OFFSET = 1
const Z_OFFSET = 1
const skills = ["melee", "short", "long"]
# Map file paths and names
const map_list = [
	{"path":"res://scenes/maps/Map000.tscn", "name":"Industrial Park"},
	{"path":"res://scenes/maps/Map001.tscn", "name":"Tower Islands"},
	{"path":"res://scenes/maps/Map002.tscn", "name":"Little Bridge"},
	{"path":"res://scenes/maps/Map003.tscn", "name":"Hillside Bunker"},
	{"path":"res://scenes/maps/Map004.tscn", "name":"City Ruins"},
	{"path":"res://scenes/maps/Map005.tscn", "name":"Old Bridge"},
	{"path":"res://scenes/maps/Map006.tscn", "name":"Lonely Hills"},
	{"path":"res://scenes/maps/Map007.tscn", "name":"Canyon Road"},
	{"path":"res://scenes/maps/Map008.tscn", "name":"Rough Ground"},
	{"path":"res://scenes/maps/Map009.tscn", "name":"Spiral Tower"},
	{"path":"res://scenes/maps/Map010.tscn", "name":"Tunnel Entrance"},
	{"path":"res://scenes/maps/Map011.tscn", "name":"Serpentine"},
	{"path":"res://scenes/maps/Map012.tscn", "name":"Tower Ruin"},
]
const map_mods = {
	"light":["Dawn", "Mid-day", "Dusk", "Night"],
	"effect":["Mines"]
}
const map_lights = {
	"Dawn":{
		"energy":0.25,
		"angle":-30,
		"env":"res://scenes/maps/env_dawn.tres"
	},
	"Mid-day":{
		"energy":1,
		"angle":-85,
		"env":"res://scenes/maps/env_day.tres"
	},
	"Dusk":{
		"energy":0.25,
		"angle":-150,
		"env":"res://scenes/maps/env_dusk.tres"
	},
	"Night":{
		"energy":0.02,
		"angle":-150,
		"env":"res://scenes/maps/env_night.tres"
	}
}
const tile_data = [
	{"name":"wallA", "height":2, "angle":0, "move":2},
	{"name":"wallA_window", "height":2, "angle":0, "move":2},
	{"name":"wallA_garage", "height":2, "angle":0, "move":2},
	{"name":"wallA_door", "height":2, "angle":0, "move":2},
	{"name":"wallA_roof_top", "height":1, "angle":0, "move":4},
	{"name":"wallA_roof_side", "height":0.5, "angle":30, "move":3},
	{"name":"wallA_low", "height":1, "angle":0, "move":2},
	{"name":"wallB", "height":2, "angle":0, "move":2},
	{"name":"wallB_window", "height":2, "angle":0, "move":2},
	{"name":"wallB_garage", "height":2, "angle":0, "move":2},
	{"name":"wallB_door", "height":2, "angle":0, "move":2},
	{"name":"wallB_roof_top", "height":1, "angle":0, "move":4},
	{"name":"wallB_roof_side", "height":0.5, "angle":30, "move":3},
	{"name":"road_center", "height":0, "angle":0, "move":2},
	{"name":"road_side", "height":0, "angle":0, "move":2},
	{"name":"road_corner_in", "height":0, "angle":0, "move":2},
	{"name":"road_corner_out", "height":0, "angle":0, "move":2},
	{"name":"dirt", "height":0, "angle":0, "move":3},
	{"name":"grass", "height":0, "angle":0, "move":4},
	{"name":"pavement", "height":0, "angle":0, "move":2},
	{"name":"pave_damage", "height":0, "angle":0, "move":3},
	{"name":"grass_low", "height":1, "angle":0, "move":4},
	{"name":"grass_tall", "height":2, "angle":0, "move":4},
	{"name":"dirt_low", "height":1, "angle":0, "move":3},
	{"name":"dirt_tall", "height":2, "angle":0, "move":3},
]

# Preloaded resources
const debris_obj = preload("res://Effects/Debris.tscn")
const repair_small_obj = preload("res://scenes/items/RepairSmall.tscn")
const repair_large_obj = preload("res://scenes/items/RepairLarge.tscn")
const mine_obj = preload("res://scenes/items/Mine.tscn")
const mech_obj = preload("res://scenes/mech/MechV3.tscn")
const nav_obj = preload("res://Arena/NavPoint.tscn")
const msg_obj = preload("res://ui/DialogText.tscn")
const obj_explosion = preload("res://Effects/Explosion.tscn")

# Accessor variables for child nodes
@onready var map_cam = $Camera3D

# Accessor vars for UI elements
@onready var map_info = $MapUI/TopBar/MapInfo/InfoLabel
@onready var match_info = $MapUI/TopBar/MatchInfo
@onready var team_info1 = $MapUI/TeamInfo1
@onready var team_info2 = $MapUI/TeamInfo2
@onready var mech_cam = $MapUI/TurnInfo/MechView/InnerBox/ViewBox/SubViewport/ChaseCam
@onready var unit_info = $MapUI/TurnInfo/CurrentUnit

# Arena variables:
var state : int = MapState.IDLE
var match_result : String = "normal"
var turn_count : int = 0
var is_turn_idle : bool = true
var idle_turns : int = 0
var idle_timer : float = 0.0
var turn_timeout : int = 80
var idle_timeout : int = 30
var match_start_time : int = 0
var match_end_time : int = 0
var move_speed : float = 20.0
var move_speed_fast : float = 40.0
var anim_speed : float = 1.0
var anim_speed_fast : float = 2.0
var wait_time : float = 0.25
var wait_time_fast : float = 0.0

# Map variables
var arena_map = null
var deploy_tiles = []
var nav_grid = {}
var map_props = {
	"index":0,
	"path":"",
	"name":"",
	"light":"mid",
	"effect":"none"
}

# Team variables
var team_list = []
var turns_queue = []
var winTeam = null

# UI variables
var msg_queue = []
var pilot_text : Dictionary

# Signals sent to main game
signal match_end

# main functions:
func _ready():
	# Load settings
	var config = ConfigFile.new()
	var err = config.load("settings.cfg")
	if err == OK:
		print("Config file loaded, getting map settings...")
		turn_timeout = config.get_value("map", "turn_timeout", 80)
		idle_timeout = config.get_value("map", "idle_timeout", 30)
		move_speed = config.get_value("mech", "move_speed", 20.0)
		move_speed_fast = config.get_value("mech", "move_speed_fast", 40.0)
		anim_speed = config.get_value("mech", "anim_speed", 1.0)
		anim_speed_fast = config.get_value("mech", "anim_speed_fast", 2.0)
		wait_time = config.get_value("mech", "wait_time", 0.25)
		wait_time_fast = config.get_value("mech", "wait_time_fast", 0)
	else:
		print("Error loading map config, using defaults...")
	$Debug/Vectors.camera = map_cam.cam
	if GameData.debug_mode:
		map_cam.cam_mode = map_cam.CamState.DEBUG
		$Debug/Vectors.visible = true
	else:
		map_cam.cam_mode = map_cam.CamState.NORMAL
		$Debug/Vectors.visible = false
	var file = File.new()
	# Load pilot chatter
	var data_path : String = "../data/"
	file.open(data_path + "pilot_talk.json", File.READ)
	var json = file.get_as_text()
	var test_json_conv = JSON.new()
	test_json_conv.parse(json).result
	pilot_text = test_json_conv.get_data()
	file.close()
	map_list.shuffle()

func _process(delta):
	if Input.is_action_just_pressed("ui_page_up"):
		GameData.debug_mode = !GameData.debug_mode
		if GameData.debug_mode:
			map_cam.cam_mode = map_cam.CamState.DEBUG
			$Debug/Vectors.visible = true
		else:
			map_cam.cam_mode = map_cam.CamState.NORMAL
			$Debug/Vectors.visible = false
	if Input.is_action_just_pressed("ui_home"):
		if map_cam.cam_mode == map_cam.CamState.PHOTO:
			map_cam.cam_mode = map_cam.CamState.NORMAL
		else:
			map_cam.cam_mode = map_cam.CamState.PHOTO
	match state:
		MapState.IDLE:
			pass
		MapState.INTRO:
			if map_cam.tween_done:
				nav_update()
				turns_queue.front().reset_acts()
				turns_queue.front().item_list = $Items.get_children()
				match_start_time = Time.get_unix_time_from_system()
				state = MapState.FIGHT
		MapState.FIGHT:
			if (idle_timer > idle_timeout):
				check_win()
			if turns_queue.front().turn_finished:
				next_turn()
			map_cam.follow_mech(turns_queue.front())
			idle_timer += delta
			$Markers.update_target(turns_queue.front())
			ui_update()
		MapState.OUTRO:
			if map_cam.tween_done:
				state = MapState.IDLE
				var hp_list = []
				for mech in $Mechs.get_children():
					hp_list.append({
						"body" : mech.bodyHP,
						"arm_r" : mech.armRHP,
						"arm_l" : mech.armLHP,
						"legs" : mech.legsHP
					})
				var fight_data = {
					"start" : match_start_time,
					"end" : match_end_time,
					"result" : match_result,
					"winner" : winTeam,
					"turns" : turn_count,
					"map" : map_props.name,
					"hp_data" : hp_list
				}
				emit_signal("match_end", fight_data)

#aux functions:
# Roll new map properties and return the results
func roll_map() -> Dictionary:
	map_props.index += 1
	if map_props.index >= map_list.size():
		map_props.index = 0
		map_list.shuffle()
	map_props.name = map_list[map_props.index].name
	map_props.path = map_list[map_props.index].path
	map_props.light = map_mods.light[randi() % map_mods.light.size()]
#	if randf() <= 0.3:
#		map_props.effect = "Mines"
#	else:
	map_props.effect = "Standard"
	return map_props


# Get Manhattan distance between nav points
func get_distance(from, to):
	var dist = (abs(to.grid_pos.x - from.grid_pos.x) + abs(to.grid_pos.z - from.grid_pos.z))
	return dist

# Double check if able to attack 
func check_attack(attacker, target):
	var weapon = attacker.attack_wpn
	var target_range = get_distance(attacker.curr_tile, target.curr_tile)
	if (!attacker.is_dead && is_instance_valid(target) && weapon.active):
		attacker.direction = (target.global_transform.origin - attacker.global_transform.origin)
		if (target_range >= weapon.range_min) or (target_range <= weapon.range_max):
			return true
		else:
			return false
	else:
		return false

# Create list of attacks based on given info
func roll_attack(attacker, target, weapon, to_hit):
	var atk_roll = randf()
	var dmg_mult = 1
	var hit_loc = "miss"
	var dmg_final = 0
	# Check to hit, and update attacker's hit/miss/crit stats
	# Also update attacker's dmg_out stats
	if atk_roll <= to_hit:
		if atk_roll <= to_hit * 0.1:
			dmg_mult = 2
			attacker.mechData.crit += 1
		else:
			attacker.mechData.hit += 1
		hit_loc = hit_location()
		attacker.mechData.dmg_out += weapon.damage * dmg_mult
		# Reduce damage by hit location's defense stat
		dmg_final = max(1, floor((weapon.damage * dmg_mult) - target.mechData[hit_loc].defense))
	else:
		attacker.mechData.miss += 1
	# Update target's dmg_in stat and recent attacker data
	if dmg_final > 0:
		target.mechData.dmg_in += dmg_final
		target.update_threats(attacker, dmg_final)
	return {
		"type":weapon.type,
		"target":target,
		"part":hit_loc, 
		"dmg":int(dmg_final), 
		"crit":dmg_mult,
		}

# Roll random hit location
func hit_location():
	var hitTotal = HitTable.Body + HitTable.ArmR + HitTable.ArmL + HitTable.Leg;
	var hitArmR = HitTable.Body + HitTable.ArmR;
	var hitArmL = hitArmR + HitTable.ArmL;
	# Roll hit location and deliver damage
	var loc_roll = randf() * hitTotal
	if loc_roll <= HitTable.Body:
		return "body"
	if loc_roll > HitTable.Body && loc_roll <= hitArmR:
		return "arm_r"
	if loc_roll > hitArmR && loc_roll <= hitArmL:
		return "arm_l"
	if loc_roll > hitArmL && loc_roll <= hitTotal:
		return "legs"


# Run combat between two mechs
func combat(attacker, defender):
	$MapUI/TurnInfo.hide()
	$MapUI/Attacker.show()
	$MapUI/Defender.show()
	is_turn_idle = false
	var atk_parts_lost = attacker.mechData.part_lost
	var def_parts_lost = defender.mechData.part_lost
	defender.get_counter_wpn(attacker)
	var atk_speed = skills.find(attacker.attack_wpn.skill)
	var def_speed = 999
	if defender.attack_wpn != null:
		def_speed = skills.find(defender.attack_wpn.skill)
	# Compare weapon speeds to decide who goes first
	if atk_speed <= def_speed:
		if randf() <= 0.3:
			pilot_msg(attacker, "attack")
		pick_action(attacker, defender)
		await attacker.attack_done
		attacker.mechData.part_dest += max(0, (defender.mechData.part_lost - def_parts_lost))
		if !defender.is_dead && !defender.is_stunned:
			defender.update_wpn()
			if defender.attack_wpn != null && defender.attack_wpn.active:
				pick_action(defender, attacker)
				await defender.attack_done
				defender.mechData.part_dest += max(0, (attacker.mechData.part_lost - atk_parts_lost))
				if attacker.is_dead:
					defender.mechData.kill += 1
		else:
			if defender.is_dead:
				attacker.mechData.kill += 1
	else:
		if randf() <= 0.3:
			pilot_msg(defender, "counter")
		pick_action(defender, attacker)
		await defender.attack_done
		defender.mechData.part_dest += max(0, (attacker.mechData.part_lost - atk_parts_lost))
		if !attacker.is_dead && !attacker.is_stunned:
			attacker.update_wpn()
			if attacker.attack_wpn.active:
				pick_action(attacker, defender)
				await attacker.attack_done
				attacker.mechData.part_dest += max(0, (defender.mechData.part_lost - def_parts_lost))
				if defender.is_dead:
					attacker.mechData.kill += 1
		else:
			if attacker.is_dead:
				defender.mechData.kill += 1
	attacker.in_combat = false
	await get_tree().create_timer(0.5).timeout
	$MapUI/TurnInfo.show()
	$MapUI/Attacker.hide()
	$MapUI/Defender.hide()


func pick_action(atk, def):
	if atk.attack_wpn.special != "none":
		if (randf() * 100) <= atk.mechData.pilot[atk.attack_wpn.skill]:
			atk.glow(atk.attack_wpn.spc_name)
			await atk.glow_done
			call(atk.attack_wpn.special, atk, def)
		else:
			act_attack(atk, def)
	else:
		act_attack(atk, def)

# General skills
# Standard attack
func act_attack(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			shots.append(roll_attack(attacker, target, weapon, to_hit - acc_penalty))
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Dual Wield skill
func act_dual(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			shots.append(roll_attack(attacker, target, weapon, to_hit - acc_penalty))
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Melee skills
func act_combo(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate * 2:
			shots.append(roll_attack(attacker, target, weapon, to_hit - acc_penalty))
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Kneecap skill
func act_kneecap(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			shot.effect = {"type":"stun", "duration":4}
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Skewer skill
func act_skewer(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			if shot.part != "miss":
				shot.dmg = weapon.damage
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Machine gun skills
# Mag Dump skill
func act_magdump(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack with double fire rate
		for i in weapon.fire_rate * 2:
			shots.append(roll_attack(attacker, target, weapon, to_hit - acc_penalty))
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Spray N' Pray skill
func act_spray(attacker, target):
	if check_attack(attacker, target):
		# Find enemy mechs within 2 squares
		var target_group = []
		for mech in turns_queue:
			if !mech.is_dead && mech.team != attacker.team:
				if get_distance(target.curr_tile, mech.curr_tile) <= 2 && attacker.curr_tile.get_los(mech.curr_tile):
					target_group.append(mech)
		if target_group.size() == 0:
			target_group.append(target)
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		var curr_target
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack with double fire rate, randomly selecting between targets
		for i in weapon.fire_rate * 2:
			curr_target = target_group[randi() % target_group.size()]
			target_range = get_distance(attacker.curr_tile, curr_target.curr_tile)
			acc_penalty = curr_target.dodge_total + weapon.acc_loss_h * (target_range - 1)
			shots.append(roll_attack(attacker, curr_target, weapon, to_hit - acc_penalty))
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Focus Fire skill
func act_focus(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		var hit_loc = hit_location()
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times, overriding hit location to the selected one
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			if shot.part != "miss":
				shot.part = hit_loc
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Shotgun skills
# Stunner skill
func act_stunner(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			shot.effect = {"type":"stun", "duration":4}
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Slug Shot skill
func act_slugshot(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		var hit_loc = hit_location()
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times, overriding hit location to the selected one
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			if shot.part != "miss":
				shot.part = hit_loc
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Street Sweeper skill
func act_sweeper(attacker, target):
	if check_attack(attacker, target):
		# Find enemy mechs within 2 squares
		var target_group = []
		for mech in turns_queue:
			if !mech.is_dead && mech.team != attacker.team:
				if get_distance(target.curr_tile, mech.curr_tile) <= 2:
					target_group.append(mech)
		if target_group.size() == 0:
			target_group.append(target)
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		var curr_target
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack with double fire rate, randomly selecting between targets
		for i in weapon.fire_rate * 2:
			curr_target = target_group[randi() % target_group.size()]
			target_range = get_distance(attacker.curr_tile, curr_target.curr_tile)
			acc_penalty = curr_target.dodge_total + weapon.acc_loss_h * (target_range - 1)
			shots.append(roll_attack(attacker, curr_target, weapon, to_hit - acc_penalty))
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Flamer skills
# Meltdown skill
func act_meltdown(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			shot.effect = {"type":"burn", "duration":4}
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Rifle skills
# Double Tap skill
func act_dbltap(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack with double rate of fire
		for i in weapon.fire_rate * 2:
			shots.append(roll_attack(attacker, target, weapon, to_hit - acc_penalty))
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Anti Armor skill
func act_antiarmor(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times, overriding damage to full weapon damage
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			if shot.part != "miss":
				shot.dmg = weapon.damage
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Disable skill
func act_disable(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			shot.effect = {"type":"stun", "duration":4}
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Missile skills
# Incendiary Missils skill
func act_fire(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			shot.effect = {"type":"burn", "duration":4}
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# EMP Missile skill
func act_emp(attacker, target):
	if check_attack(attacker, target):
		#attacker.update_sprite()
		var weapon = attacker.attack_wpn
		var target_range = get_distance(attacker.curr_tile, target.curr_tile)
		var shots = []
		var skill = attacker.mechData.pilot[weapon.skill]
		var to_hit = weapon.accuracy * (1 + weapon.stability) + skill/100.0
		var acc_penalty = target.dodge_total + weapon.acc_loss_h * (target_range - 1)
		if "ammo" in weapon:
			weapon.ammo -= 1
		# Attack $fire_rate times
		for i in weapon.fire_rate:
			var shot = roll_attack(attacker, target, weapon, to_hit - acc_penalty)
			shot.effect = {"type":"stun", "duration":4}
			shots.append(shot)
		attacker.do_attack(shots)
	else:
		attacker.do_attack(null)

# Update UI info
func ui_update():
	if !turns_queue.is_empty():
		var thisMech = turns_queue.front()
		for info_mini in team_info1.get_children() + team_info2.get_children():
			if info_mini.focus_mech == thisMech:
				info_mini.focus = true
			else:
				info_mini.focus = false
			info_mini.update_data()
		if $MapUI/SkillTag.visible && is_instance_valid($MapUI/SkillTag.focus_mech):
			$MapUI/SkillTag.position = map_cam.cam.unproject_position($MapUI/SkillTag.focus_mech.position + Vector3.UP)
		var debug_info = "Idle Timer: %f\n" % idle_timer
		if thisMech != null:
			if GameData.debug_mode:
				$Debug/Vectors.focus_mech = thisMech
				$Debug/Vectors.update()
				debug_info += "Pilot: " + thisMech.mechData.pilot.name + "\n"
				if (thisMech.move_target != null):
					debug_info += "move_target: " + str(thisMech.move_target) + "\n"
				if is_instance_valid(thisMech.attack_target):
					debug_info += "attack_target: " + str(thisMech.attack_target) + "\n"
				if (thisMech.attack_wpn != null):
					debug_info += "attack_wpn: " + thisMech.attack_wpn.name + "\n"
				if (!thisMech.move_path.is_empty()):
					var path_string = ""
					for tile in thisMech.move_path:
						path_string += str(tile.global_transform.origin) + "\n"
					debug_info += "move_path:\n" + path_string
				$Debug/DebugInfo.text = debug_info
			# Update current unit info
			unit_info.update_info(thisMech)
			# Update mech POV camera
			mech_cam.global_transform = thisMech.cam_point.global_transform
			mech_cam.rotation_degrees.y += 180
			$MapUI/Attacker.update_info(thisMech)
			if is_instance_valid(thisMech.attack_target):
				$MapUI/Defender.update_info(thisMech.attack_target)


func check_win():
	# Check if only one team remains
	var end_match = false
	var msg_top = "MATCH OVER"
	var msg_bot = "WINNER BY VIOLENCE"
	var teamInfo = [{"size":0, "hp":0}, {"size":0, "hp":0}]
	var allDisabled = true
	for mech in turns_queue:
		if !mech.is_dead:
			if mech.armRHP > 0 || mech.armLHP > 0:
				allDisabled = false
			if mech.team == team_list[0]:
				teamInfo[0].size += 1
				teamInfo[0].hp += mech.bodyHP
			else:
				teamInfo[1].size += 1
				teamInfo[1].hp += mech.bodyHP
	if teamInfo[0].size == 0:
		winTeam = team_list[1]
		match_result = "normal"
		$MapUI/IntroOutro.outro(msg_top, GameData.teamNames[winTeam].to_upper() + " WINS", msg_bot)
		$MapUI/AnimationPlayer.play_backwards("intro")
		map_cam.outro()
		self.state = MapState.OUTRO
		end_match = true
	elif teamInfo[1].size == 0:
		winTeam = team_list[0]
		match_result = "normal"
		$MapUI/IntroOutro.outro(msg_top, GameData.teamNames[winTeam].to_upper() + " WINS", msg_bot)
		$MapUI/AnimationPlayer.play_backwards("intro")
		map_cam.outro()
		self.state = MapState.OUTRO
		end_match = true
	# Abnormal match end: All mechs disarmed, turn timeout, idle timeout
	if allDisabled or (idle_turns > turn_timeout) or (idle_timer > idle_timeout):
		var err_msg = ""
		if allDisabled:
			err_msg = "End match: All mechs disarmed"
			GameData.write_log("stalemate," + map_props.name, "error")
			print(err_msg)
			msg_top = "STALEMATE"
			match_result = "decision"
		if (idle_turns > turn_timeout):
			err_msg = "End match: " + str(turn_timeout) + " turn timeout on " + map_props.name
			GameData.write_log("inactive," + map_props.name, "error")
			print(err_msg)
			msg_top = "TIMEOUT"
			match_result = "decision"
		if (idle_timer > idle_timeout):
			err_msg = "End match: " + str(idle_timeout) + " second timeout on " + map_props.name
			GameData.write_log("stalled," + map_props.name, "error")
			print(err_msg)
			msg_top = "STALL"
			match_result = "error"
		var winIndex = 0
		var maxSize = 0
		var maxHP = 0
		for i in teamInfo.size():
			if teamInfo[i].size > maxSize:
				winIndex = i
				maxSize = teamInfo[i].size
				maxHP = teamInfo[i].hp
			elif teamInfo[i].size == maxSize:
				if teamInfo[i].hp > maxHP:
					winIndex = i
		winTeam = team_list[winIndex]
		$MapUI/IntroOutro.outro(msg_top, GameData.teamNames[winTeam].to_upper() + " WINS", "WINNER BY DECISION")
		$MapUI/AnimationPlayer.play_backwards("intro")
		map_cam.outro()
		self.state = MapState.OUTRO
		end_match = true
	if end_match:
		match_end_time = Time.get_unix_time_from_system()
		if GameData.debug_mode:
			$Debug/Vectors.focus_mech = null
		for mech in $Mechs.get_children():
			mech.state = mech.MechState.DONE
			for part in ["body", "arm_r", "arm_l", "legs"]:
				mech.mech_parts[part].anim.stop()
		match_bonuses()
	return end_match


func match_bonuses():
	var _bonuses = [
		{"title":"Survivor", "pay":100},
		{"title":"Last Mech Standing", "pay":100},
		{"title":"Mech of Theseus", "pay":100},
		{"title":"New Champ", "pay":500}
	]
	var dmg_list = []
	var dest_list = []
	var acc_list = []
	var kill_list = []
	for mech in turns_queue:
		dmg_list.append(mech.mechData.dmg_out)
		dest_list.append(mech.mechData.part_dest)
		if mech.mechData.hit + mech.mechData.miss > 0:
			acc_list.append(float(mech.mechData.hit) / float(mech.mechData.hit + mech.mechData.miss))
		else:
			acc_list.append(0.0)
		kill_list.append(mech.mechData.kill)
		if mech.team == winTeam:
			mech.mechData.bonuses.append({"title":"Win Bonus", "pay":100})
			if mech.bodyHP > 0 and mech.legsHP == 0 and mech.armLHP == 0 and mech.armRHP == 0:
				mech.mechData.bonuses.append({"title":"TORSO!", "pay":100})
		if mech.mechData.kill >= 4:
			mech.mechData.bonuses.append({"title":"One Mech Army", "pay":100})
	if dmg_list.find(dmg_list.max()) == dmg_list.rfind(dmg_list.max()):
		turns_queue[dmg_list.find(dmg_list.max())].mechData.bonuses.append({"title":"Pain Train", "pay":100})
	if dest_list.find(dest_list.max()) == dest_list.rfind(dest_list.max()):
		turns_queue[dest_list.find(dest_list.max())].mechData.bonuses.append({"title":"Wrecker", "pay":100})
	if acc_list.find(acc_list.max()) == acc_list.rfind(acc_list.max()):
		turns_queue[acc_list.find(acc_list.max())].mechData.bonuses.append({"title":"Sharpshooter", "pay":100})
	if kill_list.find(kill_list.max()) == kill_list.rfind(kill_list.max()):
		turns_queue[kill_list.find(kill_list.max())].mechData.bonuses.append({"title":"Slayer", "pay":100})


func next_turn():
	if !check_win():
		nav_update()
		# Proc effects for all tiles
		for point in $Nav.get_children():
			point.proc_effects()
		# Proc effects for all mechs
		for mech in turns_queue:
			mech.proc_effects()
		idle_timer = 0.0
		turn_count += 1
		if is_turn_idle:
			idle_turns += 1
		else:
			idle_turns = 0
		is_turn_idle = true
		turns_queue.push_back(turns_queue.pop_front())
		while turns_queue.front().is_dead:
			turns_queue.push_back(turns_queue.pop_front())
		turns_queue.front().reset_acts()
		#print("Team " + str(turns_queue.front().team) + ", Mech: " + str(turns_queue.front().num) + " reset action")
		turns_queue.front().item_list = $Items.get_children()


func add_hype(team_index, money):
	print("GET HYPE! Added %d to %s!", [money, team_index])


func chat_msg(user_id, text):
	# Instance and move/scale dialog box at mini-info panel's position
	var target = null
	for mech in turns_queue:
		if mech.mechData.user_id == user_id:
			target = mech
	var start = false
	if msg_queue.is_empty():
		start = true
	msg_queue.push_back({"mech":target, "text":text})
	if start:
		msg_popup()


# Instance and move/scale dialog box at mini-info panel's position
func pilot_msg(mech, type):
	if state == MapState.FIGHT:
		var start = false
		if msg_queue.is_empty():
			start = true
		var msg_text = pilot_text[type][randi() % pilot_text[type].size()]
		msg_queue.push_back({"mech":mech, "text":msg_text})
		if start:
			msg_popup()


func msg_popup():
	if !msg_queue.is_empty():
		var msg_inst = msg_obj.instantiate()
		var msg_data = msg_queue.pop_front()
		$MapUI.add_child(msg_inst)
		msg_inst.connect("dialog_done", Callable(self, "msg_popup"))
		if msg_data.mech != null:
			msg_inst.set_msg(msg_data.text)
			for info_mini in team_info1.get_children() + team_info2.get_children():
				if info_mini.focus_mech == msg_data.mech:
					msg_inst.global_position = info_mini.global_position
					if info_mini.get_parent() == team_info2:
						msg_inst.global_position.x -= msg_inst.size.x
					else:
						msg_inst.global_position.x += team_info1.size.x
					msg_inst.popup(2)

func show_skill(mech, name):
	$MapUI/SkillTag.focus_mech = mech
	$MapUI/SkillTag.label.text = str(name)
	$MapUI/SkillTag.visible = true
	await get_tree().create_timer(1).timeout
	$MapUI/SkillTag.visible = false

# Remove dead mech from turn queue, then delete it
func remove_mech(mech):
	var mech_pos = mech.get_position()
	var explosion = obj_explosion.instantiate()
	self.add_child(explosion)
	explosion.position = mech_pos
	if match_info.team1_index == mech.team:
		match_info.team1_count.value -= 1
	elif match_info.team2_index == mech.team:
		match_info.team2_count.value -= 1
	mech.visible = false
	# Spawn scrap objects
	var repair_list = []
	var repair_limit = 2
	while repair_limit > 0:
		if randf() > 0.5:
			repair_list.append({"object":repair_small_obj, "value":0.1})
			repair_limit -= 1
		else:
			repair_list.append({"object":repair_large_obj, "value":0.2})
			repair_limit -= 2
		if repair_limit == 1:
			repair_list.append({"object":repair_small_obj, "value":0.1})
			repair_limit -= 1
	# Find valid tiles within Manhattan distance of 3
	var near_points = []
	for point in $Nav.get_children():
		if point.curr_mech == null:
			var dist_x = abs(mech.curr_tile.grid_pos.x - point.grid_pos.x)
			var dist_z = abs(mech.curr_tile.grid_pos.z - point.grid_pos.z)
			if (dist_x + dist_z) <= 3:
				near_points.append(point)
	# Pick tiles to fling scrap pieces to
	for repair in repair_list:
		var rand_point = near_points[randi() % near_points.size()]
		var debris_scn = debris_obj.instantiate()
		add_child(debris_scn)
		debris_scn.position = rand_point.position + Vector3.UP
		debris_scn.launch(rand_point)
		var item = spawn_item(repair.object, rand_point.position)
		item.repair_value = repair.value
		near_points.erase(rand_point)

func spawn_item(obj, pos):
	var obj_inst = obj.instantiate()
	$Items.add_child(obj_inst)
	for point in $Nav.get_children():
		if point.position == pos:
			obj_inst.curr_tile = point
			obj_inst.position = point.position
	return obj_inst

func spawn_mechs(tournament):
	for i in team_list.size():
		var thisTeam = null
		if team_list[i] == tournament.roster.size():
			thisTeam = tournament.champ.data
		else:
			thisTeam = tournament.roster[team_list[i]].data
		for j in thisTeam.size():
			var mech_inst = mech_obj.instantiate()
			$Mechs.add_child(mech_inst)
			mech_inst.connect("move_done", Callable(self, "nav_update"))
			mech_inst.connect("dead", Callable(self, "remove_mech"))
			mech_inst.connect("talk", Callable(self, "pilot_msg"))
			mech_inst.connect("run_combat", Callable(self, "combat"))
			mech_inst.connect("skill_proc", Callable(self, "show_skill"))
			mech_inst.mechData = thisTeam[j]
			mech_inst.mechData.reset_data()
			mech_inst.team = team_list[i]
			mech_inst.num = j
			if GameData.fast_combat:
				mech_inst.spd_move = move_speed_fast
				mech_inst.spd_anim = anim_speed_fast
				mech_inst.spd_wait = wait_time_fast
			else:
				mech_inst.spd_move = move_speed
				mech_inst.spd_anim = anim_speed
				mech_inst.spd_wait = wait_time
			mech_inst.global_translate(deploy_tiles[i][j])
			if map_props.light == "Night":
				mech_inst.get_node("Effects/Headlight").visible = true

func nav_update():
	var mechs = $Mechs.get_children()
	var items = $Items.get_children()
	for point in $Nav.get_children():
		point.reset_data()
		for mech in mechs:
			if !mech.is_dead:
				if (point.position - mech.position).length() < 0.1:
					point.curr_mech = mech
					mech.curr_tile = point
		for item in items:
			if (point.position - item.position).length() < 0.1:
				point.curr_item = item
				item.curr_tile = point

func clear_map():
	for point in $Nav.get_children():
		point.free()
	for mech in $Mechs.get_children():
		mech.free()
	for item in $Items.get_children():
		item.free()
	if is_instance_valid(arena_map):
		arena_map.free()

func load_map(tournament):
	# Reset arena
	match_result = "normal"
	idle_timer = 0
	# Update map props and load map object into arena
	var map_obj = load(map_props.path) 
	#var map_obj = load("res://scenes/maps/RangeTest.tscn")
	map_info.text = (msg_map_info % [map_props.name, map_props.light, map_props.effect])
	arena_map = map_obj.instantiate()
	self.add_child(arena_map)
	$Markers.hide()
	var map_min = Vector3.ZERO
	var map_max = Vector3.ZERO
	# Setup light direction and intensity
	if is_instance_valid($Map/DirectionalLight3D):
		$Map/DirectionalLight3D.light_energy = map_lights[map_props.light].energy
		$Map/DirectionalLight3D.rotation_degrees.x = map_lights[map_props.light].angle
	# Load world environment
	if is_instance_valid($Map/WorldEnvironment):
		var map_env = load(map_lights[map_props.light].env)
		$Map/WorldEnvironment.environment = map_env
	# Build list of navigation points
	var this_cell = 0
	var clear = true
	var tile_height = 0
	var nav_inst = null
	var curr_index = 0
	for coord in arena_map.tiles.get_used_cells():
		# Get mesh index of the cell and double check that it's valid
		this_cell = arena_map.tiles.get_cell_item(Vector3i(coord.x, coord.y, coord.z))
		if this_cell != -1:
			# Update min/max extents of gridmap
			map_min.x = min(map_min.x, coord.x)
			map_min.y = min(map_min.y, coord.y)
			map_min.z = min(map_min.z, coord.z)
			map_max.x = max(map_max.x, coord.x)
			map_max.y = max(map_max.y, coord.y)
			map_max.z = max(map_max.z, coord.z)
			# If the tile is 0 height, a mech can stand on it, so place a nav point
			# If it's taller than 0, check the cell above to see if it's clear
			# If the cell above is clear, place a nav point
			clear = true
			tile_height = tile_data[this_cell].height
			if tile_height > 0:
				if arena_map.tiles.get_cell_item(Vector3i(coord.x, coord.y+1, coord.z)) != -1:
					clear = false
			if clear:
				nav_inst = nav_obj.instantiate()
				$Nav.add_child(nav_inst)
				nav_inst.index = str(curr_index)
				curr_index += 1
				nav_inst.grid_pos = coord
				nav_inst.base_move = tile_data[this_cell].move
				nav_inst.move_cost = tile_data[this_cell].move
				nav_inst.position = (
					arena_map.tiles.map_to_local(Vector3i(coord.x, coord.y, coord.z)) + 
					Vector3(0, tile_height, 0))
				if map_props.effect == "Mines" && randf() <= 0.2:
					var mine_inst = mine_obj.instantiate()
					$Items.add_child(mine_inst)
					mine_inst.position = nav_inst.position
	# Now, link nav points to their neighboring nav points
	await get_tree().idle_frame
	var from = Vector3.ZERO
	var to = Vector3.ZERO
	var space_state
	var raycast
	nav_grid.clear()
	for point in $Nav.get_children():
		nav_grid[point.index] = {"tile":point, "neighbors":[]}
		for n_point in $Nav.get_children():
			var diff = n_point.position - point.position
			if (abs(diff.x) == TILE_WIDTH && diff.z == 0) || (abs(diff.z) == TILE_WIDTH && diff.x == 0):
				from = point.position + Vector3.UP
				to = n_point.position + Vector3.UP
				if diff.y < 0:
					from = point.position + Vector3(diff.x/TILE_WIDTH, 1, diff.z/TILE_WIDTH)
				elif diff.y > 0:
					to = n_point.position - Vector3(diff.x/TILE_WIDTH, 1, diff.z/TILE_WIDTH)
				space_state = get_world_3d().direct_space_state
				raycast = space_state.intersect_ray(from, to, [], 1)
				if raycast.is_empty():
					nav_grid[point.index].neighbors.append(n_point.index)
	var world_min = arena_map.tiles.map_to_local(Vector3i(map_min.x, map_min.y, map_min.z))
	var world_max = arena_map.tiles.map_to_local(Vector3i(map_max.x, map_max.y, map_max.z))
	$Debug/Vectors.map_grid = nav_grid
	map_cam.origin = 0.5 * (world_min + world_max)
	deploy_tiles.clear()
	for i in tournament.current_match.teams.size():
		deploy_tiles.append([])
	for point in arena_map.deploy_points:
		deploy_tiles[point.deploy_team].append(point.position)
	
	# Clear out mechs and spawn new ones
	turns_queue.clear()
	team_list.clear()
	for team in tournament.current_match.teams:
		team_list.append(team.index)
	team_list.shuffle()
	spawn_mechs(tournament)
	turns_queue = $Mechs.get_children()
	for mech in turns_queue:
		mech.setup(self)
	idle_turns = 0
	turn_count = 0
	nav_update()
	
	# Set up UI
	match_info.setup(tournament.tour_count, 
	tournament.current_match.name, 
	tournament.current_match.teams[0], 
	tournament.current_match.teams[1])
	var all_info = team_info1.get_children() + team_info2.get_children()
	for i in turns_queue.size():
		all_info[i].focus_mech = turns_queue[i]
	ui_update()
	map_cam.position = map_cam.origin + Vector3(0, 25, 0)
	if map_props.light == "Night":
		mech_cam.environment = load("res://scenes/maps/env_nightvision.tres")
		$MapUI/Attacker.night_mode(true)
		$MapUI/Defender.night_mode(true)
	else:
		mech_cam.environment = null
		$MapUI/Attacker.night_mode(false)
		$MapUI/Defender.night_mode(false)
	map_cam.cam.current = true
	$MapUI.visible = false

func start_match():
	$MapUI.visible = true
	$MapUI/IntroOutro.start()
	$MapUI/AnimationPlayer.play("intro")
	map_cam.intro()
	state = MapState.INTRO
