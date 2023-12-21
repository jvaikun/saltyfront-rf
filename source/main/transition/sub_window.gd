extends PanelContainer

const MAX_LINES = 4

@export var head_text = ""

var msg_text = [
	"Sub System Message 1",
	"Sub System Message 2",
	"Sub System Message 3",
	"Sub System Message 4",
]


func _ready():
	$Content/Header.text = head_text
	$Content/Body.text = ""


func set_messages(new_text):
	msg_text = new_text


func show_messages():
	for i in MAX_LINES:
		$Content/Body.text += msg_text[i] + "\n"
		await get_tree().create_timer(randf()).timeout

