extends Node3D

const anim_top = ["weld_torso0", "weld_torso1", "weld_torso2"]
const anim_side = ["weld_leg_low", "weld_leg_up", "weld_arm_low", "weld_arm_up"]

var is_horizontal = false
var active = true
var anim_in = true
var tween_pos


func _ready():
	active = true
	anim_in = true
	$Timer.start(randf())


func reset_arm():
	active = false
	$Timer.stop()
	if tween_pos is Tween:
		tween_pos.kill()
	$robot_arm/AnimationPlayer.stop()
	$robot_arm/AnimationPlayer.play("0default")
	tween_pos = create_tween()
	tween_pos.tween_property($robot_arm, "position", Vector3.ZERO, 0.25)
	tween_pos.play()


func _on_animation_player_animation_finished(anim_name):
	if active:
		if anim_in:
			anim_in = false
			$robot_arm/Armature/Skeleton3D/Wrist/Sparks.emitting = true
			await get_tree().create_timer(0.5).timeout
			$robot_arm/AnimationPlayer.play_backwards(anim_name)
		else:
			anim_in = true
			$Timer.start(randf())


func _on_timer_timeout():
	var anim = "0default"
	if is_horizontal:
		anim = anim_top[randi() % anim_top.size()]
		tween_pos = create_tween()
		tween_pos.tween_property($robot_arm, "position", Vector3(((randi() % 3) - 1) * 0.5, 0, 0), 0.5)
		tween_pos.tween_callback($robot_arm/AnimationPlayer.play.bind(anim))
		tween_pos.play()
	else:
		anim = anim_side[randi() % anim_side.size()]
		if anim in ["weld_arm_low", "weld_arm_up"]:
			if $robot_arm.position.z == 0:
				tween_pos = create_tween()
				tween_pos.tween_property($robot_arm, "position", Vector3(0, 0, -1), 0.5)
				tween_pos.tween_callback($robot_arm/AnimationPlayer.play.bind(anim))
				tween_pos.play()
		elif $robot_arm.position.z != 0:
			tween_pos = create_tween()
			tween_pos.tween_property($robot_arm, "position", Vector3.ZERO, 0.5)
			tween_pos.tween_callback($robot_arm/AnimationPlayer.play.bind(anim))
			tween_pos.play()

