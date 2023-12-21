extends PanelContainer

# Texture atlas constants
const FACE_WIDTH = 64
const FACE_HEIGHT = 80
const ATLAS_WIDTH = 8

@onready var team_color = $Content/Info/Status/Pilot/TeamColor
@onready var pilot_face = $Content/Info/Status/Pilot/Portrait
@onready var pilot_name = $Content/PilotName
@onready var mech_tag = $TeamNum/Tag
@onready var mech_num = $TeamNum/Number
@onready var stats = $Content/Info/Status
@onready var death = $Content/Info/Death
@onready var dmg_arml = $Content/Info/Status/MechDmg/DmgArmL
@onready var dmg_armr = $Content/Info/Status/MechDmg/DmgArmR
@onready var dmg_body = $Content/Info/Status/MechDmg/DmgBody
@onready var dmg_legs = $Content/Info/Status/MechDmg/DmgLegs

var selected : bool = false
var focus_mech : MechStats : set = set_focus


func set_focus(val):
	focus_mech = val
	update_info()


func update_info():
	if !focus_mech.is_dead and focus_mech != null:
		stats.visible = !focus_mech.is_dead
		death.visible = focus_mech.is_dead
		if !focus_mech.is_dead:
			$Highlight.visible = selected
			mech_tag.modulate = GameData.TEAM_DEFS[focus_mech.team].ui_color
			mech_num.text = str(focus_mech.num)
			var face_id = int(focus_mech.pilot.face) 
			var faceX = (face_id % ATLAS_WIDTH) * FACE_WIDTH
			var faceY = (face_id / ATLAS_WIDTH) * FACE_HEIGHT
			var faceArea = Rect2(faceX, faceY, FACE_WIDTH, FACE_HEIGHT)
			team_color.color = GameData.TEAM_DEFS[focus_mech.team].ui_color
			self_modulate = GameData.TEAM_DEFS[focus_mech.team].ui_color
			pilot_face.texture.set_region(faceArea)
			pilot_name.text = focus_mech.pilot.name
			dmg_body.modulate = get_condition(focus_mech.hp_body, focus_mech.body.hp)
			dmg_armr.modulate = get_condition(focus_mech.hp_armr, focus_mech.arm_r.hp)
			dmg_arml.modulate = get_condition(focus_mech.hp_arml, focus_mech.arm_l.hp)
			dmg_legs.modulate = get_condition(focus_mech.hp_legs, focus_mech.legs.hp)
		else:
			$Highlight.visible = false
	else:
		stats.visible = false
		death.visible = true
		$Highlight.visible = false


func get_condition(hp, max_hp):
	if hp > 0:
		var percent = float(hp / max_hp)
		if percent >= 0.5:
			return Color(0, 1, 0)
		elif percent >= 0.25:
			return Color(1, 1, 0)
		else:
			return Color(1, 0, 0)
	else:
		return Color(0.5, 0.5, 0.5)

