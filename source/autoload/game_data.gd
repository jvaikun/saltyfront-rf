extends Node

# Team constants
const TEAM_DEFS = [
	{ "name":"red", "ui_color":Color(1, 0, 0), "mech_color":Color(1, 0, 0) },
	{ "name":"blue", "ui_color":Color(0, 0, 1), "mech_color":Color(0, 0, 1) },
	{ "name":"green", "ui_color":Color(0, 0.75, 0), "mech_color":Color(0, 0.75, 0) },
	{ "name":"yellow", "ui_color":Color(1, 1, 0), "mech_color":Color(1, 1, 0) },
	{ "name":"white", "ui_color":Color(1, 1, 1), "mech_color":Color(0.9, 0.9, 0.9) },
	{ "name":"black", "ui_color":Color(0.3, 0.3, 0.3), "mech_color":Color(0.2, 0.2, 0.2) },
	{ "name":"purple", "ui_color":Color(0.5, 0, 0.5), "mech_color":Color(0.5, 0, 0.5) },
	{ "name":"brown", "ui_color":Color(0.65, 0.15, 0.15), "mech_color":Color(0.65, 0.15, 0.15) },
	{ "name":"champion", "ui_color":Color(1, 0.75, 0), "mech_color":Color(1, 0.5, 0) },
]

# File system variables
var file
var rec_path = "../data/records/"
var screenshot_path = "../sshot"
var screenshot_count = 0
var streams : Dictionary

# Game variables
var debug_mode = false
var offline_mode = true
var fast_wait = true
var fast_combat = false
var focus_time = 4
var prep_time = 60
var prep_time_fast = 15
var pay_time = 30
var pay_time_fast = 15
var bet_time = 60
var bet_time_fast = 15
var bracket_time = 5
var turn_timeout : int = 80
var idle_timeout : int = 30
var match_start_time : int = 0
var match_end_time : int = 0
var move_speed : float = 20.0
var move_speed_fast : float = 40.0
var anim_speed : float = 1.0
var anim_speed_fast : float = 2.0
var wait_time : float = 0.25
var wait_time_fast : float = 0.0

# Buffer variables
var team_list = []


# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	# Load settings from settings.cfg, or defaults if not available
	var config = ConfigFile.new()
	var err = config.load("settings.cfg")
	if err == OK:
		print("Config file loaded, getting settings...")
		# File paths
		rec_path = config.get_value("paths", "recs", "../data/records/")
		# Connection params
		offline_mode = config.get_value("flags", "offline_mode", false)
		# Game params
		fast_wait = config.get_value("flags", "fast_wait", false)
		focus_time = config.get_value("game", "focus_time", 4)
		bracket_time = config.get_value("game", "bracket_time", 5)
		prep_time = config.get_value("game", "prep_time", 60)
		prep_time_fast = config.get_value("game", "prep_time_fast", 4)
		pay_time = config.get_value("game", "pay_time", 30)
		pay_time_fast = config.get_value("game", "pay_time_fast", 2)
		bet_time = config.get_value("game", "bet_time", 60)
		bet_time_fast = config.get_value("game", "bet_time_fast", 2)
		# Combat params
		fast_combat = config.get_value("flags", "fast_combat", false)
		turn_timeout = config.get_value("map", "turn_timeout", 80)
		idle_timeout = config.get_value("map", "idle_timeout", 30)
		move_speed = config.get_value("mech", "move_speed", 20.0)
		move_speed_fast = config.get_value("mech", "move_speed_fast", 40.0)
		anim_speed = config.get_value("mech", "anim_speed", 1.0)
		anim_speed_fast = config.get_value("mech", "anim_speed_fast", 2.0)
		wait_time = config.get_value("mech", "wait_time", 0.25)
		wait_time_fast = config.get_value("mech", "wait_time_fast", 0)
	else:
		print("Error loading config file, using defaults...")
	var json = ""
	file = FileAccess.open("../data/streams.json", FileAccess.READ)
	json = file.get_as_text()
	streams = JSON.parse_string(json)
	file.close()


func write_log(row : String, type : String):
	var time = Time.get_datetime_dict_from_system()
	var timestamp = "%d-%02d-%02dT%02d:%02d:%02d" % [time.year, time.month, time.day, time.hour, time.minute, time.second]
	var file_name = "%s%s_log.csv" % [rec_path, type]
	if file.file_exists(file_name):
		file = FileAccess.open(file_name, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(file_name, FileAccess.WRITE)
	file.seek_end()
	file.store_string("%s,%s\n" % [row, timestamp])
	file.close()


func log_transaction(user, value, type):
	write_log("%s,%d,%s" % [user, value, type], "transaction")


func screenshot():
	var time = Time.get_datetime_dict_from_system()
	var timestamp = "%s%s%sT%s%s%s" % [time.year, time.month, time.day, time.hour, time.minute, time.second]
	get_viewport().get_texture().get_image().save_png("%s/shot%s.png" % [screenshot_path, timestamp])

