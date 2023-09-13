extends Node3D

# Texture atlas constants
const FACE_WIDTH = 64
const FACE_HEIGHT = 80
const ATLAS_WIDTH = 8

@onready var p_color = $SubViewport/Panel/Content/Color
@onready var p_pilot = $SubViewport/Panel/Content/Color/Pilot
@onready var p_name = $SubViewport/Panel/Content/Name


func update_sign(mech):
	if mech != null:
		var face_id = int(mech.pilot.face) 
		var faceX = (face_id % ATLAS_WIDTH) * FACE_WIDTH
		var faceY = (face_id / ATLAS_WIDTH) * FACE_HEIGHT
		var face_rect = Rect2(faceX, faceY, FACE_WIDTH, FACE_HEIGHT)
		p_color.color = GameData.TEAM_DEFS[mech.team].ui_color
		p_pilot.texture.region = face_rect
		p_name.text = mech.pilot.name

