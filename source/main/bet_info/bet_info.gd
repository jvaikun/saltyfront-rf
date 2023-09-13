extends VBoxContainer

const format_bet = "%s, %d (%.2f%%)\n"
const team_info = "%s\nPAYOUT\nx%.2f"
const team_percent = "%dC"
const list_header = "TOP 10 BETS: %s"

@onready var labels = [
	{ 
		"teaminfo":$Header/Content/Team1,
		"teamcolor":$Header/Content/BetRatio/TeamColor1,
		"percent":$Header/Content/BetRatio/TeamColor1/Money,
		"listhead":$TopBets/Team1/Content/Header,
		"toplist":$TopBets/Team1/Content/BetList,
	},
	{
		"teaminfo":$Header/Content/Team2,
		"teamcolor":$Header/Content/BetRatio/TeamColor2,
		"percent":$Header/Content/BetRatio/TeamColor2/Money,
		"listhead":$TopBets/Team2/Content/Header,
		"toplist":$TopBets/Team2/Content/BetList,
	}
]


# Custom sort by bet size, descending
static func money_desc(a, b):
	if a["money"] > b["money"]:
		return true
	return false


func update_info(books, bets):
	bets.sort_custom(money_desc)
	for i in books.size():
		labels[i].teaminfo.text = team_info % [
			GameData.TEAM_DEFS[books[i].team].name.to_upper(),
			books[i].odds,
		]
		labels[i].teamcolor.color = GameData.TEAM_DEFS[books[i].team].ui_color
		labels[i].percent.text = team_percent % books[i].total
		labels[i].listhead.modulate = GameData.TEAM_DEFS[books[i].team].ui_color
		labels[i].listhead.text = list_header % GameData.TEAM_DEFS[books[i].team].name.to_upper()
		labels[i].toplist.text = ""
	if books[1].total != 0:
		labels[0].teamcolor.size_flags_stretch_ratio = float(books[0].total) / books[1].total
	var count1 = 0
	var count2 = 0
	for bet in bets:
		var ind = 0
		if bet.team != books[0].team:
			ind = 1
		var pct = float(bet.money) / books[ind].total * 100
		if ind == 0:
			count1 += 1
			if count1 <= 10:
				labels[ind].toplist.text += format_bet % [bet.name, bet.money, pct]
		else:
			count2 += 1
			if count2 <= 10:
				labels[ind].toplist.text += format_bet % [bet.name, bet.money, pct]

