extends Control

const CONNECTION_TEXT = "Nick: %s\nClient: %s\nChannel: %s\nAuth: %s"

@onready var settings = {
	$Main/Buttons/FastWait: ["game", "fast_wait"],
	$Main/Settings/Tabs/Game/SignupNorm: ["game", "signup_time"],
	$Main/Settings/Tabs/Game/SignupFast: ["game", "signup_time_fast"], 
	$Main/Settings/Tabs/Game/BettingNorm: ["game", "bet_time"], 
	$Main/Settings/Tabs/Game/BettingFast: ["game", "bet_time_fast"], 
	$Main/Settings/Tabs/Game/PayoutNorm: ["game", "pay_time"], 
	$Main/Settings/Tabs/Game/PayoutFast: ["game", "pay_time_fast"], 
	$Main/Settings/Tabs/Game/RosterNorm: ["game", "bracket_time"],
	$Main/Settings/Tabs/Game/RosterFast: ["game", "bracket_time_fast"],
	$Main/Settings/Tabs/Game/MechNorm: ["game", "focus_time"],
	$Main/Settings/Tabs/Game/MechFast: ["game", "focus_time_fast"],
	$Main/Settings/Tabs/Connection/ConnectList: ["connection", "stream"],
	$Main/Buttons/Offline: ["connection", "offline_mode"],
	$Main/Buttons/FastCombat: ["combat", "fast_combat"],
	$Main/Settings/Tabs/Combat/MoveNorm: ["combat", "move_speed"], 
	$Main/Settings/Tabs/Combat/MoveFast: ["combat", "move_speed_fast"], 
	$Main/Settings/Tabs/Combat/AnimNorm: ["combat", "anim_speed"], 
	$Main/Settings/Tabs/Combat/AnimFast: ["combat", "anim_speed_fast"], 
	$Main/Settings/Tabs/Combat/WaitNorm: ["combat", "act_wait"], 
	$Main/Settings/Tabs/Combat/WaitFast: ["combat", "act_wait_fast"], 
	$Main/Settings/Tabs/Combat/TimeOutTurns: ["combat", "turn_timeout"], 
	$Main/Settings/Tabs/Combat/TimeOutSecs: ["combat", "idle_timeout"],
	$Main/Settings/Tabs/Paths/DataPath: ["paths", "data"], 
	$Main/Settings/Tabs/Paths/PartPath: ["paths", "parts"], 
	$Main/Settings/Tabs/Paths/UserPath: ["paths", "user"], 
	$Main/Settings/Tabs/Paths/MusicPath: ["paths", "bgm"], 
	$Main/Settings/Tabs/Paths/RecordPath: ["paths", "recs"],
	$Main/Settings/Tabs/Paths/ShotPath: ["paths", "screen"],
}

var game_config = ConfigFile.new()


func _ready():
	
	# Check for config file and display settings
	var err = game_config.load("settings.cfg")
	if err == OK:
		for channel in GameData.streams:
			$Main/Settings/Tabs/Connection/ConnectList.add_item(channel)
		for item in settings:
			var info = settings[item]
			if item is LineEdit:
				item.text = str(game_config.get_value(info[0], info[1]))
			if item is OptionButton:
				item.selected = 0
			if item is CheckButton:
				item.button_pressed = game_config.get_value(info[0], info[1])
	else:
		print("Error loading game config!")


func update_settings():
	for item in settings:
		var info = settings[item]
		if item is LineEdit:
			game_config.set_value(info[0], info[1], float(item.text))
		if item is OptionButton:
			game_config.set_value(info[0], info[1], item.get_item_text(item.selected))
		if item is CheckButton:
			game_config.set_value(info[0], info[1], item.pressed)
	game_config.save("settings.cfg")


func _on_connect_list_item_selected(index):
	var channel = $Main/Settings/Tabs/Connection/ConnectList.get_item_text(index)
	$Main/Settings/Tabs/Connection/ConnectInfo.text = CONNECTION_TEXT % GameData.streams[channel].values()


func _on_offline_toggled(button_pressed):
	game_config.set_value("connection", "offline_mode", button_pressed)
	$Main/Settings/Tabs/Connection/ConnectList.disabled = button_pressed


func _on_fast_wait_toggled(button_pressed):
	game_config.set_value("game", "fast_wait", button_pressed)


func _on_fast_combat_toggled(button_pressed):
	game_config.set_value("combat", "fast_combat", button_pressed)


func _on_btn_normal_pressed():
	var select_index = $Main/Settings/Tabs/Connection/ConnectList.selected
	var channel = $Main/Settings/Tabs/Connection/ConnectList.get_item_text(select_index)
	ChatBot.set_channel(channel)
	var err = get_tree().change_scene_to_file("res://main/main.tscn")
	if err != OK:
		print("Error loading main game!")


func _on_btn_sim_pressed():
	pass # Replace with function body.


func _on_btn_quit_pressed():
	get_tree().quit()

