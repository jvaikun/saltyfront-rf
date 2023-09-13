extends Node3D

var focus_mech = null

func hide():
	$Select.visible = false
	$Move.visible = false
	$Target.visible = false

func update_target(mech):
	focus_mech = mech
	if is_instance_valid(focus_mech):
		$Select.position = focus_mech.get_position() + Vector3(0, 0.02, 0)
		$Select.visible = true
		if is_instance_valid(focus_mech.move_target):
			$Move.position = focus_mech.move_target.get_position() + Vector3(0, 0.02, 0)
			$Move.visible = true
		else:
			$Move.visible = false
		if is_instance_valid(focus_mech.attack_target):
			$Target.position = focus_mech.attack_target.get_position() + Vector3(0, 0.02, 0)
			$Target.visible = true
		else:
			$Target.visible = false
	else:
		$Select.visible = false
		$Move.visible = false
		$Target.visible = false
