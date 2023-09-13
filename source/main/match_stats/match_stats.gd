extends Control

# Accessor vars
@onready var pilots = [
	{"pilot":$Rankings/Content/Body/Team1Mech1/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team1Mech1/Bonuses},
	{"pilot":$Rankings/Content/Body/Team1Mech2/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team1Mech2/Bonuses},
	{"pilot":$Rankings/Content/Body/Team1Mech3/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team1Mech3/Bonuses},
	{"pilot":$Rankings/Content/Body/Team1Mech4/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team1Mech4/Bonuses},
	{"pilot":$Rankings/Content/Body/Team2Mech1/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team2Mech1/Bonuses},
	{"pilot":$Rankings/Content/Body/Team2Mech2/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team2Mech2/Bonuses},
	{"pilot":$Rankings/Content/Body/Team2Mech3/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team2Mech3/Bonuses},
	{"pilot":$Rankings/Content/Body/Team2Mech4/PilotInfo, 
	"bonus":$Rankings/Content/Body/Team2Mech4/Bonuses},
]

var cycle_time = 0
var focus_index = 0
var mech_count = 0

signal focus_changed(index)


func start_timer(time):
	cycle_time = time
	$Timer.start(cycle_time)


func set_payouts(list):
	var list_text = ""
	for item in list:
		list_text += item
	$Report/Payout/Content/Body.text = list_text


func update_info(team1, team2):
	var results1 = {"id":0, "hits":0, "crits":0, "misses":0, "dmg_out":0, "dmg_in":0, "part_dest":0, "part_lost":0}
	var results2 = {"id":0, "hits":0, "crits":0, "misses":0, "dmg_out":0, "dmg_in":0, "part_dest":0, "part_lost":0}
	for mech in team1.mechs:
		results1.id = mech.team
		results1.hits += mech.hit
		results1.crits += mech.crit
		results1.misses += mech.miss
		results1.dmg_out += mech.dmg_out
		results1.dmg_in += mech.dmg_in
		results1.part_dest += mech.part_dest
		results1.part_lost += mech.part_lost
	for mech in team2.mechs:
		results2.id = mech.team
		results2.hits += mech.hit
		results2.crits += mech.crit
		results2.misses += mech.miss
		results2.dmg_out += mech.dmg_out
		results2.dmg_in += mech.dmg_in
		results2.part_dest += mech.part_dest
		results2.part_lost += mech.part_lost
	# Update Team 1 stats
	$Report/Stats/Content/Team1/Header.text = team1.name.capitalize()
	$Report/Stats/Content/Team1/Header.modulate = team1.color
	$Report/Stats/Content/Team1/Hits.text = str(results1.hits)
	$Report/Stats/Content/Team1/Crits.text = str(results1.crits)
	$Report/Stats/Content/Team1/Misses.text = str(results1.misses)
	$Report/Stats/Content/Team1/DamageOut.text = str(results1.dmg_out)
	$Report/Stats/Content/Team1/DamageIn.text = str(results1.dmg_in)
	$Report/Stats/Content/Team1/PartDest.text = str(results1.part_dest)
	$Report/Stats/Content/Team1/PartLost.text = str(results1.part_lost)
	# Update Team 2 stats
	$Report/Stats/Content/Team2/Header.text = team2.name.capitalize()
	$Report/Stats/Content/Team2/Header.modulate = team2.color
	$Report/Stats/Content/Team2/Hits.text = str(results2.hits)
	$Report/Stats/Content/Team2/Crits.text = str(results2.crits)
	$Report/Stats/Content/Team2/Misses.text = str(results2.misses)
	$Report/Stats/Content/Team2/DamageOut.text = str(results2.dmg_out)
	$Report/Stats/Content/Team2/DamageIn.text = str(results2.dmg_in)
	$Report/Stats/Content/Team2/PartDest.text = str(results2.part_dest)
	$Report/Stats/Content/Team2/PartLost.text = str(results2.part_lost)
	# Create rankings
	var all_mechs = team1.mechs + team2.mechs
	mech_count = all_mechs.size()
	for i in all_mechs.size():
		pilots[i].bonus.text = ""
		pilots[i].pilot.set_focus(all_mechs[i])
		if all_mechs[i].bonuses.is_empty():
			pilots[i].bonus.text = "No Bonus"
		else:
			for item in all_mechs[i].bonuses:
				pilots[i].bonus.text += "%s +%d\n" % [item.title, item.pay]


func _on_timer_timeout():
	focus_index += 1
	if focus_index >= mech_count:
		focus_index = 0
	$Timer.start(cycle_time)
	focus_changed.emit(focus_index)


func _on_hidden():
	$Timer.stop()

