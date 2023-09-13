extends PanelContainer

const ICONS = {
	"melee":preload("res://ui/icons/icon_melee.png"),
	"mgun":preload("res://ui/icons/icon_mgun.png"),
	"sgun":preload("res://ui/icons/icon_sgun.png"),
	"rifle":preload("res://ui/icons/icon_rifle.png"),
	"flame":preload("res://ui/icons/icon_flame.png"),
	"missile":preload("res://ui/icons/icon_missile.png"),
	"pack":preload("res://ui/icons/icon_pack.png"),
}

# Label accessor vars
@onready var part_list = {
	"pod_l": {"label":$Stats/PartsList/PodL, "title":"LEFT SHOULDER"},
	"wpn_l": {"label":$Stats/PartsList/WeaponL, "title":"LEFT WEAPON"},
	"pack": {"label":$Stats/PartsList/Pack, "title":"BACKPACK"},
	"wpn_r": {"label":$Stats/PartsList/WeaponR, "title":"RIGHT WEAPON"},
	"pod_r": {"label":$Stats/PartsList/PodR, "title":"RIGHT SHOULDER"}
}

# Label accessor vars
@onready var p_info = $Stats/PilotInfo/PilotInfo
@onready var melee_bar = $Stats/PilotInfo/PilotData/MeleeBar
@onready var melee_num = $Stats/PilotInfo/PilotData/MeleeNum
@onready var short_bar = $Stats/PilotInfo/PilotData/ShortBar
@onready var short_num = $Stats/PilotInfo/PilotData/ShortNum
@onready var long_bar = $Stats/PilotInfo/PilotData/LongBar
@onready var long_num = $Stats/PilotInfo/PilotData/LongNum
@onready var dodge_bar = $Stats/PilotInfo/PilotData/DodgeBar
@onready var dodge_num = $Stats/PilotInfo/PilotData/DodgeNum
@onready var hp = $Stats/PilotInfo/MechData/HP
@onready var defense = $Stats/PilotInfo/MechData/Def
@onready var m_dodge = $Stats/PilotInfo/MechData/Eva

var cycle_time = 0
var mech_list = []
var focus_index = 0

signal focus_changed(index)


func set_list(mech_array):
	mech_list = mech_array
	focus_index = 0
	set_focus(mech_list[focus_index])


func set_focus(focus_mech):
	if focus_mech != null:
		p_info.set_focus(focus_mech)
		melee_bar.value = focus_mech.pilot.melee
		melee_num.text = str(focus_mech.pilot.melee)
		short_bar.value = focus_mech.pilot.short
		short_num.text = str(focus_mech.pilot.short)
		long_bar.value = focus_mech.pilot.long
		long_num.text = str(focus_mech.pilot.long)
		dodge_bar.value = focus_mech.pilot.dodge
		dodge_num.text = str(focus_mech.pilot.dodge)
		hp.text = str(focus_mech.body.hp + focus_mech.arm_r.hp + focus_mech.arm_l.hp + focus_mech.legs.hp)
		defense.text = str(round((focus_mech.body.defense + focus_mech.arm_r.defense + focus_mech.arm_l.defense + focus_mech.legs.defense)/4))
		m_dodge.text = str((focus_mech.body.dodge + focus_mech.arm_r.dodge + focus_mech.arm_l.dodge + focus_mech.legs.dodge) * 100) + "%"
		# Set up part sprites using parameters
		for part in part_list:
			var info_text = focus_mech[part].name + "\n"
			var icon = null
			if part in ["pod_l", "pod_r", "wpn_l", "wpn_r"]:
				info_text += " [%s]" % focus_mech[part].skill.to_upper()
				icon = ICONS[focus_mech[part].type]
				info_text += (str(focus_mech[part].damage) + " DMG x " + 
				str(focus_mech[part].fire_rate) + "\n")
				if focus_mech[part].spc_name != "none":
					info_text += (focus_mech[part].spc_name + 
					", " + str(focus_mech.pilot[focus_mech[part].skill]) + "%\n")
			else:
				icon = ICONS.pack
			part_list[part].label.set_info(part_list[part].title, icon, info_text)
	$Timer.start(cycle_time)


func start_timer(time):
	cycle_time = time
	$Timer.start(cycle_time)


func _on_timer_timeout():
	focus_index += 1
	if focus_index >= mech_list.size():
		focus_index = 0
	set_focus(mech_list[focus_index])
	$Timer.start(cycle_time)
	focus_changed.emit(focus_index)


func _on_hidden():
	$Timer.stop()

