extends Node3D

var message = "READY" : set = set_msg


func set_msg(val):
	message = str(val)
	$SubViewport/PanelContainer/Label.text = message

