extends Control
## Plays the sample tavern dialogue in the sample dialogue box and shows the story variables as they change.

@onready var _box: LoreHubDialogueBox = $LoreHubDialogueBox
@onready var _variables: Label = %Variables
@onready var _replay: Button = %Replay


func _ready() -> void:
	_box.finished.connect(func(): _replay.show())
	_replay.pressed.connect(_play)
	_play()


func _play() -> void:
	_replay.hide()
	_box.play(preload("res://demo/tavern.json"))
	if not _box.runner.variable_changed.is_connected(_show_variables):
		_box.runner.variable_changed.connect(_show_variables)
	_show_variables("", null)


func _show_variables(_name: String, _value: Variant) -> void:
	var parts: PackedStringArray = []
	var variables := _box.runner.get_variables()
	for variable_name in variables:
		parts.append("%s = %s" % [variable_name, variables[variable_name]])
	_variables.text = "  ".join(parts)
