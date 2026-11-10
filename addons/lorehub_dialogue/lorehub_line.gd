class_name LoreHubLine
extends RefCounted
## The node the player is on: who speaks, what they say, and the node's meta data.

## Short id of the dialogue node.
var node_id := ""
## Name shown for the speaker: the custom name set on the line, else the character's document name. Empty when
## the node has no speaker.
var speaker_name := ""
## Id of the speaker's LoreHub document (the character), empty when the node has no speaker.
var speaker_id := ""
## The line's text, its parts joined by new lines.
var text := ""
## Meta data of the node by meta schema name: int for integer fields, String for text fields.
var meta := {}
## True when the node has options for the player to pick from.
var has_options := false


func _to_string() -> String:
	return "%s: %s" % [speaker_name, text] if speaker_name != "" else text
