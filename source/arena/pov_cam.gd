extends PanelContainer

# Texture atlas constants
const FACE_WIDTH = 64
const FACE_HEIGHT = 80
const ATLAS_WIDTH = 8
const info_text = "%s\n%s %d"

@onready var pilot_face = $Overlay/PilotInfo/Content/Portrait
@onready var pilot_name = $Overlay/PilotInfo/Content/PilotName
@onready var attack_icon = $Overlay/AttackInfo/Content/Icon
@onready var attack_info = $Overlay/AttackInfo/Content/Label
@onready var body_bar = $Overlay/UnitInfo/Content/Info/HPInfo/BodyBar
@onready var body_num = $Overlay/UnitInfo/Content/Info/HPInfo/BodyNum
@onready var arml_bar = $Overlay/UnitInfo/Content/Info/HPInfo/ArmLBar
@onready var arml_num = $Overlay/UnitInfo/Content/Info/HPInfo/ArmLNum
@onready var armr_bar = $Overlay/UnitInfo/Content/Info/HPInfo/ArmRBar
@onready var armr_num = $Overlay/UnitInfo/Content/Info/HPInfo/ArmRNum
@onready var legs_bar = $Overlay/UnitInfo/Content/Info/HPInfo/LegsBar
@onready var legs_num = $Overlay/UnitInfo/Content/Info/HPInfo/LegsNum

var focus_mech : MechStats : set = set_focus


func set_focus(val):
	focus_mech = val
	update_info()


func update_info():
	if !focus_mech.is_dead and focus_mech != null:
		var face_id = int(focus_mech.pilot.face) 
		var face_x = (face_id % ATLAS_WIDTH) * FACE_WIDTH
		var face_y = (face_id / ATLAS_WIDTH) * FACE_HEIGHT
		var face_area = Rect2(face_x, face_y, FACE_WIDTH, FACE_HEIGHT)
		pilot_face.texture.set_region(face_area)
		pilot_name.text = info_text % [
			focus_mech.pilot.name,
			GameData.TEAM_DEFS[focus_mech.team].name,
			focus_mech.num]
		body_num.text = str(focus_mech.hp_body)
		body_bar.max_value = focus_mech.body.hp
		body_bar.value = focus_mech.hp_body
		arml_num.text = str(focus_mech.hp_arml)
		arml_bar.max_value = focus_mech.body.hp
		arml_bar.value = focus_mech.hp_body
		armr_num.text = str(focus_mech.hp_armr)
		armr_bar.max_value = focus_mech.body.hp
		armr_bar.value = focus_mech.hp_body
		legs_num.text = str(focus_mech.hp_legs)
		legs_bar.max_value = focus_mech.body.hp
		legs_bar.value = focus_mech.hp_body

