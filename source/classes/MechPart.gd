extends Node3D

const hitspark_obj = preload("res://effects/spark_hit.tscn")
const dmgnum_obj = preload("res://effects/damage_num.tscn")
const tex_broken = preload("res://parts/tex_damage.png")

var mat_base = null
var tex_normal = null
var spark_damage


func _ready():
	var mesh_instance = $Armature/Skeleton3D.get_child(0)
	mat_base = mesh_instance.get_active_material(0)
	tex_normal = mat_base.albedo_texture
	spark_damage = find_child("Sparks")


func impact(type, damage, crit):
	var spark_inst = hitspark_obj.instantiate()
	spark_damage.add_child(spark_inst)
	var dmgnum = dmgnum_obj.instantiate()
	spark_damage.add_child(dmgnum)
	if type == "repair":
		dmgnum.label.modulate = Color(0, 1, 0, 1)
	dmgnum.label.text = str(damage)
	if crit > 1:
		dmgnum.label.modulate = Color(1, 0, 0, 1)


func set_state(state):
	match state:
		"normal":
			mat_base.albedo_texture = tex_normal
			spark_damage.emitting = false
		"critical":
			mat_base.albedo_texture = tex_normal
			spark_damage.emitting = true
		"broken":
			mat_base.albedo_texture = tex_broken
			spark_damage.emitting = true
