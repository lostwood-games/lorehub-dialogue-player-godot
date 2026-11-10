extends SceneTree
## Headless tests of the runner against the rules of LoreHub's player.
## Run from the godot/ folder: godot --headless --path . -s res://tests/run_tests.gd

const Dialogue := preload("res://addons/lorehub_dialogue/lorehub_dialogue.gd")
const Runner := preload("res://addons/lorehub_dialogue/lorehub_runner.gd")

const N1 := "aaaaaaaa-0000-4000-8000-000000000001"
const N2 := "aaaaaaaa-0000-4000-8000-000000000002"
const N3 := "aaaaaaaa-0000-4000-8000-000000000003"
const N4 := "aaaaaaaa-0000-4000-8000-000000000004"
const N6 := "aaaaaaaa-0000-4000-8000-000000000006"
const O1 := "bbbbbbbb-0000-4000-8000-000000000001"
const O2 := "bbbbbbbb-0000-4000-8000-000000000002"
const O3 := "bbbbbbbb-0000-4000-8000-000000000003"

var _failures: Array[String] = []
var _checks := 0
var _test := ""


func _init() -> void:
	for method in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			_test = method_name
			call(method_name)
	if _failures.is_empty():
		print("LoreHub tests: %d checks passed." % _checks)
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		printerr("LoreHub tests: %d of %d checks failed." % [_failures.size(), _checks])
		quit(1)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL %s: %s" % [_test, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(
		typeof(actual) == typeof(expected) and actual == expected,
		"%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)]
	)


func load_tavern() -> Dialogue:
	return Dialogue.load_from_file("res://tests/tavern.json")


func ids(choices: Array) -> Array:
	return choices.map(func(c): return c.id)


func test_loads_the_export() -> void:
	var dialogue := load_tavern()
	check(dialogue != null, "the tavern export loads")
	check_eq(dialogue.get_dialogue_name(), "Tavern: Kael the barkeep", "dialogue name")
	check_eq(dialogue.get_start_node_id(), N1, "start node from the dialogue's link")
	check_eq(dialogue.get_node_ids().size(), 5, "node count")


func test_loads_every_source() -> void:
	var json_resource: JSON = load("res://tests/tavern.json")
	check(json_resource != null, "Godot loads the .json export as a JSON resource")
	check(Dialogue.from_source(json_resource) != null, "from a JSON resource")
	check(Dialogue.from_source("res://tests/tavern.json") != null, "from a path")
	check(Dialogue.from_source(json_resource.data) != null, "from a Dictionary")
	var runner := Runner.new(json_resource)
	runner.start()
	check_eq(runner.get_current_line().node_id, N1, "the runner takes the JSON resource directly")


func test_rejects_other_files() -> void:
	check(
		Dialogue.from_json_string('{"type":"@lorehub/export-schema","apiVersion":"3.0.0","resources":[]}') == null,
		"a newer major schema is refused"
	)
	check(Dialogue.from_json_string('{"type":"something-else"}') == null, "another JSON file is refused")
	check(Dialogue.from_json_string("not json") == null, "text that is not JSON is refused")
	check(
		Dialogue.from_json_string('{"type":"@lorehub/export-schema","apiVersion":"2.1.0","resources":[]}') != null,
		"a newer minor schema is read"
	)


func test_first_line_speaker_meta_and_variables() -> void:
	var runner := Runner.new(load_tavern())
	var lines: Array = []
	runner.line_started.connect(func(line): lines.append(line))
	runner.start()
	check_eq(lines.size(), 1, "one line on start")
	var line = lines[0]
	check_eq(line.node_id, N1, "starts on the first node")
	check_eq(line.speaker_name, "Kael", "speaker is the document name")
	check_eq(line.speaker_id, "ca2f5193-a3e0-41dd-830a-491132090d34", "speaker id")
	check_eq(line.text, "Back again, traveller?", "text")
	check_eq(line.meta.get("mood"), "grumpy", "text meta data")
	check_eq(line.meta.get("wait"), 2, "integer meta data is an int")
	check(line.has_options, "the first node has options")
	check_eq(runner.get_variable("met_kael"), true, "entering the node set met_kael")
	check_eq(runner.get_variable("gold"), 5, "gold starts at its default")
	check(runner.is_node_played(N1), "the node is played")


func test_custom_speaker_name_and_multi_part_text() -> void:
	var runner := Runner.new(load_tavern())
	runner.start(N2)
	check_eq(runner.get_current_line().speaker_name, "Barkeep", "custom name wins over the document name")
	runner.start(N3)
	check_eq(runner.get_current_line().text, "The road north is closed.\nHas been for a week.", "text parts joined")


func test_hidden_choices_and_state_conditions() -> void:
	var runner := Runner.new(load_tavern())
	var presented: Array = []
	runner.choices_presented.connect(func(choices): presented.append(choices))
	runner.start()
	check_eq(ids(presented[0]), [O2, O3], "the drink needs 10 gold and is hidden; short option ids work")
	runner.choose(presented[0][0])
	check(runner.is_option_selected(O2), "the picked option is selected")
	check_eq(runner.get_current_line().node_id, N3, "the option's link leads to Oliver")
	check_eq(runner.get_variable("trust"), 2, "trust added on entering")
	runner.advance()
	check_eq(runner.get_current_line().node_id, N1, "trust 2 fails the >= 3 link, the next link is followed")
	check_eq(ids(runner.get_choices()), [O3], "asking about the road is hidden once selected")
	var finished := [false]
	runner.dialogue_finished.connect(func(): finished[0] = true)
	runner.choose_id(O3)
	check(finished[0], "leaving without the secret has no passing link and ends the dialogue")
	check(not runner.is_running(), "not running after the end")


func test_full_route_with_gold() -> void:
	var runner := Runner.new(load_tavern())
	runner.set_variable("gold", 20)
	runner.start("", true)
	check_eq(ids(runner.get_choices()), [O1, O2, O3], "enough gold shows the drink")
	runner.choose_id(O1)
	check_eq(runner.get_variable("gold"), 10, "the drink subtracts 10 gold")
	check_eq(runner.get_variable("trust"), 1, "the drink adds trust")
	runner.advance()
	runner.choose_id(O2)
	check_eq(runner.get_variable("trust"), 3, "trust is 3 after the road")
	runner.advance()
	check_eq(runner.get_current_line().node_id, N4, "trust 3 passes the secret link")
	runner.advance()
	check_eq(ids(runner.get_choices()), [O1, O3], "10 gold still meets >= 10")
	runner.choose_id(O3)
	check_eq(runner.get_current_line().node_id, N6, "the secret was played, so leaving says goodbye")
	runner.advance()
	check(not runner.is_running(), "a node without links ends the dialogue")


func test_unavailable_choices_can_be_shown() -> void:
	var runner := Runner.new(load_tavern())
	runner.hide_unavailable_choices = false
	runner.start()
	var choices := runner.get_choices()
	check_eq(ids(choices), [O1, O2, O3], "all options when hidden ones are shown")
	check(not choices[0].available, "the drink is not available")
	check_eq(choices[0].failing_conditions.size(), 1, "one failing condition")
	runner.choose(choices[0])
	check_eq(runner.get_current_line().node_id, N1, "an unavailable choice can't be picked")


func test_unsigned_number_stays_at_zero() -> void:
	var runner := Runner.new(load_tavern())
	runner.set_variable("gold", 3)
	runner.start(N2, true)
	check_eq(runner.get_variable("gold"), 0, "subtracting 10 from 3 leaves 0")
	runner.set_variable("gold", -5)
	check_eq(runner.get_variable("gold"), 0, "set_variable can't make it negative either")


func test_variable_changed_signal() -> void:
	var runner := Runner.new(load_tavern())
	var changes := {}
	runner.variable_changed.connect(func(variable_name, value): changes[variable_name] = value)
	runner.start()
	check_eq(changes, {"met_kael": true}, "only changed variables are reported")


func test_state_round_trip() -> void:
	var runner := Runner.new(load_tavern())
	runner.start()
	runner.choose_id(O2)
	var state := runner.get_state()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state))
	var restored := Runner.new(load_tavern())
	restored.set_state(saved)
	check(restored.is_running(), "a saved running dialogue runs again")
	check_eq(restored.get_current_line().node_id, N3, "on the saved node")
	check_eq(restored.get_variable("trust"), 2, "number survives JSON as an int")
	check_eq(restored.get_variable("met_kael"), true, "bool survives")
	check(restored.is_option_selected(O2), "selected options survive")
	var lines: Array = []
	restored.line_started.connect(func(line): lines.append(line))
	restored.resume()
	check_eq(lines.size(), 1, "resume shows the line again")
	check_eq(restored.get_variable("trust"), 2, "resume doesn't apply the node's variables again")
	restored.advance()
	check_eq(ids(restored.get_choices()), [O3], "state conditions still read the restored selection")


func test_stop_from_a_handler() -> void:
	var runner := Runner.new(load_tavern())
	var presented := [false]
	runner.choices_presented.connect(func(_c): presented[0] = true)
	runner.line_started.connect(func(_line): runner.stop())
	runner.start()
	check(not runner.is_running(), "stopped")
	check(not presented[0], "no choices after stop() in line_started")


func test_later_reference_is_part_of_the_line_and_dialogue_name() -> void:
	var dialogue := Dialogue.from_data({
		"type": "@lorehub/export-schema",
		"apiVersion": "2.0.0",
		"resources": [
			{"type": "@lorehub/dialogue", "apiVersion": "2.0.0", "id": "dialogue/d1", "name": "Scene 01"},
			{"type": "@lorehub/document", "apiVersion": "1.0.0", "id": "doc-kael", "name": "Kael"},
			{"type": "@lorehub/document", "apiVersion": "1.0.0", "id": "doc-oliver", "name": "Oliver"},
			{"type": "@lorehub/dialogue-node", "apiVersion": "2.0.0", "id": "dialogue/d1/dialogue-node/n1", "contentBlockId": "n1"},
			{"type": "@lorehub/content-block", "apiVersion": "1.0.0", "id": "n1", "content": [
				{"documentId": "doc-kael", "text": null},
				{"text": "Have you seen"},
				{"documentId": "doc-oliver", "text": null},
				{"text": "today?"},
			]},
			{"type": "@lorehub/dialogue-link", "apiVersion": "1.0.0", "id": "dialogue/d1/dialogue-link/l1", "from": "dialogue/d1", "to": "dialogue/d1/dialogue-node/n1"},
		],
	})
	check_eq(dialogue.get_dialogue_name(), "Scene 01", "the dialogue name is read")
	var runner := Runner.new(dialogue)
	runner.start()
	var line := runner.get_current_line()
	check_eq(line.speaker_name, "Kael", "the first reference is the speaker")
	check_eq(line.text, "Have you seen\nOliver\ntoday?", "a later reference keeps its text in the line")
