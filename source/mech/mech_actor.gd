extends CharacterBody3D

enum MechState {READY, MOVE, ACTION, DONE, WAIT}

const part_paths = {
	"body": "res://parts/body/mech_body%s.tscn",
	"pack": "res://parts/pack/mech_pack%s.tscn",
	"arm_l": "res://parts/arml/mech_arml%s.tscn",
	"arm_r": "res://parts/armr/mech_armr%s.tscn",
	"legs": "res://parts/legs/mech_legs%s.tscn",
	"wpn_l": "res://parts/weapon/%s%s.tscn",
	"pod_l": "res://parts/pod/pod%s.tscn",
	"wpn_r": "res://parts/weapon/%s%s.tscn",
	"pod_r": "res://parts/pod/pod%s.tscn",
}
const sound_fx = {
	"bullet_hit":16,
	"bullet_miss":10,
	"explode_sm":7,
	"explode_lg":7,
}

@onready var fx_smoke = $Effects/Smoke
@onready var fx_fire = $Effects/Fire
@onready var anim_fx = $Effects/AnimEffect

@export var prop_mode : bool = false
@export var debug_mode : bool = false

var global_range_max = 0
var global_range_min = 0
var weapon_list = []
var anim_speed = 1

var state = MechState.DONE
var is_dead = false
var part_data = {}
var direction = Vector3.RIGHT
var mech_data = null
var move_range = 1
var jump_height = 1
var bodyHP = 5 : set = set_bodyHP
var armRHP = 5 : set = set_armRHP
var armLHP = 5 : set = set_armLHP
var legsHP = 5 : set = set_legsHP
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


# custom_sort functions
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


# Setter functions
func set_bodyHP(value):
	if value <= 0:
		bodyHP = 0
		if !is_dead:
			mech_data.dead = 1
			emit_signal("talk", self, "death")
			emit_signal("dead", self)
			is_dead = true
			#print("Mech is dead")
	else:
		fx_smoke.emitting = (value < mech_data.body.hp / 2)
		bodyHP = value


func set_armRHP(value):
	if value <= 0:
		if armRHP > 0:
			if !prop_mode:
				play_sfx("explode_sm")
			mech_data.part_lost += 1
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
				play_sfx("explode_sm")
			mech_data.part_lost += 1
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
				play_sfx("explode_sm")
			mech_data.part_lost += 1
			mech_parts.legs.obj.set_state("broken")
		move_range = int(mech_data.legs.move / 2)
		jump_height = max(1, int(mech_data.legs.jump / 2))
		legsHP = 0
	else:
		if legsHP <= 0:
			mech_parts.legs.obj.set_state("normal")
		move_range = mech_data.legs.move
		jump_height = mech_data.legs.jump
		legsHP = value


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func anim_walk(toggle : bool = true):
	if toggle:
		if mech_parts.legs.anim.current_animation != "walk-loop":
			mech_parts.legs.anim.play("walk", -1, anim_speed, false)
			mech_parts.arm_l.anim.play("walk", -1, anim_speed, false)
			mech_parts.arm_r.anim.play("walk", -1, anim_speed, false)
	else:
		mech_parts.legs.anim.stop()
		mech_parts.arm_l.anim.stop()
		mech_parts.arm_r.anim.stop()


func setup_mech():
	# Link to map's nav grid
	# Mech needs to talk to Arena object to get map/nav data
	# Build basic stats
	self.bodyHP = mech_data.body.hp
	self.armRHP = mech_data.arm_r.hp
	self.armLHP = mech_data.arm_l.hp
	self.legsHP = mech_data.legs.hp
	move_range = mech_data.legs.move
	jump_height = mech_data.legs.jump
	dodge_total = (mech_data.body.dodge + 
	mech_data.arm_r.dodge + mech_data.arm_l.dodge + 
	mech_data.legs.dodge + mech_data.pilot.dodge / 100.0)
	
	# Clear old body parts
	for part in $Parts.get_children():
		part.queue_free()
	
	for part in mech_parts:
		if part in ["wpn_l", "wpn_r"]:
			mech_parts[part].path = part_paths[part] % [mech_data[part].type, mech_data[part].model]
		else:
			mech_parts[part].path = part_paths[part] % mech_data[part].model
	
	var team_color = GameData.TEAM_DEFS[team].mech_color
	
	mech_parts.legs.obj = load(mech_parts.legs.path).instantiate()
	$Parts.add_child(mech_parts.legs.obj)
	mech_parts.legs.anim = mech_parts.legs.obj.get_node("AnimationPlayer")
	
	mech_parts.body.obj = load(mech_parts.body.path).instantiate()
	mech_parts.legs.obj.get_node("Armature/Skeleton3D/Hip").add_child(mech_parts.body.obj)
	mech_parts.body.anim = mech_parts.body.obj.get_node("AnimationPlayer")
	mech_parts.body.obj.get_node("Armature/Skeleton3D/body").get_active_material(1).albedo_color = team_color
	
	mech_parts.arm_l.obj = load(mech_parts.arm_l.path).instantiate()
	mech_parts.body.obj.get_node("Armature/Skeleton3D/ArmL").add_child(mech_parts.arm_l.obj)
	mech_parts.arm_l.anim = mech_parts.arm_l.obj.get_node("AnimationPlayer")
	mech_parts.arm_l.obj.get_node("Armature/Skeleton3D/arm").get_active_material(1).albedo_color = team_color
	
	mech_parts.arm_r.obj = load(mech_parts.arm_r.path).instantiate()
	mech_parts.body.obj.get_node("Armature/Skeleton3D/ArmR").add_child(mech_parts.arm_r.obj)
	mech_parts.arm_r.anim = mech_parts.arm_r.obj.get_node("AnimationPlayer")
	mech_parts.arm_r.obj.get_node("Armature/Skeleton3D/arm").get_active_material(1).albedo_color = team_color
	
	mech_parts.pack.obj = load(mech_parts.pack.path).instantiate()
	mech_parts.body.obj.get_node("Armature/Skeleton3D/Pack").add_child(mech_parts.pack.obj)
	mech_parts.pack.obj.rotation_degrees.y = 180
	
	mech_parts.wpn_l.obj = load(mech_parts.wpn_l.path).instantiate()
	mech_parts.arm_l.obj.get_node("Armature/Skeleton3D/Hand").add_child(mech_parts.wpn_l.obj)
	mech_parts.wpn_l.obj.rotation_degrees.y = 180
	
	mech_parts.wpn_r.obj = load(mech_parts.wpn_r.path).instantiate()
	mech_parts.arm_r.obj.get_node("Armature/Skeleton3D/Hand").add_child(mech_parts.wpn_r.obj)
	mech_parts.wpn_r.obj.rotation_degrees.y = 180
	
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
	if mech_data.wpn_l != null:
		if mech_data.wpn_l.range_max > global_range_max:
			global_range_max = mech_data.wpn_l.range_max
		if mech_data.wpn_l.range_min < global_range_min:
			global_range_min = mech_data.wpn_l.range_min
		weapon_list.append(mech_data.wpn_l.get_data())
		weapon_list.back()["stability"] = mech_data.arm_l.stability
		weapon_list.back()["obj"] = mech_parts.wpn_l.obj
		weapon_list.back()["side"] = "left"
		weapon_list.back()["active"] = true
	if mech_data.wpn_r != null:
		if mech_data.wpn_r.range_max > global_range_max:
			global_range_max = mech_data.wpn_r.range_max
		if mech_data.wpn_r.range_min < global_range_min:
			global_range_min = mech_data.wpn_r.range_min
		weapon_list.append(mech_data.wpn_r.get_data())
		weapon_list.back()["stability"] = mech_data.arm_r.stability
		weapon_list.back()["obj"] = mech_parts.wpn_r.obj
		weapon_list.back()["side"] = "right"
		weapon_list.back()["active"] = true
	if mech_data.pod_l != null:
		if mech_data.pod_l.range_max > global_range_max:
			global_range_max = mech_data.pod_l.range_max
		if mech_data.pod_l.range_min < global_range_min:
			global_range_min = mech_data.pod_l.range_min
		weapon_list.append(mech_data.pod_l.get_data())
		weapon_list.back()["stability"] = mech_data.arm_l.stability
		weapon_list.back()["obj"] = mech_parts.pod_l.obj
		weapon_list.back()["side"] = "left"
		weapon_list.back()["active"] = true
	if mech_data.pod_r != null:
		if mech_data.pod_r.range_max > global_range_max:
			global_range_max = mech_data.pod_r.range_max
		if mech_data.pod_r.range_min < global_range_min:
			global_range_min = mech_data.pod_r.range_min
		weapon_list.append(mech_data.pod_r.get_data())
		weapon_list.back()["stability"] = mech_data.arm_r.stability
		weapon_list.back()["obj"] = mech_parts.pod_r.obj
		weapon_list.back()["side"] = "right"
		weapon_list.back()["active"] = true
	weapon_list.sort_custom(damage)
	# Build friends and enemies lists
#	if my_arena != null:
#		for mech in my_arena.turns_queue:
#			if mech != self:
#				var info = {"mech":mech, "target":0.0, "threat":0.0, "last_attack":1.0, "last_dmg":0.0}
#				if (mech.team == self.team):
#					friends.append(info)
#				else:
#					enemies.append(info)
#		unit_list = friends + enemies
	cam_point = mech_parts.body.obj.get_node("Armature/Skeleton3D/Head")
	if !prop_mode:
		$MechTag/SubViewport/Tag.modulate = GameData.TEAM_DEFS[team].ui_color
		$MechTag/SubViewport/Label.text = str(num)
		$MechTag.show()


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


# Randomly play effect in the corresponding array in the effect dictionary
func play_sfx(sfx_name):
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(queue_free)
	if sfx_name in sound_fx.keys():
		player.stream = $Resources.get_resource(sfx_name + str(randi() % sound_fx[sfx_name]))
	else:
		player.stream = $Resources.get_resource(sfx_name)
	player.play()
