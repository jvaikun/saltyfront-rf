extends Control

# Game constants and enums
enum GameState {START, PREFIGHT, FIGHT, POSTFIGHT, TOUR_END, RESET}

# Accessor vars
@onready var hangar = $Hangar
@onready var arena = $Arena
@onready var transition = $Transition

# Modules
var tournament = Tournament.new()
var game_config = ConfigFile.new()
var bet_manager = BetManager.new()

# Game vars
var state = GameState.START

# Wait times
var signup_timer
var bracket_timer
var focus_timer
var bet_timer
var pay_timer
var stats_timer = focus_timer

# Bet and match tracking variables
var bet_ai : Dictionary = {}
var bets : Array = []
var books : Array = [
	{"team":0, "count":0, "total":0, "percent":0, "odds":0},
	{"team":0, "count":0, "total":0, "percent":0, "odds":0}
]
var active_users : Array = []
var next_queue : Array = []


func _ready():
	arena.hide()
	arena.match_data = tournament.current_match
	# Load config file
	var err = game_config.load("settings.cfg")
	if err != OK:
		print("Error loading game config!")
	# Connect signals
	tournament.connect("match_ended", next_match)
	tournament.connect("tour_ended", next_tour)
	# Set variables
	if game_config.get_value("game", "fast_wait", false):
		signup_timer = game_config.get_value("game", "signup_time_fast")
		bracket_timer = game_config.get_value("game", "bracket_time_fast")
		bet_timer = game_config.get_value("game", "bet_time_fast")
		pay_timer = game_config.get_value("game", "pay_time_fast")
		focus_timer = game_config.get_value("game", "focus_time_fast")
	else:
		signup_timer = game_config.get_value("game", "signup_time")
		bracket_timer = game_config.get_value("game", "bracket_time")
		bet_timer = game_config.get_value("game", "bet_time")
		pay_timer = game_config.get_value("game", "pay_time")
		focus_timer = game_config.get_value("game", "focus_time")
	stats_timer = focus_timer
	transition.boot_up()


func next_match():
	state = GameState.PREFIGHT
	get_tree().call_group("ui_prefight", "show")
	$Bracket.start_timer(bracket_timer)
	hangar.load_mechs(tournament.current_match.teams)


func next_tour():
	state = GameState.TOUR_END
	get_tree().call_group("ui_summary", "show")
	$TourStats.start_timer(signup_timer, focus_timer)


func _on_signup_signup_ended():
	hangar.workshop_out()
	await hangar.left_workshop
	state = GameState.PREFIGHT
	tournament.new_tournament()
	$Bracket.set_teams(tournament.roster, tournament.champ)
	$Bracket.start_timer(bracket_timer)
	hangar.load_mechs(tournament.current_match.teams)


func _on_versus_header_timer_ended():
	if state == GameState.PREFIGHT:
		state = GameState.FIGHT
		arena.load_map("res://maps/map.tscn")
		arena.setup_map()
		get_tree().call_group("ui_prefight", "hide")
		hangar.hide()
		arena.show()
		print("Betting ended!")
	elif state == GameState.POSTFIGHT:
		arena.hide()
		hangar.show()
		hangar.move_cam(0)
		get_tree().call_group("ui_postfight", "hide")
		print("Payout ended!")
		tournament.next_match()


func _on_match_ended():
	state = GameState.POSTFIGHT
	tournament.end_match({
		"winner": tournament.current_match.teams[0].index,
		"turns": 100,
		"start": 500,
		"end": 1000,
		"result": "test",
		"map": "Test",
	})
	if $VersusHeader.team1.team_index != tournament.current_winner:
		$VersusHeader.team1.set_loss(true)
	else:
		$VersusHeader.team2.set_loss(true)
	$Bracket.eliminate(tournament.current_loser)
	bet_manager.pay_out(tournament.current_winner)
	$MatchStats.set_payouts(bet_manager.payouts)
	# Go through teams and pay out bonuses
	for mech in (tournament.current_match.teams[0].mechs + tournament.current_match.teams[1].mechs):
		for bonus in mech.bonuses:
			if mech.user_id != "npc":
				UserDB.users[mech.user_id].money += bonus.pay
				var title_str = bonus.title.to_lower().replace(" ", "_")
				GameData.log_transaction(mech.user_id, UserDB.users[mech.user_id].money, title_str)
				var debug_msg = "%s: %s, +%d" % [UserDB.users[mech.user_id].name, bonus.title, bonus.pay]
				print(debug_msg)
	UserDB.save_users()
	get_tree().call_group("ui_postfight", "show")
	$VersusHeader.start_timer(tournament.current_match, "MAP", pay_timer)
	$MatchStats.start_timer(focus_timer)


func _on_bracket_bracket_ended():
	hangar.move_cam(0)
	$VersusHeader.set_teams(tournament.current_match.teams[0], tournament.current_match.teams[1])
	$MechInfo.set_list(tournament.current_match.teams[0].mechs + tournament.current_match.teams[1].mechs)
	bet_manager.reset_bets(tournament.current_match.teams)
	bet_manager.auto_bet(tournament.roster, tournament.current_match.teams)
	$BetInfo.update_info(bet_manager.books, bet_manager.bets)
	$VersusHeader.start_timer(tournament.current_match, "NEXT MAP", bet_timer)
	$MechInfo.start_timer(focus_timer)
	get_tree().call_group("ui_prefight", "show")


func _on_tour_stats_summary_done():
	state = GameState.START
	get_tree().call_group("ui_summary", "hide")
	get_tree().call_group("ui_signup", "show")
	$Signup.signup_start(tournament.tour_count, signup_timer)


func _on_mech_info_focus_changed(index):
	hangar.move_cam(index)


func _on_match_stats_focus_changed(index):
	hangar.move_cam(index)


func _on_transition_bootup_finished():
	$Signup.signup_start(tournament.tour_count, signup_timer)

