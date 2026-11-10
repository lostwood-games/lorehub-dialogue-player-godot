class_name LoreHubDialogueBox
extends PanelContainer
## A small dialogue box: speaker name, text, a button per choice and Continue. Copy the scene and restyle it, or
## use it as an example for your own UI. Reads the dialogue with a [LoreHubRunner], available as [member runner].

## The dialogue ended.
signal finished

const _Runner := preload("../lorehub_runner.gd")

## Dialogue to play when the box enters the tree, see [member autostart].
@export var dialogue: JSON
@export var autostart := false
## Hide the box when the dialogue ends.
@export var hide_when_finished := true

## Runner of the dialogue being played; set its variables before [method play] with keep_state, or read them after.
var runner: _Runner

@onready var _speaker: Label = %Speaker
@onready var _text: RichTextLabel = %Text
@onready var _choices: VBoxContainer = %Choices
@onready var _continue: Button = %Continue


func _ready() -> void:
	_continue.pressed.connect(_on_continue)
	if autostart and dialogue != null:
		play(dialogue)
	else:
		hide()


## Shows the box and plays [param source] from its start: a LoreHub .json export such as
## [code]preload("res://dialogues/tavern.json")[/code], or anything [method LoreHubDialogue.from_source] reads. With
## [param keep_state] the runner keeps its variables and history, for a second dialogue of the same story or after
## [method LoreHubRunner.set_state].
func play(source: Variant, keep_state: bool = false) -> void:
	var previous := runner
	runner = _Runner.new(source)
	if runner.dialogue == null:
		return
	if keep_state and previous != null:
		runner.set_state(previous.get_state())
	runner.line_started.connect(_on_line_started)
	runner.choices_presented.connect(_on_choices_presented)
	runner.dialogue_finished.connect(_on_finished)
	show()
	runner.start("", keep_state)


func _unhandled_input(event: InputEvent) -> void:
	if visible and _continue.visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_continue()


func _on_line_started(line) -> void:
	_speaker.text = line.speaker_name
	_speaker.visible = line.speaker_name != ""
	_text.text = line.text
	_clear_choices()
	# Nodes with options wait for a choice; the rest wait for Continue. When every option is hidden, Continue ends it.
	_continue.visible = true
	_continue.grab_focus.call_deferred()


func _on_choices_presented(choices: Array) -> void:
	_clear_choices()
	_continue.visible = choices.is_empty()
	for choice in choices:
		var button := Button.new()
		button.text = choice.text
		button.disabled = not choice.available
		button.pressed.connect(runner.choose.bind(choice))
		_choices.add_child(button)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus.call_deferred()


func _on_continue() -> void:
	if runner != null and runner.is_running():
		runner.advance()


func _on_finished() -> void:
	_clear_choices()
	if hide_when_finished:
		hide()
	finished.emit()


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
