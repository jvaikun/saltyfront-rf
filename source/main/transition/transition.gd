extends Control

const msg1 = "System message 1"
const msg2 = "System message 2"
const msg3 = "System message 3"
const msg4 = "System message 4"

@onready var sub_windows = [
	$Bootup/Left/SubWindow,
	$Bootup/Left/SubWindow2,
	$Bootup/Left/SubWindow3,
	$Bootup/Right/SubWindow,
	$Bootup/Right/SubWindow2,
	$Bootup/Right/SubWindow3
]

signal bootup_finished


func _ready():
	$Bootup.hide()


func boot_up():
	$Anim.play("RESET")
	$Bootup.show()
	$Anim.play("boot_up")
	await $Anim.animation_finished
	$Bootup.hide()
	bootup_finished.emit()


func show_messages():
	for window in sub_windows:
		window.show_messages()

