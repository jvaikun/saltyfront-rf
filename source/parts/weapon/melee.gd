extends Node3D

const bullet_obj = preload("res://bullets/bullet.tscn")
const speed = 20
const spread = 0

signal shot_fired
signal attack_finished

var sfx_shoot : Array
var sfx_aim : Array
var shot_list : Array
var shot_index = 0


func _ready():
	sfx_shoot = $SFXShoot.get_resource_list() as Array
	sfx_aim = $SFXAim.get_resource_list() as Array


func spawn_bullet(data):
	var bullet_inst = bullet_obj.instantiate()
	get_parent().add_child(bullet_inst)
	bullet_inst.hide()
	bullet_inst.global_transform.origin = $Muzzle.global_transform.origin
	for key in data.keys():
		bullet_inst.set(key, data[key])
	bullet_inst.data = data
	bullet_inst.set_target(data.target, spread)
	bullet_inst.speed = speed


func fire_shot():
	shot_fired.emit()
	spawn_bullet(shot_list[shot_index])
	shot_index += 1
	if shot_index >= shot_list.size():
		end_attack()


func start_attack(shot_data):
	shot_list = shot_data
	shot_index = 0
	$SoundPlayer.stream = $SFXAim.get_resource(sfx_aim.pick_random())
	$SoundPlayer.play()


func end_attack():
	$Muzzle/Flame.emitting = false
	$AnimationPlayer.stop()
	attack_finished.emit()

