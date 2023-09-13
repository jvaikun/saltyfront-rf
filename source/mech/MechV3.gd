extends CharacterBody3D

enum MechState {READY, MOVE, ACTION, DONE, WAIT}

const bullet_obj = preload("res://bullets/bullet.tscn")
const missile_obj = preload("res://bullets/missile_lg.tscn")
const part_paths = {
	"body": "res://scenes/parts/body/mech_body%s.tscn",
	"pack": "res://scenes/parts/pack/mech_pack%s.tscn",
	"arm_l": "res://scenes/parts/arml/mech_arml%s.tscn",
	"arm_r": "res://scenes/parts/armr/mech_armr%s.tscn",
	"legs": "res://scenes/parts/legs/mech_legs%s.tscn",
	"wpn_l": "res://scenes/parts/weapon/%s%s.tscn",
	"pod_l": "res://scenes/parts/pod/pod%s.tscn",
	"wpn_r": "res://scenes/parts/weapon/%s%s.tscn",
	"pod_r": "res://scenes/parts/pod/pod%s.tscn",
}
const sound_fx = {
	"bullet_hit":16,
	"bullet_miss":10,
	"explode_sm":7,
	"explode_lg":7,
}

@onready var smoke = $Effects/Smoke
@onready var mech_tag = $MechTag

signal move_done
signal attack_done
signal dead
signal talk
signal run_combat
signal skill_proc(world_pos, skill_name)
signal glow_done

@export var prop_mode = false
@export var debug_mode = false

# Speed settings
var spd_move = 10.0
var spd_anim = 1.0
var spd_wait = 0.25

# Movement variables:
var curr_tile = null
var move_tiles = []
var move_target = null
var move_path = []
# Format for map_grid entries: {index:{tile, neighbors[]}}
var map_grid = {}
# Format for nav_paths entries: {index:{root, distance}}
var nav_paths = {}
# Format for priority_list entries: [{tile, priority}]
var priority_list = []

# Attack/targeting variables
var attack_tiles = []
var attack_target = null
var attack_wpn = null
var global_range_max = 0
var global_range_min = 0
var unit_list = []
var enemies = []
var friends = []
var weapon_list = []
var item_list = []

# Turn/action variables:
var is_dead = false
var is_stunned = false
var dont_act = false
var dont_move = false
var is_thinking = false
var is_moving = false
var has_attacked = false
var in_combat = false
var turn_finished = true
var state = MechState.DONE
var nextState = MechState.DONE
var ai_weights = {
	"target_dist":1, "target_range":0.5, 
	"threat_dist":0, "threat_range":0, 
	"friend_dist":0, "repair":0
}
var timer = 0
var effects = []
var step = 0

# mech attributes:
var partData = {}
var direction = Vector3.RIGHT
var mechData = null
var move_range = 1
var jump_height = 1
var bodyHP = 5: set = set_bodyHP
var armRHP = 5: set = set_armRHP
var armLHP = 5: set = set_armLHP
var legsHP = 5: set = set_legsHP
var dodge_total = 0
var team = 0
var num = 0
var cam_point = null
var mech_parts = {
	"body": {"path":"", "obj":null, "anim":null},
	"pack": {"path":"", "obj":null, "anim":null},
	"arm_l": {"path":"", "obj":null, "anim":null},
	"arm_r": {"path":"", "obj":null, "anim":null},
	"legs": {"path":"", "obj":null, "anim":null},
	"wpn_l": {"path":"", "obj":null, "anim":null},
	"pod_l": {"path":"", "obj":null, "anim":null},
	"wpn_r": {"path":"", "obj":null, "anim":null},
	"pod_r": {"path":"", "obj":null, "anim":null},
}

# Custom sort class for sorting list vars
class CustomSort:
	# Sort by priority, descending
	static func priority(a, b):
		if a["priority"] > b["priority"]:
			return true
		return false
	# Sort by damage, descending
	static func damage(a, b):
		if a["damage"] > b["damage"]:
			return true
		return false
	# Sort by distance, ascending
	static func distance(a, b):
		if a["distance"] < b["distance"]:
			return true
		return false
	# Sort by target, descending
	static func target(a, b):
		if a["target"] > b["target"]:
			return true
		return false
	# Sort by threat, descending
	static func threat(a, b):
		if a["threat"] > b["threat"]:
			return true
		return false


func set_bodyHP(value):
	if value <= 0:
		bodyHP = 0
		if !is_dead:
			mechData.dead = 1
			emit_signal("talk", self, "death")
			emit_signal("dead", self)
			is_dead = true
			#print("Mech is dead")
	else:
		smoke.emitting = (value < mechData.body.hp / 2)
		bodyHP = value


func set_armRHP(value):
	if value <= 0:
		if armRHP > 0:
			if !prop_mode:
				play_fx("explode_sm")
			mechData.part_lost += 1
			mech_parts.arm_r.obj.set_state("broken")
		armRHP = 0
	else:
		if armRHP <= 0:
			mech_parts.arm_r.obj.set_state("normal")
		armRHP = value
	update_wpn()


func set_armLHP(value):
	if value <= 0:
		if armLHP > 0:
			if !prop_mode:
				play_fx("explode_sm")
			mechData.part_lost += 1
			mech_parts.arm_l.obj.set_state("broken")
		armLHP = 0
	else:
		if armLHP <= 0:
			mech_parts.arm_l.obj.set_state("normal")
		armLHP = value
	update_wpn()


func set_legsHP(value):
	if value <= 0:
		if legsHP > 0:
			if !prop_mode:
				play_fx("explode_sm")
			mechData.part_lost += 1
			mech_parts.legs.obj.set_state("broken")
		move_range = int(mechData.legs.move / 2)
		jump_height = max(1, int(mechData.legs.jump / 2))
		legsHP = 0
	else:
		if legsHP <= 0:
			mech_parts.legs.obj.set_state("normal")
		move_range = mechData.legs.move
		jump_height = mechData.legs.jump
		legsHP = value


# Get shortest path distance to tile
func get_distance(tile):
	var d_min = 999.0
	for n_index in map_grid[tile.index].neighbors:
		if nav_paths[n_index].distance < d_min && nav_paths[n_index].distance > 0:
			d_min = float(nav_paths[n_index].distance)
	return d_min


# Get Manhattan distance between nav points
func get_range(from, to):
	var manhattan = (abs(to.grid_pos.x - from.grid_pos.x) + abs(to.grid_pos.z - from.grid_pos.z))
	return manhattan


func _physics_process(delta):
	match state:
		MechState.READY:
			if !is_thinking:
				is_thinking = true
				think_move()
		MechState.MOVE:
			if is_moving:
				move(delta)
			else:
				for part in ["arm_r", "arm_l", "body", "legs"]:
					mech_parts[part].anim.stop()
				check_item()
				emit_signal("move_done")
				think_action()
		MechState.ACTION:
			if !has_attacked:
				has_attacked = true
				in_combat = true
				get_attack_tiles()
				await get_tree().create_timer(0.5).timeout
				for tile in attack_tiles:
					tile.can_atk = false
				emit_signal("run_combat", self, attack_target)
			elif !in_combat:
				#print("ATTACK state done")
				nextState = MechState.DONE
				state = MechState.WAIT
		MechState.DONE:
			if !turn_finished:
				for part in ["arm_r", "arm_l", "body", "legs"]:
					mech_parts[part].anim.stop()
				turn_finished = true
				#print("Team " + str(team) + ", Mech " + str(num) + " turn finished")
		MechState.WAIT:
			if timer >= spd_wait:
				timer = 0
				state = nextState
			else:
				timer += delta

func setup(my_arena):
	# Link to map's nav grid
	if my_arena != null:
		map_grid = my_arena.nav_grid
	# Build basic stats
	self.bodyHP = mechData.body.hp
	self.armRHP = mechData.arm_r.hp
	self.armLHP = mechData.arm_l.hp
	self.legsHP = mechData.legs.hp
	move_range = mechData.legs.move
	jump_height = mechData.legs.jump
	dodge_total = (mechData.body.dodge + 
	mechData.arm_r.dodge + mechData.arm_l.dodge + 
	mechData.legs.dodge + mechData.pilot.dodge / 100.0)
	
	# Clear old body parts
	for part in $Parts.get_children():
		part.queue_free()
	
	for part in mech_parts:
		if part in ["wpn_l", "wpn_r"]:
			mech_parts[part].path = part_paths[part] % [mechData[part].type, mechData[part].model]
		else:
			mech_parts[part].path = part_paths[part] % mechData[part].model
	
	var team_mat = load("res://scenes/parts/team_" + str(team) + ".material")
	
	mech_parts.legs.obj = load(mech_parts.legs.path).instantiate()
	$Parts.add_child(mech_parts.legs.obj)
	mech_parts.legs.anim = mech_parts.legs.obj.get_node("AnimationPlayer")
	
	mech_parts.body.obj = load(mech_parts.body.path).instantiate()
	mech_parts.legs.obj.get_node("Armature/Skeleton3D/Hip").add_child(mech_parts.body.obj)
	mech_parts.body.anim = mech_parts.body.obj.get_node("AnimationPlayer")
	mech_parts.body.obj.get_node("Armature/Skeleton3D/body").set_surface_override_material(1, team_mat)
	
	mech_parts.arm_l.obj = load(mech_parts.arm_l.path).instantiate()
	mech_parts.body.obj.get_node("Armature/Skeleton3D/ArmL").add_child(mech_parts.arm_l.obj)
	mech_parts.arm_l.anim = mech_parts.arm_l.obj.get_node("AnimationPlayer")
	mech_parts.arm_l.obj.get_node("Armature/Skeleton3D/arm").set_surface_override_material(1, team_mat)
	
	mech_parts.arm_r.obj = load(mech_parts.arm_r.path).instantiate()
	mech_parts.body.obj.get_node("Armature/Skeleton3D/ArmR").add_child(mech_parts.arm_r.obj)
	mech_parts.arm_r.anim = mech_parts.arm_r.obj.get_node("AnimationPlayer")
	mech_parts.arm_r.obj.get_node("Armature/Skeleton3D/arm").set_surface_override_material(1, team_mat)
	
	mech_parts.pack.obj = load(mech_parts.pack.path).instantiate()
	mech_parts.body.obj.get_node("Armature/Skeleton3D/Pack").add_child(mech_parts.pack.obj)
	
	mech_parts.wpn_l.obj = load(mech_parts.wpn_l.path).instantiate()
	mech_parts.wpn_l.obj.rotation_degrees.y = 180
	mech_parts.arm_l.obj.get_node("Armature/Skeleton3D/Hand").add_child(mech_parts.wpn_l.obj)
	
	mech_parts.wpn_r.obj = load(mech_parts.wpn_r.path).instantiate()
	mech_parts.wpn_r.obj.rotation_degrees.y = 180
	mech_parts.arm_r.obj.get_node("Armature/Skeleton3D/Hand").add_child(mech_parts.wpn_r.obj)
	
	mech_parts.pod_l.obj = load(mech_parts.pod_l.path).instantiate()
	mech_parts.arm_l.obj.get_node("Armature/Skeleton3D/Shoulder").add_child(mech_parts.pod_l.obj)
	mech_parts.pod_l.obj.position += Vector3(0, 0.15, 0)
	
	mech_parts.pod_r.obj = load(mech_parts.pod_r.path).instantiate()
	mech_parts.arm_r.obj.get_node("Armature/Skeleton3D/Shoulder").add_child(mech_parts.pod_r.obj)
	mech_parts.pod_r.obj.position += Vector3(0, 0.15, 0)
	
	# Build weapon list
	weapon_list.clear()
	global_range_max = 0
	global_range_min = 999
	if mechData.wpn_l != null:
		if mechData.wpn_l.range_max > global_range_max:
			global_range_max = mechData.wpn_l.range_max
		if mechData.wpn_l.range_min < global_range_min:
			global_range_min = mechData.wpn_l.range_min
		weapon_list.append(mechData.wpn_l.get_data())
		weapon_list.back()["stability"] = mechData.arm_l.stability
		weapon_list.back()["obj"] = mech_parts.wpn_l.obj
		weapon_list.back()["side"] = "left"
		weapon_list.back()["active"] = true
	if mechData.wpn_r != null:
		if mechData.wpn_r.range_max > global_range_max:
			global_range_max = mechData.wpn_r.range_max
		if mechData.wpn_r.range_min < global_range_min:
			global_range_min = mechData.wpn_r.range_min
		weapon_list.append(mechData.wpn_r.get_data())
		weapon_list.back()["stability"] = mechData.arm_r.stability
		weapon_list.back()["obj"] = mech_parts.wpn_r.obj
		weapon_list.back()["side"] = "right"
		weapon_list.back()["active"] = true
	if mechData.pod_l != null:
		if mechData.pod_l.range_max > global_range_max:
			global_range_max = mechData.pod_l.range_max
		if mechData.pod_l.range_min < global_range_min:
			global_range_min = mechData.pod_l.range_min
		weapon_list.append(mechData.pod_l.get_data())
		weapon_list.back()["stability"] = mechData.arm_l.stability
		weapon_list.back()["obj"] = mech_parts.pod_l.obj
		weapon_list.back()["side"] = "left"
		weapon_list.back()["active"] = true
	if mechData.pod_r != null:
		if mechData.pod_r.range_max > global_range_max:
			global_range_max = mechData.pod_r.range_max
		if mechData.pod_r.range_min < global_range_min:
			global_range_min = mechData.pod_r.range_min
		weapon_list.append(mechData.pod_r.get_data())
		weapon_list.back()["stability"] = mechData.arm_r.stability
		weapon_list.back()["obj"] = mech_parts.pod_r.obj
		weapon_list.back()["side"] = "right"
		weapon_list.back()["active"] = true
	weapon_list.sort_custom(Callable(CustomSort, "damage"))
	# Build friends and enemies lists
	if my_arena != null:
		for mech in my_arena.turns_queue:
			if mech != self:
				var info = {"mech":mech, "target":0.0, "threat":0.0, "last_attack":1.0, "last_dmg":0.0}
				if (mech.team == self.team):
					friends.append(info)
				else:
					enemies.append(info)
		unit_list = friends + enemies
	cam_point = mech_parts.body.obj.get_node("Armature/Skeleton3D/Head")
	if !prop_mode:
		$SubViewport/Tag.modulate = GameData.teamColors[team]
		$SubViewport/Label.text = str(num)
		$MechTag.show()


func reset_acts():
	if !is_dead:
		is_thinking = false
		is_moving = false
		has_attacked = false
		in_combat = false
		attack_target = null
		move_target = null
		turn_finished = false
		state = MechState.READY


# aux functions:
# Update recent damage amount of attacker
func update_threats(attacker, damage):
	for enemy in enemies:
		if enemy.mech == attacker:
			enemy.last_attack = 1
			enemy.last_dmg = damage


# Update weapon availability based on weapon ammo or arm HP
func update_wpn():
	var hp_check = 0
	global_range_max = 0
	global_range_min = 999
	for weapon in weapon_list:
		if weapon.side == "left":
			hp_check = armLHP
		else:
			hp_check = armRHP
		if hp_check > 0:
			weapon.active = true
			if "ammo" in weapon:
				weapon.active = (weapon.ammo > 0)
		else:
			weapon.active = false
		if weapon.active:
			if weapon.range_max > global_range_max:
				global_range_max = weapon.range_max
			if weapon.range_min < global_range_min:
				global_range_min = weapon.range_min

# Get tiles in attack range
func get_attack_tiles():
	# Check Manhattan distance between curr_tile and mapTiles to see if they're in range
	if attack_wpn != null:
		var this_tile = null
		for index in map_grid:
			this_tile = map_grid[index].tile
			var distance = (abs(curr_tile.grid_pos.x - this_tile.grid_pos.x) + 
			abs(curr_tile.grid_pos.z - this_tile.grid_pos.z))
			if (distance >= attack_wpn.range_min) && (distance <= attack_wpn.range_max):
				if curr_tile.get_los(this_tile):
					this_tile.can_atk = true
					attack_tiles.append(this_tile)

# Repair parts when ending turn on a wreck
func repair(percent):
	# Need to use self to force trigger the set/get function
	self.bodyHP += mechData.body.hp * percent
	self.armRHP += mechData.arm_r.hp * percent
	self.armLHP += mechData.arm_l.hp * percent
	self.legsHP += mechData.legs.hp * percent
	mech_parts.body.obj.impact("repair", "+" + str(int(percent * 100)) + "%", 1)

# Add an effect to this mech
func add_effect(new_effect):
	# Top up effect duration if already applied
	var existing = false
	for effect in effects:
		if effect.type == new_effect.type:
			existing = true
			if effect.duration < new_effect.duration:
				effect.duration = new_effect.duration
	# Add new effect if not already applied
	if !existing:
		match new_effect.type:
			"stun":
				is_stunned = true
				$Effects/Stun.visible = true
				effects.append(new_effect)
			"burn":
				$Effects/Fire.visible = true
				effects.append(new_effect)

# Check for active effects and act appropriately
func proc_effects():
	# Update count of turns since units last attacked us
	for enemy in enemies:
		enemy.last_attack += 1
	# Apply active effects and update timers
	for effect in effects:
		match effect.type:
			"stun":
				if effect.duration > 0:
					is_stunned = true
					effect.duration -= 1
				else:
					$Effects/Stun.visible = false
					is_stunned = false
					effects.erase(effect)
			"burn":
				if effect.duration > 0:
					for part in ["body", "arm_r", "arm_l", "legs"]:
						damage({"type":"fire", 
						"part":part, 
						"dmg":15, 
						"crit":1, 
						"effect":{"type":"none", "duration":0}})
					effect.duration -= 1
				else:
					$Effects/Fire.visible = false
					effects.erase(effect)


func check_item():
	for item in item_list:
		if is_instance_valid(item) && (item.position - self.position).length() < 0.1:
			if item.is_in_group("repair"):
				repair(item.repair_value)
				item.queue_free()
			if item.is_in_group("mine"):
				item.visible = true
				item.detonate(self)


# Decision making function for movement
func think_move():
	move_target = null
	is_moving = false
	# Don't do anything if stunned, dead, or move disabled
	if is_stunned || is_dead || dont_move:
		nextState = MechState.MOVE
		state = MechState.WAIT
		return
	# Calculate paths from starting point and get movement tiles
	for tile in move_tiles:
		tile.unmark()
	move_tiles.clear()
	calc_paths(curr_tile)
	var this_node = null
	var this_tile = null
	for index in nav_paths:
		this_tile = map_grid[index].tile
		this_node = nav_paths[index]
		# Tile available for standing and within move range
		if this_node.distance <= move_range && this_node.distance > 0:
			if this_tile.curr_mech == null:
				this_tile.can_move = true
				move_tiles.append(this_tile)
	# Calculate threat and target levels for other units
	var unit_dist = 0
	var max_dist = 100 
	var near_dist = move_range * 2
	for unit in unit_list:
		if !unit.mech.is_dead:
			unit_dist = get_distance(unit.mech.curr_tile)
			unit.threat = 0.0
			unit.threat += float(unit.mech.armRHP / unit.mech.mechData.arm_r.hp) * 0.5
			unit.threat += float(unit.mech.armLHP / unit.mech.mechData.arm_l.hp) * 0.5
			unit.threat += unit.threat * clamp(1 - (unit_dist / max_dist), 0, 1)
			unit.target = 0.0
			unit.target += float(unit.mech.bodyHP / unit.mech.mechData.body.hp) * 0.5
			unit.target += float(unit.mech.armRHP / unit.mech.mechData.arm_r.hp) * 0.2
			unit.target += float(unit.mech.armLHP / unit.mech.mechData.arm_l.hp) * 0.2
			unit.target += float(unit.mech.legsHP / unit.mech.mechData.legs.hp) * 0.1
			unit.target += unit.target * clamp(1 - (unit_dist / max_dist), 0, 1)
	# Main target position
	var main_target = null
	var target_near = false
	enemies.sort_custom(Callable(CustomSort, "target"))
	main_target = enemies[0].mech.curr_tile
	if is_instance_valid(main_target):
		unit_dist = get_distance(main_target)
		if unit_dist <= near_dist:
			target_near = true
	# Main threat position
	var main_threat = null
	var threat_near = false
	enemies.sort_custom(Callable(CustomSort, "threat"))
	main_threat = enemies[0].mech.curr_tile
	if is_instance_valid(main_threat):
		unit_dist = get_distance(main_threat)
		if unit_dist <= near_dist:
			threat_near = true
	# Closest friend position
	var close_friend = null
	friends.sort_custom(Callable(CustomSort, "threat"))
	close_friend = friends[0].mech.curr_tile
	# Nearest repair kit position
	var close_repair = null
	var d_min = 999
	for item in item_list:
		if item.is_in_group("repair"):
			var item_dist = get_distance(item.curr_tile)
			if item_dist < d_min:
				d_min = item_dist
				close_repair = item.curr_tile
	
	# Damage percentages
	var body_pct = float(bodyHP / mechData.body.hp)
	var armr_pct = float(armRHP / mechData.arm_r.hp)
	var arml_pct = float(armLHP / mechData.arm_l.hp)
	var legs_pct = float(legsHP / mechData.legs.hp)
	var total_pct = body_pct * 0.5 + armr_pct * 0.2 + arml_pct * 0.2 + legs_pct * 0.1
	
	if close_repair != null:
		ai_weights.repair = int(armr_pct > 0.25) * 0.5 + int(arml_pct > 0.25) * 0.5
		ai_weights.repair += (1.0 - total_pct)
	else:
		ai_weights.repair = 0.0
	
	if target_near:
		ai_weights.target_dist = 0.5
		ai_weights.target_range = 1.0
		ai_weights.friend_dist = 0.0
	else:
		ai_weights.target_dist = 1.0
		ai_weights.target_range = 0.0
		ai_weights.friend_dist = 0.5
	
	if threat_near:
		ai_weights.threat_dist = 0.0
		ai_weights.threat_range = 0.0
	else:
		ai_weights.threat_dist = 0.0
		ai_weights.threat_range = 0.0
	
	# Go through movement squares and calculate position values
	update_wpn()
	priority_list.clear()
	var priority = 0
	var goal_dist = 0
	var goal_range = 0
	var tile_value = 0
	for tile in move_tiles:
		priority = 0
		calc_paths(tile)
		if main_target != null:
			# Distance from tile to main target
			goal_dist = get_distance(main_target)
			tile_value = clamp(1 - (goal_dist / max_dist), 0, 1)
			priority += tile_value * ai_weights.target_dist
			# Can we shoot at this tile?
			if tile.get_los(main_target):
				tile_value = 0
				goal_range = get_range(tile, main_target)
				for weapon in weapon_list:
					if weapon.active and (goal_range >= weapon.range_min) and (goal_range <= weapon.range_max):
						tile_value = clamp(1 - (goal_range / weapon.range_max), 0, 1) * 0.25
				priority += tile_value * ai_weights.target_range
		if main_threat != null:
			# Distance from tile to main threat
			goal_dist = get_distance(main_threat)
			tile_value = clamp(goal_dist / max_dist, 0, 1)
			priority += tile_value * ai_weights.threat_dist
			# Can the threat shoot at this tile?
			if global_range_max != 0:
				if !tile.get_los(main_threat):
					goal_range = get_range(tile, main_threat)
					tile_value = clamp(goal_range / global_range_max, 0, 1)
					priority += tile_value * ai_weights.threat_range
		# Distance from tile to nearest repair kit
		if close_repair != null:
			if tile == close_repair:
				priority += ai_weights.repair
			else:
				goal_dist = get_distance(close_repair)
				tile_value = clamp(1 - (goal_dist / max_dist), 0, 1)
				priority += tile_value * ai_weights.repair
		# Distance to closest fighting ally
		if close_friend != null:
			goal_dist = get_distance(close_friend)
			tile_value = clamp(1 - (goal_dist / max_dist), 0, 1)
			priority += tile_value * ai_weights.friend_dist
		priority_list.append({"tile":tile, "priority":priority})
	# If priority_list isn't empty, choose a move target, default to current tile if empty
	if !priority_list.is_empty():
		# Sort priority list, get max values
		priority_list.sort_custom(Callable(CustomSort, "priority"))
		var max_list = []
		for item in priority_list:
			if item.priority == priority_list[0].priority:
				max_list.append(item)
		# Pick one of the max priority tiles, get the path to it
		if max_list.size() == 1:
			move_target = max_list[0].tile
		else:
			move_target = max_list[randi() % max_list.size()].tile
	else:
		move_target = curr_tile
	#print("READY state done")
	get_move_path()
	is_thinking = false
	if !debug_mode:
		is_moving = true
		nextState = MechState.MOVE
		state = MechState.WAIT


# Decision making function for action
func think_action():
	# Prep attack variables and update weapons
	update_wpn()
	attack_target = null
	attack_wpn = null
	# Don't do anything if stunned, dead, or act disabled
	if is_stunned || is_dead || dont_act:
		nextState = MechState.DONE
		state = MechState.WAIT
		return
	# Check Manhattan distance of enemy units,
	# and find the highest damage weapon within range
	var enemy_range = 0
	for enemy in enemies:
		if (!enemy.mech.is_dead && curr_tile.get_los(enemy.mech.curr_tile)):
			enemy_range = get_range(curr_tile, enemy.mech.curr_tile)
			for weapon in weapon_list:
				if (weapon.active && 
				enemy_range >= weapon.range_min &&
				enemy_range <= weapon.range_max):
					attack_target = enemy.mech
					attack_wpn = weapon
					break
			break
	if is_instance_valid(attack_target):
		nextState = MechState.ACTION
	else:
		nextState = MechState.DONE
	state = MechState.WAIT

# Calculate pathing from origin, where origin is a NavPoint
func calc_paths(origin):
	nav_paths.clear()
	# Reminder: for loop on Dictionaries will loop through KEYS only
	for point in map_grid:
		nav_paths[point] = {"root":null, "distance":0}
	if origin == null:
		print("Null origin tile, can't generate paths")
	else:
		# Reminder: queue is an array of index strings, the front is the frontier
		# Reminder: frontier is an index string, look up all related vars appropriately
		var queue = []
		var frontier = origin.index
		var next_dist = 0
		var front_tile = null
		var n_tile = null
		queue.push_back(frontier)
		while !queue.is_empty():
			frontier = queue.pop_front()
			#print("Frontier has " + str(frontier.neighbors.size()) + " neighbors")
			for n_index in map_grid[frontier].neighbors:
				front_tile = map_grid[frontier].tile
				n_tile = map_grid[n_index].tile
				next_dist = nav_paths[frontier].distance + n_tile.move_cost
				# not too high
				if abs(n_tile.position.y - front_tile.position.y) <= jump_height:
					if n_tile != origin:
						# not rooted yet
						if nav_paths[n_index].root == null:
							# TODO: This conditional is fucking up the distance calcs
							# Problem: Enemy mech squares are treated as impassable, and 'disconnected' from nav_paths{}
							# So, when we go to get the move distance to an enemy square, it returns 0
							# Solution: Take closest distance of neighboring squares?
							# tile available (or used by team-mate)
							if n_tile.curr_mech == null || n_tile.curr_mech.team == team || n_tile.curr_mech.is_dead:
								nav_paths[n_index].root = frontier
								nav_paths[n_index].distance = next_dist
								queue.push_back(n_index)
						# already rooted, update if distance is shorter
						elif next_dist < nav_paths[n_index].distance:
							nav_paths[n_index].root = frontier
							nav_paths[n_index].distance = next_dist
							queue.push_back(n_index)

# Get shortest path to move_target tile
func get_move_path():
	move_path.clear()
	calc_paths(curr_tile)
	if move_target != null && move_target != curr_tile:
		# Start at move_target, trace back to origin through root tiles
		var path_head = move_target.index
		while nav_paths[path_head].root != null:
			move_path.push_front(map_grid[path_head].tile)
			path_head = nav_paths[path_head].root
	else:
		move_path.push_front(curr_tile)

func move(delta):
	if !move_tiles.is_empty() && !move_path.is_empty():
		if mech_parts.legs.anim.current_animation != "walk-loop":
			mech_parts.legs.anim.play("walk-loop", -1, spd_anim, false)
			mech_parts.arm_l.anim.play("walk-loop", -1, spd_anim, false)
			mech_parts.arm_r.anim.play("walk-loop", -1, spd_anim, false)
		var from = global_transform.origin
		var to = move_path.front().global_transform.origin
		var look = to
		look.y = from.y
		direction = to - from
		if direction.length() < (spd_move * delta * 2):
			if step == 0:
				play_fx("step0")
				step = 1
			else:
				play_fx("step1")
				step = 0
			self.global_transform.origin = to
			move_path.pop_front()
		else:
			if global_transform.origin != look:
				look_at(look, Vector3.UP)
			var vel = direction.normalized() * spd_move
			if direction.y > 1.0:
				vel = Vector3.UP * spd_move
			set_velocity(vel)
			set_up_direction(Vector3.UP)
			move_and_slide()
			vel = velocity
		if move_path.is_empty():
			for tile in move_tiles:
				tile.unmark()
			move_tiles.clear()
			is_moving = false
			#print("Move finished")
	else:
		for part in ["arm_r", "arm_l", "body", "legs"]:
			mech_parts[part].anim.stop()
		for tile in move_tiles:
			tile.unmark()
		move_tiles.clear()
		is_moving = false

# Damage function
func damage(data):
	# Get current part hp values
	var part_hp = {
		"body":bodyHP,
		"arm_r":armRHP,
		"arm_l":armLHP,
		"legs":legsHP
		}
	if data.part != "miss":
		if "effect" in data:
			add_effect(data.effect)
		# If a destroyed arm/leg was hit, apply half damage to the body instead
		if data.part != "body" && part_hp[data.part] <= 0:
			data.part = "body"
			data.dmg = data.dmg/2
		mech_parts[data.part].obj.impact("hit", data.dmg, data.crit)
		match data.type:
			"melee":
				play_fx("step_mech")
			"missile":
				play_fx("explode_sm")
			"flame":
				pass
			_:
				play_fx("bullet_hit")
		match data.part:
			"body":
				self.bodyHP -= data.dmg
			"arm_r":
				self.armRHP -= data.dmg
			"arm_l":
				self.armLHP -= data.dmg
			"legs":
				self.legsHP -= data.dmg
		mechData.dmg_in += data.dmg
	else:
		mech_parts.body.obj.impact("miss", "miss", data.crit)
		if !(data.type in ["melee", "missile", "flame"]):
			play_fx("bullet_miss")

# Spawn bullet for attack
func projectile(target, object, hardpoint, speed, spread, data):
	var proj_inst = object.instantiate()
	add_child(proj_inst)
	proj_inst.global_transform.origin = hardpoint.global_transform.origin
	proj_inst.data = data
	proj_inst.set_target(target, spread)
	proj_inst.speed = speed
	return proj_inst

# Perform attack animation and deal damage to target
func do_attack(shot_list):
	if shot_list == null || !is_instance_valid(attack_target):
		await get_tree().idle_frame
		emit_signal("attack_done")
		return
	# Turn toward target
	var aim = attack_target.global_transform.origin
	aim.y = self.global_transform.origin.y
	look_at(aim, Vector3.UP)
	# Attack lead-in animation
	var anim_side = mech_parts.arm_r.anim
	if attack_wpn.side == "left":
		anim_side = mech_parts.arm_l.anim
	var point = attack_wpn.obj.get_node("Muzzle")
	if attack_wpn.type == "missile":
		mech_parts.legs.anim.play("launch_in_" + attack_wpn.side, -1, spd_anim, false)
		mech_parts.arm_r.anim.play("launch_in", -1, spd_anim, false)
		mech_parts.arm_l.anim.play("launch_in", -1, spd_anim, false)
		await mech_parts.legs.anim.animation_finished
	elif attack_wpn.type != "melee":
		mech_parts.legs.anim.play("shoot_in_" + attack_wpn.side, -1, spd_anim, false)
		mech_parts.body.anim.play("shoot_in_" + attack_wpn.side, -1, spd_anim, false)
		anim_side.play("shoot_in", -1, spd_anim, false)
		await mech_parts.legs.anim.animation_finished
	attack_wpn.obj.start_loop()
	# Attack loop
	var last_shot
	for shot in shot_list:
		var bullet
		match (attack_wpn.type):
			# If weapon is melee, spawn invisible bullet, animate
			"melee":
				mech_parts.body.anim.stop()
				anim_side.stop()
				mech_parts.body.anim.play("melee_" + attack_wpn.side, -1, spd_anim, false)
				anim_side.play("melee", -1, spd_anim, false)
				attack_wpn.obj.shoot()
				bullet = projectile(shot.target, bullet_obj, point, 20, 0, shot)
				bullet.visible = false
				await mech_parts.body.anim.animation_finished
			# If weapon is shotgun, spawn bullets all at once, animate start only
			"sgun":
				if shot_list.find(shot) == 0:
					anim_side.stop()
					anim_side.play("shoot", -1, spd_anim, false)
					attack_wpn.obj.shoot()
					await anim_side.animation_finished
				bullet = projectile(shot.target, bullet_obj, point, 20, 0.4, shot)
			# If weapon is flamer, spawn invisible bullets with pause, no animation
			"flame":
				if shot_list.find(shot) == 0:
					attack_wpn.obj.shoot()
					$Effects/Flame.global_transform.origin = point.global_transform.origin
					$Effects/Flame.look_at(attack_target.global_transform.origin + Vector3.UP, Vector3.UP)
					$Effects/Flame.emitting = true
				bullet = projectile(shot.target, bullet_obj, point, 30, 0.4, shot)
				bullet.visible = false
				await get_tree().create_timer(0.1).timeout
			"missile":
				anim_side.stop()
				anim_side.play("launch", -1, spd_anim, false)
				attack_wpn.obj.shoot()
				bullet = projectile(shot.target, missile_obj, point, 20, 0, shot)
				await anim_side.animation_finished
			"mgun":
				anim_side.stop()
				anim_side.play("shoot", -1, spd_anim * 2, false)
				attack_wpn.obj.shoot()
				bullet = projectile(shot.target, bullet_obj, point, 30, 0.6, shot)
				await anim_side.animation_finished
			"rifle":
				anim_side.stop()
				anim_side.play("shoot", -1, spd_anim, false)
				attack_wpn.obj.shoot()
				bullet = projectile(shot.target, bullet_obj, point, 30, 0.2, shot)
				await anim_side.animation_finished
		if shot_list.find(shot) == shot_list.size()-1:
			last_shot = bullet
	# Attack end animation
	attack_wpn.obj.end_loop()
	$Effects/Flame.emitting = false
	$Effects/AnimEffect.stop()
	for part in ["arm_r", "arm_l", "body", "legs"]:
		mech_parts[part].anim.stop()
	if attack_wpn.type == "missile":
		mech_parts.legs.anim.play("launch_in_" + attack_wpn.side, -1, -spd_anim, true)
		mech_parts.arm_r.anim.play("launch_in", -1, -spd_anim, true)
		mech_parts.arm_l.anim.play("launch_in", -1, -spd_anim, true)
	elif attack_wpn.type != "melee":
		mech_parts.legs.anim.play("shoot_in_" + attack_wpn.side, -1, -spd_anim, true)
		mech_parts.body.anim.play("shoot_in_" + attack_wpn.side, -1, -spd_anim, true)
		if attack_wpn.side == "right":
			mech_parts.arm_r.anim.play("shoot_in", -1, -spd_anim, true)
		else:
			mech_parts.arm_l.anim.play("shoot_in", -1, -spd_anim, true)
	if attack_wpn.type != "melee":
		if is_instance_valid(last_shot):
			await last_shot.tree_exited
		else:
			await mech_parts.legs.anim.animation_finished
	#print("Team " + str(team) + ", Mech " + str(num) + " attack done")
	emit_signal("attack_done")

func get_counter_wpn(target):
	var distance = (abs(target.curr_tile.grid_pos.x - self.curr_tile.grid_pos.x) + 
	abs(target.curr_tile.grid_pos.z - self.curr_tile.grid_pos.z))
	attack_target = target
	attack_wpn = null
	update_wpn()
	var d_max = 0
	# Can't counter if in Stun or Don't Act
	if !is_stunned && !dont_act:
		for weapon in weapon_list:
			if !("ammo" in weapon):
				if (weapon.active && 
				(distance >= weapon.range_min) && 
				(distance <= weapon.range_max)):
					if weapon.damage > d_max:
						d_max = weapon.damage
						attack_wpn = weapon


func glow(skl_name):
	play_fx("skill_activate")
	$Effects/AnimEffect.play("skill_proc")
	emit_signal("skill_proc", self, skl_name)
	await $Effects/AnimEffect.animation_finished
	emit_signal("glow_done")


# Randomly play effect in the corresponding array in the effect dictionary
func play_fx(fx_name):
	var player = AudioStreamPlayer.new()
	player.connect("finished", Callable(player, "queue_free"))
	add_child(player)
	if fx_name in sound_fx.keys():
		player.stream = $Resources.get_resource(fx_name + str(randi() % sound_fx[fx_name]))
	else:
		player.stream = $Resources.get_resource(fx_name)
	player.play()


func _on_Area_area_entered(area):
	if area.is_in_group("projectiles"):
		if area.target_mech == self:
			damage(area.data)
			if area.data.type == "missile" && area.data.part != "miss":
				for part in ["body", "arm_r", "arm_l", "legs"]:
					if area.data.part != part:
						damage({"type":"splash", 
						"part":part, 
						"dmg":int(area.data.dmg / 5.0), 
						"crit":1,
						"effect":{"type":"none", "duration":0}})
			area.queue_free()
