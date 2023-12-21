extends PanelContainer

const MAX_LENGTH = 40
const PADDING = " +++ "
const SCROLL_SPD = 0.1

@onready var clip_files = $ClipFiles
@onready var bgm = $BGM
@onready var clip = $Clip
@onready var ticker = $Ticker

var bgm_path = "../bgm/"
var bgm_list = []
var bgm_index = 0
var track_name = ""
var label_text = ""
var offset = 0
var wait = 0


func _ready():
	var dir = DirAccess.open(bgm_path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if !dir.current_is_dir():
			bgm_list.append({"name":file_name.get_basename(), "path":bgm_path + file_name})
		file_name = dir.get_next()
	dir.list_dir_end()
	bgm_list.shuffle()
	bgm.finished.connect(play_track)


func _process(delta):
	wait += delta
	if wait >= SCROLL_SPD:
		wait = 0
		move_text()


func move_text():
	if offset >= track_name.length():
		offset = 0
	label_text += track_name.substr(offset, 1)
	if label_text.length() >= MAX_LENGTH:
		label_text = label_text.right(1)
	ticker.text = label_text
	offset += 1


func play_track():
	if bgm_index >= bgm_list.size():
		bgm_index = 0
		bgm_list.shuffle()
	var file = FileAccess.open(bgm_list[bgm_index].path, FileAccess.READ)
	var bgm_stream = AudioStreamOggVorbis.new()
	bgm_stream.data = file.get_buffer(file.get_len())
	file.close()
	track_name = bgm_list[bgm_index].name + PADDING
	offset = 0
	bgm_index += 1
	bgm.stream = bgm_stream
	bgm.play()


func play_clip(title):
	clip.stream = clip_files.get_resource(title)
	clip.play()

