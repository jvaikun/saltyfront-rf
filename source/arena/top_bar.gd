extends HBoxContainer

const header_text = "Tournament %d\n%s"

@onready var header = $MatchInfo/Content/MatchName
@onready var team_info = [
	[$TeamInfo1/Content/TeamName, $TeamInfo1/Content/TeamCount],
	[$TeamInfo2/Content/TeamName, $TeamInfo2/Content/TeamCount],
]

var match_info : set = set_info


func set_info(val):
	match_info = val
	header.text = header_text % [match_info.tour, match_info.name]
	for i in team_info.size():
		team_info[i][0].text = match_info.teams[i].name
		team_info[i][0].modulate = match_info.teams[i].color
		team_info[i][1].value = match_info.teams[i].mechs.size()
		team_info[i][1].modulate = match_info.teams[i].color


func update_counts(count_list):
	for i in team_info.size():
		team_info[i][1].value = count_list[i]

