extends Node3D

const bullet_obj = preload("res://bullets/bullet.tscn")
const speed = 30
const spread = 0.4
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


func spawn_bullet(data):
	var bullet_inst = bullet_obj.instantiate()
	get_node("/root/Arena").add_child(bullet_inst)
	bullet_inst.hide()
	bullet_inst.global_transform.origin = $Muzzle.global_transform.origin
	for key in data.keys():
		bullet_inst.set(key, data[key])
	bullet_inst.set_target(data.target, spread)
	bullet_inst.speed = speed


func start_attack(shot_data):
	shot_list = shot_data
	shot_index = 0
	$SoundPlayer.stream = $SFXAim.get_resource(sfx_aim.pick_random())
	$SoundPlayer.play()
	await $SoundPlayer.finished
	$Muzzle.show()
	$Muzzle/Flame.emitting = true
	$AnimationPlayer.play("fire_glow")
	$SoundPlayer.stream = $SFXShoot.get_resource(sfx_shoot.pick_random())
	$SoundPlayer.play()
	while shot_index < shot_list.size():
		spawn_bullet(shot_list[shot_index])
		$Eject.emit_particle(
			$Eject.transform,
			$Eject.process_material.direction * $Eject.process_material.initial_velocity_min,
			$Eject.process_material.color, $Eject.process_material.color, 0)
		await get_tree().create_timer(shot_time).timeout
		shot_index += 1
	$AnimationPlayer.stop()
	$Muzzle/Flame.emitting = false
	await get_tree().create_timer($Muzzle/Flame.lifetime).timeout
	$Muzzle.hide()
	attack_finished.emit()

