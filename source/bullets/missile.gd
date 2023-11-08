extends Area3D

var speed = 10
var target = null
var adjust = Vector3.ZERO
var direction = Vector3.ZERO
var part = "body"
var type = "missile"
var damage = 0
var multiplier = 1
var effect_type = "none"
var effect_duration = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("projectiles")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var velocity = direction.normalized() * delta * speed
	global_translate(velocity)


func set_target(target_mech, spread):
	target = target_mech
	adjust = Vector3(
		randf() * spread * 2 - spread,
		randf() * spread * 2 - spread + 1.0,
		randf() * spread * 2 - spread
	)
	direction = target.global_transform.origin + adjust - self.global_transform.origin
	look_at(target.global_transform.origin + adjust, Vector3.UP)


func destroy():
	speed = 0
	$Light3D.hide()
	$Mesh.hide()
	$SmokeTrail.emitting = false
	await get_tree().create_timer(1.0).timeout
	queue_free()

