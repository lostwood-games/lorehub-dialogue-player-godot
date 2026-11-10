@tool
class_name LoreHubDialogue
extends Resource
## A dialogue exported from LoreHub (Export Schema v2).
##
## Put the [code].json[/code] file from LoreHub's Export button in your project and pass it to [LoreHubRunner]:
## Godot loads [code].json[/code] files as [JSON] resources and packs them into exported games. [method from_source]
## also takes a path, a parsed Dictionary or JSON text, for files downloaded at runtime.
## Schema docs: https://lorehub.app/documentation

## Export Schema major version this addon reads.
const SUPPORTED_SCHEMA_MAJOR := 2
const SCHEMA_TYPE := "@lorehub/export-schema"

const NODE_PLAYED_KIND := "stateData.isNodePlayed"
const OPTION_SELECTED_KIND := "stateData.isOptionSelected"

## The export JSON as parsed. Kept as data so the resource saves and loads like any other.
@export var data: Dictionary = {}

var _indexed := false
var _dialogue_id := ""
var _dialogue_name := ""
var _start_node_id := ""
var _nodes := {}  # short id -> node resource
var _node_order: Array[String] = []
var _options := {}  # short id -> option resource
var _links_from := {}  # short id of the source -> Array of link resources, in export order
var _content := {}  # node short id -> content array
var _documents := {}  # document id -> name
var _variables := {}  # variable id -> variable resource
var _variable_ids := {}  # variable name -> variable id
var _meta_schema := {}  # meta schema id -> meta schema resource


## Parses an export. Returns null and pushes an error when the text is not a LoreHub Export Schema v2.
static func from_json_string(text: String) -> LoreHubDialogue:
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error(
			"LoreHub: the file is not valid JSON (line %d: %s)." % [json.get_error_line(), json.get_error_message()]
		)
		return null
	return from_data(json.data)


## Wraps a parsed export. Returns null and pushes an error when it is not a LoreHub Export Schema v2.
static func from_data(parsed: Variant) -> LoreHubDialogue:
	var problem := validate(parsed)
	if problem != "":
		push_error("LoreHub: " + problem)
		return null
	var dialogue := LoreHubDialogue.new()
	dialogue.data = parsed
	return dialogue


## A dialogue from whatever holds it: a LoreHubDialogue, a [JSON] resource such as
## [code]preload("res://dialogues/tavern.json")[/code], a [code]res://[/code] or [code]user://[/code] path, a parsed
## Dictionary or JSON text. Returns null and pushes an error when it is not a LoreHub export.
static func from_source(source: Variant) -> LoreHubDialogue:
	if source is LoreHubDialogue:
		return source
	if source is JSON:
		return from_data(source.data)
	if typeof(source) == TYPE_DICTIONARY:
		return from_data(source)
	if typeof(source) in [TYPE_STRING, TYPE_STRING_NAME]:
		var text := str(source)
		return from_json_string(text) if text.strip_edges().begins_with("{") else load_from_file(text)
	push_error("LoreHub: can't read a dialogue from %s." % [source])
	return null


## Loads an export from a file, such as [code]res://dialogues/intro.json[/code] or [code]user://[/code] downloads.
static func load_from_file(path: String) -> LoreHubDialogue:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LoreHub: can't open %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return null
	return from_json_string(file.get_as_text())


## Empty when [param parsed] is an export this addon can play, otherwise what is wrong with it.
static func validate(parsed: Variant) -> String:
	if typeof(parsed) != TYPE_DICTIONARY:
		return "the file is not a LoreHub export: its root is not a JSON object."
	if parsed.get("type", "") != SCHEMA_TYPE:
		return 'the file is not a LoreHub export: "type" is not "%s".' % SCHEMA_TYPE
	var version := str(parsed.get("apiVersion", ""))
	if version.get_slice(".", 0) != str(SUPPORTED_SCHEMA_MAJOR):
		return (
			"the export uses schema %s, this addon reads %d.x. Export again from LoreHub or update the addon."
			% [version, SUPPORTED_SCHEMA_MAJOR]
		)
	if typeof(parsed.get("resources")) != TYPE_ARRAY:
		return 'the export has no "resources" list.'
	return ""


## Last segment of a full id: "dialogue/a/dialogue-node/b" -> "b". Short ids come back unchanged.
static func short_id(id: Variant) -> String:
	var text := str(id)
	var slash := text.rfind("/")
	return text if slash == -1 else text.substr(slash + 1)


## Fully qualified id of the dialogue, "dialogue/<guid>".
func get_dialogue_id() -> String:
	_ensure_index()
	return _dialogue_id


func get_dialogue_name() -> String:
	_ensure_index()
	return _dialogue_name


## Short id of the first node, empty when the dialogue has no start link.
func get_start_node_id() -> String:
	_ensure_index()
	return _start_node_id


func has_node_id(node_id: String) -> bool:
	_ensure_index()
	return _nodes.has(short_id(node_id))


## Short ids of every node, in export order.
func get_node_ids() -> Array[String]:
	_ensure_index()
	return _node_order.duplicate()


func get_node_resource(node_id: String) -> Dictionary:
	_ensure_index()
	return _nodes.get(short_id(node_id), {})


## Option resources of a node, in the order LoreHub shows them.
func get_node_options(node_id: String) -> Array[Dictionary]:
	_ensure_index()
	var result: Array[Dictionary] = []
	var node: Dictionary = _nodes.get(short_id(node_id), {})
	for option_id in node.get("optionsIds", []):
		var option: Dictionary = _options.get(short_id(option_id), {})
		if not option.is_empty():
			result.append(option)
	return result


func get_option_resource(option_id: String) -> Dictionary:
	_ensure_index()
	return _options.get(short_id(option_id), {})


## Links leaving a node, an option or the dialogue, in export order.
func get_links_from(id: String) -> Array:
	_ensure_index()
	return _links_from.get(short_id(id), [])


## Content parts of a node: [code]{"text": ...}[/code] and speaker [code]{"documentId": ..., "text": ...}[/code].
func get_node_content(node_id: String) -> Array:
	_ensure_index()
	return _content.get(short_id(node_id), [])


func get_document_name(document_id: String) -> String:
	_ensure_index()
	return _documents.get(document_id, "")


## Variable resources by id.
func get_variables() -> Dictionary:
	_ensure_index()
	return _variables


func get_variable_id(variable_name: String) -> String:
	_ensure_index()
	return _variable_ids.get(variable_name, "")


func get_meta_schema(meta_schema_id: String) -> Dictionary:
	_ensure_index()
	return _meta_schema.get(meta_schema_id, {})


func _ensure_index() -> void:
	if _indexed:
		return
	_indexed = true
	var resources: Array = data.get("resources", [])
	for resource in resources:
		if typeof(resource) != TYPE_DICTIONARY:
			continue
		var id := str(resource.get("id", ""))
		match resource.get("type", ""):
			"@lorehub/dialogue":
				_dialogue_id = id
				_dialogue_name = str(resource.get("name", ""))
			"@lorehub/dialogue-node":
				_nodes[short_id(id)] = resource
				_node_order.append(short_id(id))
			"@lorehub/dialogue-node-option":
				_options[short_id(id)] = resource
			"@lorehub/dialogue-link":
				var from := short_id(resource.get("from", ""))
				if not _links_from.has(from):
					_links_from[from] = []
				_links_from[from].append(resource)
			"@lorehub/content-block":
				_content[short_id(id)] = resource.get("content", [])
			"@lorehub/document":
				_documents[id] = str(resource.get("name", ""))
			"@lorehub/variable":
				_variables[id] = resource
				_variable_ids[str(resource.get("name", ""))] = id
			"@lorehub/meta-schema":
				_meta_schema[id] = resource
	var start_links: Array = _links_from.get(short_id(_dialogue_id), [])
	if not start_links.is_empty():
		_start_node_id = short_id(start_links[0].get("to", ""))
