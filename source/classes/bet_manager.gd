class_name BetManager

var bet_ai : Dictionary = {}
var bets : Array = []
var payouts : Array = []
var books : Array = []


func calc_odds():
	var pool = 0
	for i in books.size():
		books[i].count = 0
		books[i].total = 0
		books[i].percent = 0
		books[i].odds = 0
		for bet in bets:
			if bet.team == books[i].team:
				books[i].count += 1
				books[i].total += bet.money
				pool += bet.money
	for team in books:
		if team.total > 0 && pool > 0:
			team.percent = float(team.total) / pool
			team.odds = float(pool) / team.total
		else:
			team.percent = 0.0
			team.odds = 0.0


func auto_bet(roster, team_list):
	var coin_flip = 0
	var money = 0
	# NPC pilot bets
	for team in roster:
		for mech in team.data:
			if mech.user_id == "npc":
				coin_flip = int(randf() / 0.5)
				money = (randi() % 5 + 1) * 100
				add_bet("npc", mech.pilot.name, money, team_list[coin_flip].index)


# Add a bet
func add_bet(type, name, money, team):
	# Validate user name and add bet to list if OK
	var newBet = {"type":type, "name": name, "money": money, "team": team}
	for user in UserDB.users.keys():
		var thisUser = UserDB.users[user]
		if thisUser.name == name:
			thisUser.money -= newBet.money
			thisUser.money = clamp(thisUser.money, thisUser.insurance, 1000000)
			GameData.log_transaction(user, thisUser.money, "place_bet")
	bets.append(newBet)
	calc_odds()


# Cancel a bet
func cancel_bet(user_id):
	var thisUser = UserDB.users[user_id]
	for i in bets.size():
		if bets[i].name == thisUser.name:
			thisUser.money += ceil(0.9 * bets[i].money)
			GameData.log_transaction(user_id, thisUser.money, "cancel_bet")
			bets.remove_at(i)
			break


# Clear bet list
func reset_bets(team_list):
	bets.clear()
	books.clear()
	for team in team_list:
		books.append({"team":team.index, "count":0, "total":0, "percent":0, "odds":0})


# Pay out winning bets
func pay_out(winner):
	var win_index = 0
	for i in books.size():
		if books[i].team == winner:
			win_index = i
	for bet in bets:
		if bet.team == winner:
			if bet.type == "user":
				for user in UserDB.users.keys():
					var thisUser = UserDB.users[user]
					if thisUser.name == bet.name:
						thisUser.money += round(bet.money * books[win_index].odds)
						thisUser.money = max(thisUser.money, thisUser.insurance)
						GameData.log_transaction(user, thisUser.money, "pay_out")
			if bet.type == "corp":
				for corp in bet_ai.corps:
					if corp == bet.name:
						bet_ai.corps[corp].funds += round(bet.money * books[win_index].odds)
			var betText = "%s, +%d (%d x %.2f)\n"
			payouts.append(betText % [
				bet.name,
				bet.money * books[win_index].odds,
				bet.money,
				books[win_index].odds])

