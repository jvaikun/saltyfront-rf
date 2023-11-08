extends Node3D

@onready var label = $Label3D

var text = "" : set = set_text


func set_text(val):
	text = str(val)
	label.text = text


func _ready():
	var goal = position
	goal.x += (randi() % 5 - 2) * 0.3
	goal.y += (randi() % 5 - 2) * 0.1
	goal.z += (randi() % 5 - 2) * 0.3
	var move_tween = create_tween()
	move_tween.finished.connect(queue_free)
	move_tween.set_trans(Tween.TRANS_ELASTIC)
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "position", goal, 0.5)
	move_tween.play()

