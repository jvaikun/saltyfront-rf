extends Node3D

const part_script = preload("res://classes/MechPart.gd")
const spark_obj = preload("res://effects/hit_sparks.tscn")

const source_dirs = [
	"res://parts/arml/models/",
	"res://parts/armr/models/",
	"res://parts/body/models/",
	"res://parts/legs/models/",
]
const model_paths = [
	"res://parts/arml/models/mech_%s.glb",
	"res://parts/armr/models/mech_%s.glb",
	"res://parts/body/models/mech_%s.glb",
	"res://parts/legs/models/mech_%s.glb",
]
const tex_paths = [
	"res://parts/arml/textures/tex_%s.png",
	"res://parts/armr/textures/tex_%s.png",
	"res://parts/body/textures/tex_%s.png",
	"res://parts/legs/textures/tex_%s.png",
]
const out_paths = [
	"res://parts/arml/mech_%s.tscn",
	"res://parts/armr/mech_%s.tscn",
	"res://parts/body/mech_%s.tscn",
	"res://parts/legs/mech_%s.tscn",
]
const attach_bones = {
	"hand":"Hand",
	"shoulder":"Shoulder",
	"head":"Head",
	"root":"Hip",
	"arm.r":"ArmR",
	"arm.l":"ArmL",
	"pack":"Pack",
}
const spark_bones = [
	"shoulder",
	"head",
	"root",
]

var mat_mech = load("res://parts/mat_mech.material")
var mat_team = load("res://parts/mat_team.material")


# Called when the node enters the scene tree for the first time.
func _ready():
	# Go through directories and build file lists
	var file_lists = []
	for path in source_dirs:
		var dir = DirAccess.open(path)
		dir.list_dir_begin()
		var file_list = []
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".glb"):
				file_list.append(file_name.trim_prefix("mech_").trim_suffix(".glb"))
			file_name = dir.get_next()
		dir.list_dir_end()
		file_lists.append(file_list)
	# Load objects from file and save to PackedScene
	for i in source_dirs.size():
		for file in file_lists[i]:
			var load_inst = load(model_paths[i] % file).instantiate()
			add_child(load_inst)
			var skel = load_inst.get_node("Armature/Skeleton3D")
			if is_instance_valid(skel):
				# Set mesh materials to mech base material and team color
				var mesh_instance = skel.get_child(0)
				var tex_path = tex_paths[i] % file
				mat_mech.albedo_texture = load(tex_path)
				mesh_instance.set_surface_override_material(0, mat_mech.duplicate())
				if mesh_instance.get_surface_override_material_count() > 1:
					mat_team.albedo_color = Color(1, 0, 0)
					mesh_instance.set_surface_override_material(1, mat_team.duplicate())
				mesh_instance.mesh.resource_local_to_scene = true
				# Add BoneAttachment3D to Armature/Skeleton3D
				for bone in attach_bones.keys():
					if skel.find_bone(bone) >= 0:
						var attach = BoneAttachment3D.new()
						skel.add_child(attach)
						attach.owner = load_inst
						attach.name = attach_bones[bone]
						attach.bone_name = bone
						if bone in spark_bones:
							var spark_inst = spark_obj.instantiate()
							attach.add_child(spark_inst)
							spark_inst.owner = load_inst
			load_inst.set_script(part_script)
			# Save object to PackedScene file then free it
			var scene = PackedScene.new()
			var result = scene.pack(load_inst)
			if result == OK:
				var file_path = out_paths[i] % file
				var error = ResourceSaver.save(scene, file_path)
				if error != OK:
					push_error("An error occurred while saving the scene to disk.")
			load_inst.free()

