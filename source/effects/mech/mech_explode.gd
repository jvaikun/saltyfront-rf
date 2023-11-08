extends Node3D


func _ready():
	var sounds = $Sounds.get_resource_list() as Array
	$SoundPlayer.stream = $Sounds.get_resource(sounds.pick_random())
	$SoundPlayer.play()
	$Anims.play("explode")
	await get_tree().create_timer(1.5).timeout
	queue_free()

