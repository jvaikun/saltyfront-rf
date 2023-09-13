extends VBoxContainer

@onready var bars = [
	$Lists/Teams/Content/ChartBar,
	$Lists/Teams/Content/ChartBar2,
	$Lists/Teams/Content/ChartBar3,
	$Lists/Teams/Content/ChartBar4,
	$Lists/Teams/Content/ChartBar5,
	$Lists/Teams/Content/ChartBar6,
	$Lists/Teams/Content/ChartBar7,
	$Lists/Teams/Content/ChartBar8
]
@onready var ranks = [
	$Lists/Ranking/Content/RankItem,
	$Lists/Ranking/Content/RankItem2,
	$Lists/Ranking/Content/RankItem3,
	$Lists/Ranking/Content/RankItem4,
	$Lists/Ranking/Content/RankItem5,
	$Lists/Ranking/Content/RankItem6,
	$Lists/Ranking/Content/RankItem7,
	$Lists/Ranking/Content/RankItem8,
	$Lists/Ranking/Content/RankItem9,
	$Lists/Ranking/Content/RankItem10
]

signal summary_done

var cycle_max = 0
var cycle_count = 0


func start_timer(time, cycle_time):
	cycle_max = int(time / cycle_time)
	$Timer.start(cycle_time)


func update_head(tourinfo):
	$Header/Title.text = "Tournament Overview\nAverage Turns: %d\nAverage Time: %d" % [tourinfo.avg_turns, tourinfo.avg_time]


func update_stats(info, stats):
	$Lists/Teams/Content/Header.text = "Team Stats: %s" % info[0]
	$Lists/Ranking/Content/Header.text = "%s\nPilot Ranking" % info[0]
	var maxval = 0
	var anim_tween = create_tween()
	anim_tween.set_parallel()
	# Go thru stat array, get name, selected stat, 
	for stat in stats.teams:
		if stat[info[1]] > maxval:
			maxval = stat[info[1]]
	for i in bars.size():
		bars[i].set_color(GameData.teamColors[i])
		bars[i].val_name = stats.teams[i].name.capitalize()
		bars[i].val_max = maxval
		bars[i].val_num = stats.teams[i][info[1]]
		anim_tween.tween_property(bars[i], "val_num", stats.teams[i][info[1]], 0.5)
	for i in ranks.size():
		ranks[i].set_rank(i+1, stats.ranking[info[1]][i].label, stats.ranking[info[1]][i].value)
	anim_tween.play()


func _on_timer_timeout():
	cycle_count += 1
	if cycle_count > cycle_max:
		$Timer.stop()
		summary_done.emit()

