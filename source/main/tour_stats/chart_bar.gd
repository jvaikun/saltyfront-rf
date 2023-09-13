extends HBoxContainer

var val_name : String = "" : set = set_label
var val_num : int = 0 : set = set_num
var val_max : int = 0 : set = set_max


func set_label(val):
	val_name = val
	$Label.text = val_name


func set_num(val):
	val_num = val
	$Bar.value = val_num
	$Number.text = str(val_num)


func set_max(val):
	val_max = val
	$Bar.max_value = val_max


func set_color(val):
	$Bar.modulate = val

