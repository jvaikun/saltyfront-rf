extends Node3D

const bullet_obj = preload("res://bullets/bullet.tscn")
const speed = 30
const spread = 0.6
const shot_time = 0.1

signal shot_fired
signal attack_finished

var sfx_shoot : Array
var sfx_aim : Array


func _ready():
	sfx_shoot = $SFXShoot.get_resource_list() as Array
	sfx_aim = $SFXAim.get_resource_list() as Array


func spawn_bullet(data):
	var bullet_inst = bullet_obj.instantiate()
	get_node("/root/Arena").add_child(bullet_inst)
	bullet_inst.global_transform.origin = $Muzzle.global_transform.origin
	for key in data.keys():
		bullet_inst.set(key, data[key])
	bullet_inst.set_target(data.target, spread)
	bullet_inst.speed = speed


func start_attack(shot_list):
	$SoundPlayer.stream = $SFXAim.get_resource(sfx_aim.pick_random())
	$SoundPlayer.play()
	await $SoundPlayer.finished
	for shot in shot_list:
		shot_fired.emit()
		muzzle_flash()
		spawn_bullet(shot)
		$SoundPlayer.stream = $SFXShoot.get_resource(sfx_shoot.pick_random())
		$SoundPlayer.play()
		await get_tree().create_timer(shot_time).timeout
		#xform: Transform3D, velocity: Vector3, color: Color, custom: Color, flags: int
		$Eject.emit_particle(
			$Eject.transform,
			$Eject.process_material.direction * $Eject.process_material.initial_velocity_min,
			$Eject.process_material.color, $Eject.process_material.color, 0)
	$Muzzle.hide()
	attack_finished.emit()


func muzzle_flash():
	var flash_scale = 0.8 + (randi() % 4 * 0.2)
	$Muzzle.scale = Vector3(flash_scale, flash_scale, 1)
	$Muzzle.show()
	await get_tree().create_timer(0.05).timeout
	$Muzzle.hide()

