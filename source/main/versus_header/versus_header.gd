extends MarginContainer

const match_text = "Tournament %s\n%s"
const count_text = "- %d -"

@onready var lbl_match = $Panels/Countdown/Body/Match
@onready var lbl_count = $Panels/Countdown/Body/Count
@onready var lbl_map = $Panels/Countdown/Body/Map
@onready var team1 = $Panels/Team1
@onready var team2 = $Panels/Team2

signal timer_ended


func _process(_delta):
	if !$Timer.is_stopped():
		lbl_count.text = count_text % $Timer.time_left


func set_teams(first : Dictionary, second : Dictionary) -> void:
	team1.set_team(first.index, first.mechs)
	team2.set_team(second.index, second.mechs)


func start_timer(match_info, map_name, time):
	lbl_match.text = match_text % [match_info.tour, match_info.name]
	lbl_map.text = map_name
	$Timer.start(time)


func _on_timer_timeout():
	$Timer.stop()
	timer_ended.emit()

