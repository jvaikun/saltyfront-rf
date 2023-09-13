extends PanelContainer

@onready var notes = $Body/Notes
var team_index = null


func set_team(team_num: int, team: Array):
	if !team.is_empty() && team_num >= 0:
		team_index = team_num
		$Lose.visible = false
		$Body/Header.modulate = GameData.TEAM_DEFS[team_num].ui_color
		$Body/Header.text = GameData.TEAM_DEFS[team_num].name.capitalize()
		$Body/PilotList/PilotInfo.set_focus(team[0])
		$Body/PilotList/PilotInfo2.set_focus(team[1])
		$Body/PilotList/PilotInfo3.set_focus(team[2])
		$Body/PilotList/PilotInfo4.set_focus(team[3])
	else:
		team_index = 8
		$Lose.visible = false
		$Body/Header.modulate = Color(1,1,1)
		$Body/Header.text = "Unknown"
		$Body/PilotList/PilotInfo.set_focus(null)
		$Body/PilotList/PilotInfo2.set_focus(null)
		$Body/PilotList/PilotInfo3.set_focus(null)
		$Body/PilotList/PilotInfo4.set_focus(null)


func set_loss(lost: bool):
	$Lose.visible = lost

