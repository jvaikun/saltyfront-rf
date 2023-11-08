extends Node3D

const bullet_obj = preload("res://bullets/bullet.tscn")
const speed = 20
const spread = 0
const shot_time = 0.2

signal shot_fired
signal attack_finished

var sfx_shoot : Array
var sfx_aim : Array
var shot_list : Array
var shot_index = 0


func _ready():
	sfx_shoot = $SFXShoot.get_resource_list() as Array
	sfx_aim = $SFXAim.get_resource_list() as Array


func attack(data):
	var bullet_inst = bullet_obj.instantiate()
	get_node("/root/Arena").add_child(bullet_inst)
	bullet_inst.hide()
	bullet_inst.global_transform.origin = $Muzzle.global_transform.origin
	for key in data.keys():
		bullet_inst.set(key, data[key])
	bullet_inst.set_target(data.target, spread)
	bullet_inst.speed = speed

