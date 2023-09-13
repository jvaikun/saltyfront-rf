extends Area3D

const obj_spark = preload("res://effects/hit_sparks.tscn")

var speed = 30
var target_mech = null
var adjust = Vector3.ZERO
var direction = Vector3.ZERO
var data = null

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("projectiles")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var velocity = direction.normalized() * delta * speed
	global_translate(velocity)


func set_target(target, spread):
	target_mech = target
	adjust = Vector3(
		randf() * spread * 2 - spread,
		randf() * spread * 2 - spread + 1.0,
		randf() * spread * 2 - spread
	)
	direction = target_mech.global_transform.origin + adjust - self.global_transform.origin
	look_at(target_mech.global_transform.origin + adjust, Vector3.UP)


func _on_Bullet_tree_exiting():
	var inst_spark = obj_spark.instantiate()
	get_parent().add_child(inst_spark)
	inst_spark.global_transform.origin = global_transform.origin
