extends Gift

enum GameState {START, PREFIGHT, FIGHT, POSTFIGHT, TOUR_END, RESET}

# Legacy variables. Need to figure out how to get at these nicely
# Tournament object, part of main game
var tournament
# Betting information, part of main game or bet manager
var bets
# List of users queued for next tournament, part of main game
var next_queue

var regex_valid = RegEx.new()
var state = GameState.START
var got_pong : bool = false
var missed_pongs : int = 0
var active_users : Array = []

# Twitch credentials
var NICK : String
var CLIENT_ID : String
var CHANNEL : String
var OAUTH : String

signal combat_chat_sent(sender, msg)
signal bet_made(bet_type, user_name, money, team)
signal bet_cancelled(id)
signal fight_joined(id, pilot_type)
signal hype_sent(team, money)


# add_command(cmd_name : String, instance : Object, instance_func : String, 
# max_args : int = 0, min_args : int = 0, 
# permission_level : int = PermissionFlag.EVERYONE, where : int = WhereFlag.CHAT)
func _ready():
	regex_valid.compile("\\D|^0")
	add_command("help", cmd_help)
	add_command("register", cmd_register)
	add_alias("register", "reg")
	add_command("balance", cmd_balance)
	add_alias("balance", "bal")
	add_command("bet", cmd_bet, 2, 0)
	add_command("allin", cmd_allin, 1, 0)
	add_command("fight", cmd_fight, 2, 0)
	add_command("hype", cmd_hype, 2, 0)


func set_channel(chan):
	NICK = GameData.streams[chan].nick
	CLIENT_ID = GameData.streams[chan].client
	CHANNEL = GameData.streams[chan].channel
	OAUTH = GameData.streams[chan].oauth


func connect_chat():
	await(authenticate(CLIENT_ID, OAUTH))
	var success = await(connect_to_irc())
	if (success):
		request_caps()
		join_channel(CHANNEL)
		chat("Whatup big money hustlaz, SaltyFront is open for business! Throw bills or throw hands, whatever you want, just get in and get that paper!")


func twitch_message(message, _tags):
	if message == "PONG :tmi.twitch.tv":
		got_pong = true
		missed_pongs = 0


# CHAT MESSAGE HANDLER
func chat_msg(sender_data, message):
	var sender_id = UserDB.get_user_id(sender_data.user)
	if sender_data.user.to_lower() != GameData.CLIENT_ID.to_lower():
		GameData.write_log("%s,%s" % [sender_data.user, message], "chat")
	if sender_id in active_users:
		emit_signal("combat_chat_sent", sender_id, message)


# CHAT COMMAND FUNCTIONS
# Help 
func cmd_help(cmd_info : CommandInfo):
	var user = cmd_info.sender_data.user
	chat(user + ", chat command info is in the About section")


# Registration
func cmd_register(cmd_info : CommandInfo):
	var user = cmd_info.sender_data.user
	if UserDB.add_user(user) == true:
		chat("Registered user " + user)
		GameData.write_log(user + ",register,ok", "command")
	else:
		chat(user + ", you have already registered")
		GameData.write_log(user + ",register,err_existing", "command")
	return


# Check balance
func cmd_balance(cmd_info : CommandInfo):
	var user = cmd_info.sender_data.user
	var this_user_id = UserDB.get_user_id(user)
	if this_user_id != "":
		var this_user = UserDB.users[this_user_id]
		chat(user + ", your balance is "
		+ str(this_user.money) + "C, with " + str(this_user.insurance) + "C of insurance.")
		GameData.write_log(user + ",balance,ok", "command")
		return
	else:
		chat("You have not registered yet.")
		GameData.write_log(user + ",balance,err_noreg", "command")
		return


# All in
# !allin ["left", "right", "random", team_name]
func cmd_allin(cmd_info : CommandInfo, arg_ary):
	var user = cmd_info.sender_data.user
	var this_user_id = UserDB.get_user_id(user)
	var this_user = null
	if this_user_id == "":
		chat(user + ", you have not registered yet. Please register to place bets.")
		GameData.write_log(user + ",allin,err_noreg", "command")
		return
	else:
		this_user = UserDB.users[this_user_id]
	if self.state != GameState.PREFIGHT:
		chat("Sorry " + user + ", betting is closed now!")
		GameData.write_log(user + ",allin,err_closed", "command")
		return
	# Only one param allowed, team name
	var current_teams = []
	for team in tournament.current_match.teams:
		current_teams.append(team.index)
	if arg_ary.size() == 1:
		for bet in bets:
			if bet.name == this_user.name:
				chat(this_user.name + ", you've already placed a bet.")
				GameData.write_log(user + ",allin,err_existing", "command")
				return
		var betTeam = arg_ary[0].to_lower().strip_edges()
		if betTeam == "champ":
			betTeam = "champion"
		var teamIndex = GameData.teamNames.find(betTeam)
		match betTeam:
			"left":
				teamIndex = current_teams[0]
				betTeam = GameData.teamNames[teamIndex]
			"right":
				teamIndex = current_teams[1]
				betTeam = GameData.teamNames[teamIndex]
			"random":
				if randf() > 0.5:
					teamIndex = current_teams[0]
					betTeam = GameData.teamNames[teamIndex]
				else:
					teamIndex = current_teams[1]
					betTeam = GameData.teamNames[teamIndex]
			_:
				if teamIndex == -1 || !current_teams.has(teamIndex):
					chat(this_user.name + ", that team's not fighting right now.")
					GameData.write_log(user + ",bet,err_noteam", "command")
					return
		emit_signal("bet_made", "user", this_user.name, this_user.money, teamIndex)
		var msg = this_user.name + " bet it all on " + betTeam + "!"
		chat(msg)
		GameData.write_log(user + ",allin,ok", "command")
		return
	else:
		chat(this_user.name + ", command error. Check the chat commands in the About section.")
		GameData.write_log(user + ",allin,err_syntax", "command")
		return


# Place bet on selected team
# !bet ["all", "half", bet_amt] ["left", "right", "random", team_name]
# !bet cancel: Cancels your current bet, if done before betting ends, bank keeps 10% cancellation fee.
# !bet: Gets your bet for the current match, and how much you stand to earn if you win.
func cmd_bet(cmd_info : CommandInfo, arg_ary):
	# Get user name, and check if they're registered, and if they can bet now
	var user = cmd_info.sender_data.user
	var this_user_id = UserDB.get_user_id(user)
	var this_user = null
	if this_user_id == "":
		chat(user + ", you have not registered yet. Please register to place bets.")
		GameData.write_log(user + ",bet,err_noreg", "command")
		return
	else:
		this_user = UserDB.users[this_user_id]
	if self.state != GameState.PREFIGHT:
		chat("Sorry " + user + ", betting is closed now!")
		GameData.write_log(user + ",bet,err_closed", "command")
		return
	# Validation cleared, prepare parameter variables
	var current_teams = []
	for team in tournament.current_match.teams:
		current_teams.append(team.index)
	var betMoney = 0
	var betTeam = ""
	var teamIndex = 0
	# Case 1: No parameters, get bet info and show it to user
	if arg_ary.size() == 0:
		for bet in bets:
			if bet.name == this_user.name:
				chat(this_user.name +
				", you bet " + str(bet.money) +
				" on " + GameData.teamNames[bet.team].capitalize())
				GameData.write_log(user + ",bet,ok_check", "command")
				return
		chat(this_user.name + ", you haven't placed a bet.")
		GameData.write_log(user + ",bet,err_nobets", "command")
		return
	# Case 2: One parameter, check if it's the 'cancel' option or not
	elif arg_ary.size() == 1:
		if arg_ary[0].to_lower().strip_edges() == "cancel":
			for bet in bets:
				if bet.name == this_user.name:
					emit_signal("bet_cancelled", user_id)
					chat(this_user.name + ", you've cancelled your bet.")
					GameData.write_log(user + ",bet,ok_cancel", "command")
					return
			chat(this_user.name + ", you haven't placed a bet.")
			GameData.write_log(user + ",bet,err_nobets", "command")
			return
		else:
			chat(this_user.name + ", command error. Check the chat commands in the About section.")
			GameData.write_log(user + ",bet,err_syntax", "command")
			return
	# Case 3: Two parameters, check amount and team params
	elif arg_ary.size() > 1:
		for bet in bets:
			if bet.name == this_user.name:
				chat(this_user.name + ", you've already placed a bet.")
				GameData.write_log(user + ",bet,err_existing", "command")
				return
		betMoney = arg_ary[0].to_lower().strip_edges()
		betTeam = arg_ary[1].to_lower().strip_edges()
		if betTeam == "champ":
			betTeam = "champion"
		teamIndex = GameData.teamNames.find(betTeam)
		match betTeam:
			"left":
				teamIndex = current_teams[0]
				betTeam = GameData.teamNames[teamIndex]
			"right":
				teamIndex = current_teams[1]
				betTeam = GameData.teamNames[teamIndex]
			"random":
				if randf() > 0.5:
					teamIndex = current_teams[0]
					betTeam = GameData.teamNames[teamIndex]
				else:
					teamIndex = current_teams[1]
					betTeam = GameData.teamNames[teamIndex]
			_:
				if teamIndex == -1 or !current_teams.has(teamIndex):
					chat(this_user.name + ", that team's not fighting right now.")
					GameData.write_log(user + ",bet,err_noteam", "command")
					return
		match betMoney:
			"all", "allin":
				var msg = this_user.name + " bet it all on " + betTeam + "!"
				emit_signal("bet_made", "user", this_user.name, this_user.money, teamIndex)
				chat(msg)
				GameData.write_log(user + ",bet,ok_allin", "command")
				return
			"half", "halfin":
				var msg = this_user.name + " bet half their money on " + betTeam + "!"
				emit_signal("bet_made", "user", this_user.name, floor(this_user.money/2), teamIndex)
				chat(msg)
				GameData.write_log(user + ",bet,ok_halfin", "command")
				return
			_:
				# Validate money string
				if regex_valid.search(betMoney) != null:
					chat(this_user.name + ", that's not a valid number.")
					GameData.write_log(user + ",bet,err_syntax", "command")
					return
				if this_user.money < int(betMoney):
					chat("Sorry, " + this_user.name + ", you don't have enough money.")
					GameData.write_log(user + ",bet,err_nomoney", "command")
					return
				else:
					var msg = this_user.name + " bet " + str(betMoney) + " on " + betTeam
					emit_signal("bet_made", "user", this_user.name, int(betMoney), teamIndex)
					chat(msg)
					GameData.write_log(user + ",bet,ok_bet", "command")
					return


# !fight {pilot (0-3)} {skill}: Register a pilot to fight
# Will default to pilot0 if no pilot slot is given
# Can only use during team generation at the start of a tournament.
func cmd_fight(cmd_info : CommandInfo, arg_ary):
	# Get user ID from first param to validate
	var user = cmd_info.sender_data.user
	var this_user_id = UserDB.get_user_id(user)
	if this_user_id != "":
		if state == GameState.START:
			for entry in tournament.fight_queue:
				if entry.user == this_user_id:
					chat(user + ", you have already signed up to fight.")
					return
		else:
			for entry in next_queue:
				if entry.user == this_user_id:
					chat(user + ", you are already queued for the next tournament.")
					return
		#var this_user = UserDB.users[user_id]
		if arg_ary.size() == 0:
			if state == GameState.START:
				emit_signal("fight_joined", this_user_id, "rand")
				chat(user + " signed up to fight! Chosen class: Random")
			else:
				next_queue.append({"user":this_user_id, "pilot":"rand"})
				chat(user + " signed up for the next tournament! Chosen class: Random")
			GameData.write_log(user + ",fight,ok_rand", "command")
			return
		if arg_ary.size() == 1:
			if tournament.PILOT_CLASS.keys().has(arg_ary[0]):
				if state == GameState.START:
					emit_signal("fight_joined", this_user_id, arg_ary[0])
					chat(user + " signed up to fight! Chosen class: " + arg_ary[0])
				else:
					next_queue.append({"user":this_user_id, "pilot":arg_ary[0]})
					chat(user + " signed up for the next tournament! Chosen class: " + arg_ary[0])
				GameData.write_log(user + ",fight,ok_" + arg_ary[0], "command")
				return
			else:
				chat("Invalid pilot slot")
				GameData.write_log(user + ",fight,err_nopilot", "command")
				return
		if arg_ary.size() > 1:
			if ["l", "h", "light", "heavy"].has(arg_ary[1]):
				pass
			chat("Skill/equip setting not supported yet.")
			GameData.write_log(user + ",fight,err_noskill", "command")
			return
	else:
		chat("Please register before signing up.")
		GameData.write_log(user + ",fight,err_noreg", "command")
		return


func cmd_hype(cmd_info : CommandInfo, arg_ary):
	var user = cmd_info.sender_data.user
	if self.state != GameState.FIGHT:
		chat("There's no fight to get hype about, %s!" % user)
		GameData.write_log(user + ",hype,err_closed", "command")
		return
	# Validation cleared, prepare parameter variables
	var current_teams = []
	for team in tournament.current_match.teams:
		current_teams.append(team.index)
	var team = arg_ary[1].to_lower().strip_edges()
	if team == "champ":
		team = "champion"
	var team_index = GameData.teamNames.find(team)
	var money = arg_ary[0].to_lower().strip_edges()
	chat("GET HYPE! %s put %dC on %s" % [user, money, team])
	emit_signal("hype_sent", team_index, money)
