extends MarginContainer

const message_text = "Tournament #%d starting soon!"
const countdown_text = "Signup Time Left: %d"

@onready var message = $Panels/SignIn/Content/Message
@onready var countdown = $Panels/SignIn/Content/Countdown

var past_half_time = false

signal signup_ended
signal half_time_passed


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if !$Timer.is_stopped():
		countdown.text = countdown_text % $Timer.time_left
		if !past_half_time and $Timer.time_left < $Timer.wait_time * 0.5:
			past_half_time = true
			half_time_passed.emit()


func signup_start(tour_num, time):
	message.text = message_text % tour_num
	print([tour_num, time])
	$Timer.start(time)
	show()


func _on_timer_timeout():
	$Timer.stop()
	signup_ended.emit()
	hide()

