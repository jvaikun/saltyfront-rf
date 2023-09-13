extends VBoxContainer

@onready var head = $Header
@onready var icon = $Body/Icon
@onready var info = $Body/Info


func set_info(part_name, icon_tex, info_text):
	head.text = part_name
	icon.texture = icon_tex
	info.text = info_text

