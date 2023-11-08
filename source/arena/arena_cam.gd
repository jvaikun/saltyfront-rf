extends Node3D

# Constants
enum CamState {NORMAL, DEBUG, PHOTO}

const ZOOM_SPEED = 6.0
const MOVEMENT_SPEED = 6.0
const configs = [
	{ # NORMAL state
		"zoom_min":5.0, 
		"zoom_max":15.0,
		"zoom_mod":1.5,
		"arm_length":20,
		"base_pitch":-30.0,
		"base_yaw":45.0
	},
	{ # DEBUG state
		"zoom_min":20.0, 
		"zoom_max":40.0,
		"zoom_mod":1.5, 
		"arm_length":50,
		"base_pitch":-90.0,
		"base_yaw":0.0
	},
	{ # PHOTO state
		"zoom_min":1.0, 
		"zoom_max":50.0,
		"zoom_mod":1.0,
		"arm_length":20,
		"base_pitch":-30.0,
		"base_yaw":45.0
	},
]

# Accessor vars
@onready var yaw_node = $"."
@onready var pitch_node = $CamPitch
@onready var cam_node = $CamPitch/CamNode

# Camera variables
var cam_mode = CamState.NORMAL: set = set_mode
var yaw = configs[cam_mode].base_yaw: set = set_yaw
var pitch = configs[cam_mode].base_pitch: set = set_pitch
var zoom = configs[cam_mode].zoom_max: set = set_zoom
var intro_height = 25
var home_position = Vector3.ZERO
var target_mech = null


func set_mode(value):
	cam_mode = value
	match cam_mode:
		CamState.DEBUG:
			cam_node.projection = Camera3D.PROJECTION_ORTHOGONAL
		CamState.NORMAL:
			cam_node.projection = Camera3D.PROJECTION_ORTHOGONAL
		CamState.PHOTO:
			cam_node.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam_node.position = Vector3(0, 0, configs[cam_mode].arm_length)
	cam_node.size = configs[cam_mode].zoom_max
	self.yaw = configs[cam_mode].base_yaw
	self.pitch = configs[cam_mode].base_pitch


func set_yaw(value):
	yaw = value
	yaw_node.rotation_degrees.y = yaw


func set_pitch(value):
	pitch = value
	pitch_node.rotation_degrees.x = pitch


func set_zoom(value):
	var limit_length = clamp(value, configs[cam_mode].zoom_min, configs[cam_mode].zoom_max)
	if cam_mode == CamState.PHOTO:
		cam_node.position = Vector3(0, 0, limit_length)
	else:
		cam_node.size = limit_length


func _ready():
	self.cam_mode = CamState.NORMAL


func _process(delta):
	if target_mech:
		var next_pos = target_mech.position
		var next_zoom = configs[cam_mode].zoom_max
		if is_instance_valid(target_mech.attack_target):
			var distance = target_mech.attack_target.position - target_mech.position
			next_pos = target_mech.position + distance * 0.5
			next_zoom = max(configs[cam_mode].zoom_min, distance.length() * configs[cam_mode].zoom_mod)
		position = position.lerp(next_pos, MOVEMENT_SPEED * delta)
		cam_node.size = lerp(cam_node.size, next_zoom, ZOOM_SPEED * delta)

