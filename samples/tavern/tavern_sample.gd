extends Control
## Sample game screen built on LoreHubRunner with its own UI instead of the sample dialogue box. Shows how to:
## - feed game state into LoreHub variables before a dialogue (the gold buttons),
## - draw lines and choices yourself, with a typewriter effect and a speaker badge,
## - use node meta data (the "mood" text field tints the scene, "wait" pauses before the line),
## - react to variable changes, and save and load mid-dialogue.
## Everything is built in code so the whole example reads top to bottom in one file.

const DIALOGUE := preload("res://demo/tavern.json")
const SAVE_PATH := "user://lorehub_sample_save.json"
const CHARS_PER_SECOND := 40.0
const MOOD_COLORS := {"grumpy": Color(0.30, 0.16, 0.14), "": Color(0.12, 0.13, 0.17)}

var runner := LoreHubRunner.new(DIALOGUE)

var _background: ColorRect
var _badge: Label
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _continue: Button
var _variables: Label
var _status: Label
var _typing: Tween


func _ready() -> void:
	_build_ui()
	runner.line_started.connect(_on_line_started)
	runner.choices_presented.connect(_on_choices_presented)
	runner.variable_changed.connect(func(_name, _value): _show_variables())
	runner.dialogue_finished.connect(_on_finished)
	_restart()


func _restart() -> void:
	# Everything back to LoreHub's defaults except gold, which the game owns: the toolbar buttons change it.
	var gold: int = runner.get_variable("gold")
	runner.reset_state()
	runner.set_variable("gold", gold)
	runner.start("", true)
	_status.text = "Started. Kael sells drinks for 10 gold: you have %d." % runner.get_variable("gold")


func _on_line_started(line: LoreHubLine) -> void:
	_clear_choices()
	_continue.hide()
	_background.color = MOOD_COLORS.get(line.meta.get("mood", ""), MOOD_COLORS[""])
	_speaker.text = line.speaker_name if line.speaker_name != "" else "Narrator"
	_badge.text = _speaker.text.left(1)
	_badge.modulate = _speaker_color(line.speaker_id)
	_text.text = line.text
	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	# Integer meta data arrives as an int: "wait" holds the line back for that many tenths of a second.
	_typing.tween_interval(line.meta.get("wait", 0) / 10.0)
	_typing.tween_property(_text, "visible_ratio", 1.0, line.text.length() / CHARS_PER_SECOND)
	if not line.has_options:
		_typing.tween_callback(_show_continue)


func _on_choices_presented(choices: Array) -> void:
	await _typing.finished
	if choices.is_empty():
		_show_continue()  # every option is hidden: Continue ends the dialogue
		return
	for choice in choices:
		var button := Button.new()
		button.text = choice.text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(runner.choose.bind(choice))
		_choices.add_child(button)
	(_choices.get_child(0) as Button).grab_focus()


func _on_finished() -> void:
	_clear_choices()
	_continue.hide()
	_speaker.text = ""
	_badge.text = ""
	_text.text = "[i]The conversation is over. Restart, or give yourself gold and try again.[/i]"
	_text.visible_ratio = 1.0
	_status.text = "Finished."


func _show_continue() -> void:
	_continue.show()
	_continue.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if _typing and _typing.is_running():
		_typing.custom_step(1000.0)  # skip the typewriter
		get_viewport().set_input_as_handled()


func _give_gold(amount: int) -> void:
	runner.set_variable("gold", runner.get_variable("gold") + amount)
	_status.text = "Gold is now %d. Options re-check their conditions on the next node." % runner.get_variable("gold")


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(runner.get_state()))
	_status.text = "Saved to %s." % ProjectSettings.globalize_path(SAVE_PATH)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_status.text = "No save yet."
		return
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(state) != TYPE_DICTIONARY:
		_status.text = "The save file is broken."
		return
	runner.set_state(state)
	_show_variables()
	if runner.is_running():
		runner.resume()
	else:
		_on_finished()
	_status.text = "Loaded."


func _show_variables() -> void:
	var parts: PackedStringArray = []
	var variables := runner.get_variables()
	for variable_name in variables:
		parts.append("%s: %s" % [variable_name, variables[variable_name]])
	_variables.text = "   ".join(parts)


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _speaker_color(speaker_id: String) -> Color:
	if speaker_id == "":
		return Color(0.7, 0.7, 0.7)
	return Color.from_hsv(float(speaker_id.hash() % 360) / 360.0, 0.5, 0.95)


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_background = ColorRect.new()
	_background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "LoreHub Dialogue Player: tavern sample"
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)

	var toolbar := HBoxContainer.new()
	rows.add_child(toolbar)
	for entry in [["Restart", _restart], ["+20 gold", _give_gold.bind(20)], ["-5 gold", _give_gold.bind(-5)],
			["Save", _save], ["Load", _load]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		toolbar.add_child(button)

	_variables = Label.new()
	rows.add_child(_variables)
	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.7)
	rows.add_child(_status)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	rows.add_child(spacer)

	var panel := PanelContainer.new()
	rows.add_child(panel)
	var inner := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(inner)
	var line_row := HBoxContainer.new()
	line_row.add_theme_constant_override("separation", 16)
	inner.add_child(line_row)

	_badge = Label.new()
	_badge.custom_minimum_size = Vector2(64, 64)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 36)
	line_row.add_child(_badge)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = SIZE_EXPAND_FILL
	line_row.add_child(text_column)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 18)
	text_column.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(0, 60)
	text_column.add_child(_text)
	_choices = VBoxContainer.new()
	text_column.add_child(_choices)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.size_flags_horizontal = SIZE_SHRINK_END
	_continue.pressed.connect(runner.advance)
	text_column.add_child(_continue)
