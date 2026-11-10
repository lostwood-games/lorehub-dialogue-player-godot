class_name LoreHubRunner
extends RefCounted
## Plays a [LoreHubDialogue] by the same rules as the player in LoreHub.
##
## [codeblock]
## var runner := LoreHubRunner.new(preload("res://dialogues/intro.json"))
## runner.line_started.connect(func(line): print(line))
## runner.choices_presented.connect(func(choices): runner.choose(choices[0]))
## runner.start()
## [/codeblock]
##
## Entering a node applies the variables it sets and marks it played, then [signal line_started] fires. When the
## node has options, [signal choices_presented] follows and the game calls [method choose]. When it has none, the
## game calls [method advance], which follows the first link whose conditions are all met. No link to follow ends
## the dialogue with [signal dialogue_finished].

## The player entered a node.
signal line_started(line)
## The current node has options. [param choices] holds the ones to show, see [member hide_unavailable_choices].
signal choices_presented(choices: Array)
## A variable changed, by the dialogue or by [method set_variable].
signal variable_changed(variable_name: String, value: Variant)
## The dialogue ended: no link was left to follow, or [method stop] was called.
signal dialogue_finished

const _Dialogue := preload("lorehub_dialogue.gd")
const _Line := preload("lorehub_line.gd")
const _Choice := preload("lorehub_choice.gd")

## The dialogue being played.
var dialogue: _Dialogue
## In a game a choice whose conditions fail is hidden, as LoreHub's player shows it. Set to false to get those
## choices too, with [member LoreHubChoice.available] false, for example to show them greyed out.
var hide_unavailable_choices := true

var _values := {}  # variable id -> bool or int
var _played := {}  # node short id -> true
var _selected := {}  # option short id -> true
var _node_id := ""  # current node, empty when not running
var _running := false


## [param source] is anything [method LoreHubDialogue.from_source] reads, such as
## [code]preload("res://dialogues/tavern.json")[/code].
func _init(source: Variant = null) -> void:
	dialogue = null if source == null else _Dialogue.from_source(source)
	if dialogue != null:
		reset_state()


## Starts the dialogue from its first node, or from [param node_id]. With [param keep_state] the variables,
## played nodes and selected options of an earlier run or of [method set_state] are kept; otherwise variables
## start from their LoreHub defaults.
func start(node_id: String = "", keep_state: bool = false) -> void:
	if dialogue == null:
		push_error("LoreHub: the runner has no dialogue.")
		return
	if not keep_state:
		reset_state()
	_running = true
	_enter(node_id if node_id != "" else dialogue.get_start_node_id())


## Ends the dialogue now.
func stop() -> void:
	if not _running:
		return
	_finish()


## True from [method start] until the dialogue ends.
func is_running() -> bool:
	return _running


## The node the player is on, null when the dialogue is not running.
func get_current_line() -> _Line:
	return _build_line(_node_id) if _running else null


## Choices of the current node; empty when it has no options or the dialogue is not running.
func get_choices() -> Array:
	var result: Array = []
	if not _running:
		return result
	var index := 0
	for option in dialogue.get_node_options(_node_id):
		var choice := _Choice.new()
		choice.id = _Dialogue.short_id(option.get("id", ""))
		choice.text = str(option.get("text", ""))
		choice.index = index
		choice.failing_conditions = _failing(option.get("requiredVariables", []))
		choice.available = choice.failing_conditions.is_empty()
		index += 1
		if choice.available or not hide_unavailable_choices:
			result.append(choice)
	return result


## Picks a choice of the current node: marks the option selected and goes where its first passing link leads.
func choose(choice: _Choice) -> void:
	if choice == null:
		push_error("LoreHub: choose() needs a choice.")
		return
	choose_id(choice.id)


## Picks the option with this short or full id.
func choose_id(option_id: String) -> void:
	if not _running:
		push_error("LoreHub: the dialogue is not running.")
		return
	var id := _Dialogue.short_id(option_id)
	var option: Dictionary = {}
	for candidate in dialogue.get_node_options(_node_id):
		if _Dialogue.short_id(candidate.get("id", "")) == id:
			option = candidate
	if option.is_empty():
		push_error("LoreHub: option %s is not on the current node." % id)
		return
	if not _failing(option.get("requiredVariables", [])).is_empty():
		push_error('LoreHub: option "%s" is not available, its conditions are not met.' % option.get("text", ""))
		return
	# Where the option leads is decided before it counts as selected, as in LoreHub's player.
	var target := _first_passing_link(id)
	_selected[id] = true
	_enter(target)


## Goes on from a node without options: follows the first link whose conditions are all met, or ends the
## dialogue when there is none. On a node with available choices, use [method choose] instead.
func advance() -> void:
	if not _running:
		return
	if not get_choices().filter(func(c): return c.available).is_empty():
		push_error("LoreHub: the current node has choices, call choose() instead of advance().")
		return
	_enter(_first_passing_link(_node_id))


## Fires [signal line_started] and [signal choices_presented] again for the current node without changing any
## state, for example after [method set_state] or when the dialogue UI is rebuilt.
func resume() -> void:
	if not _running:
		return
	_present()


## Value of a story variable by its LoreHub name: bool for boolean variables, int for number variables, null
## when the dialogue has no such variable.
func get_variable(variable_name: String) -> Variant:
	var id := dialogue.get_variable_id(variable_name)
	if id == "":
		return null
	return _values.get(id)


## Sets a story variable by its LoreHub name, for example from the game's own state before a dialogue starts.
func set_variable(variable_name: String, value: Variant) -> void:
	var id := dialogue.get_variable_id(variable_name)
	if id == "":
		push_error('LoreHub: the dialogue has no variable "%s".' % variable_name)
		return
	_set_value(id, _coerce(dialogue.get_variables()[id], value))


## Every story variable by name.
func get_variables() -> Dictionary:
	var result := {}
	var variables := dialogue.get_variables()
	for id in variables:
		result[str(variables[id].get("name", ""))] = _values.get(id)
	return result


## True once the player has been on the node (stateData.played).
func is_node_played(node_id: String) -> bool:
	return _played.has(_Dialogue.short_id(node_id))


## True once the player picked the option (stateData.selected).
func is_option_selected(option_id: String) -> bool:
	return _selected.has(_Dialogue.short_id(option_id))


## Variables back to their LoreHub defaults, no node played and no option selected.
func reset_state() -> void:
	_values.clear()
	_played.clear()
	_selected.clear()
	var variables := dialogue.get_variables()
	for id in variables:
		_values[id] = _parse_value(variables[id], str(variables[id].get("defaultValue", "")))


## Everything needed to continue later, as plain data for a save file: variables by name, played nodes,
## selected options and the current node.
func get_state() -> Dictionary:
	return {
		"variables": get_variables(),
		"played": _played.keys(),
		"selected": _selected.keys(),
		"node_id": _node_id if _running else "",
	}


## Restores what [method get_state] returned. When the saved dialogue was running, the runner is on that node
## again: call [method resume] to show it. Variables the save doesn't have keep their current values.
func set_state(state: Dictionary) -> void:
	var saved_variables: Dictionary = state.get("variables", {})
	for variable_name in saved_variables:
		var id := dialogue.get_variable_id(str(variable_name))
		if id != "":
			_values[id] = _coerce(dialogue.get_variables()[id], saved_variables[variable_name])
	_played.clear()
	for id in state.get("played", []):
		_played[str(id)] = true
	_selected.clear()
	for id in state.get("selected", []):
		_selected[str(id)] = true
	var node_id := str(state.get("node_id", ""))
	_running = node_id != "" and dialogue.has_node_id(node_id)
	_node_id = node_id if _running else ""


func _enter(node_id: String) -> void:
	var id := _Dialogue.short_id(node_id)
	if id == "" or not dialogue.has_node_id(id):
		_finish()
		return
	_node_id = id
	for change in dialogue.get_node_resource(id).get("setVariableOnStart", []):
		_apply_set_variable(change)
	_played[id] = true
	_present()


func _present() -> void:
	var node_id := _node_id
	line_started.emit(_build_line(node_id))
	# A handler may have chosen, advanced or stopped already.
	if not _running or _node_id != node_id:
		return
	if not dialogue.get_node_options(node_id).is_empty():
		choices_presented.emit(get_choices())


func _finish() -> void:
	_running = false
	_node_id = ""
	dialogue_finished.emit()


func _first_passing_link(from_id: String) -> String:
	for link in dialogue.get_links_from(from_id):
		if _failing(link.get("requiredVariables", [])).is_empty():
			return _Dialogue.short_id(link.get("to", ""))
	return ""


func _build_line(node_id: String) -> _Line:
	var line := _Line.new()
	line.node_id = node_id
	var texts: PackedStringArray = []
	for part in dialogue.get_node_content(node_id):
		if typeof(part) != TYPE_DICTIONARY:
			continue
		var document_id = part.get("documentId")
		var part_text = part.get("text")
		if document_id != null and str(document_id) != "":
			if line.speaker_id == "":
				line.speaker_id = str(document_id)
				line.speaker_name = (
					str(part_text)
					if part_text != null and str(part_text) != ""
					else dialogue.get_document_name(line.speaker_id)
				)
		elif part_text != null:
			texts.append(str(part_text))
	line.text = "\n".join(texts)
	var node := dialogue.get_node_resource(node_id)
	for entry in node.get("metaData", []):
		var schema := dialogue.get_meta_schema(str(entry.get("metaSchemaId", "")))
		if schema.is_empty():
			continue
		var value := str(entry.get("metaSchemaValue", ""))
		line.meta[str(schema.get("name", ""))] = value.to_int() if schema.get("schemaType", "") == "integer" else value
	line.has_options = not node.get("optionsIds", []).is_empty()
	return line


## Conditions that are not met; all of them must be met (AND).
func _failing(conditions: Variant) -> Array:
	var result: Array = []
	if typeof(conditions) != TYPE_ARRAY:
		return result
	for condition in conditions:
		if not _is_met(condition):
			result.append(condition)
	return result


func _is_met(condition: Dictionary) -> bool:
	var id := str(condition.get("variableId", ""))
	var expected := str(condition.get("value", ""))
	var kind := str(condition.get("kind", ""))
	var actual: Variant
	if kind == _Dialogue.NODE_PLAYED_KIND:
		actual = is_node_played(id)
	elif kind == _Dialogue.OPTION_SELECTED_KIND:
		actual = is_option_selected(id)
	else:
		actual = _values.get(id, false)
	var op := str(condition.get("operator", "=="))
	if typeof(actual) == TYPE_INT:
		var wanted := expected.to_int()
		match op:
			"!=":
				return actual != wanted
			"<":
				return actual < wanted
			"<=":
				return actual <= wanted
			">":
				return actual > wanted
			">=":
				return actual >= wanted
			_:
				return actual == wanted
	var matches: bool = bool(actual) == (expected.to_lower() == "true")
	return not matches if op == "!=" else matches


func _apply_set_variable(change: Dictionary) -> void:
	var id := str(change.get("variableId", ""))
	var variable: Dictionary = dialogue.get_variables().get(id, {})
	var value: Variant = _parse_value(variable, str(change.get("value", "")))
	var operation := str(change.get("operation", "set"))
	if typeof(value) == TYPE_INT and operation != "set":
		var current: int = _values.get(id, 0) if typeof(_values.get(id, 0)) == TYPE_INT else 0
		value = current + value if operation == "add" else current - value
	_set_value(id, _clamp(variable, value))


func _set_value(id: String, value: Variant) -> void:
	if _values.has(id) and typeof(_values[id]) == typeof(value) and _values[id] == value:
		return
	_values[id] = value
	var variable: Dictionary = dialogue.get_variables().get(id, {})
	variable_changed.emit(str(variable.get("name", id)), value)


static func _is_number(variable: Dictionary) -> bool:
	return variable.get("variableType", "boolean") in ["number", "unsignedNumber"]


static func _parse_value(variable: Dictionary, text: String) -> Variant:
	if _is_number(variable):
		return _clamp(variable, text.to_int())
	return text.to_lower() == "true"


static func _coerce(variable: Dictionary, value: Variant) -> Variant:
	if _is_number(variable):
		return _clamp(
			variable, int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL] else str(value).to_int()
		)
	if typeof(value) == TYPE_STRING:
		return value.to_lower() == "true"
	return bool(value)


static func _clamp(variable: Dictionary, value: Variant) -> Variant:
	if typeof(value) == TYPE_INT and variable.get("variableType", "") == "unsignedNumber":
		return maxi(value, 0)
	return value
