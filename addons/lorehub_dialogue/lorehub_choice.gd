class_name LoreHubChoice
extends RefCounted
## An option of the current node.

## Short id of the option.
var id := ""
## Text shown to the player.
var text := ""
## Position among the node's options, counted from 0, the order set in LoreHub.
var index := 0
## False when one of the option's conditions is not met. The runner hides such choices unless
## LoreHubRunner.hide_unavailable_choices is false.
var available := true
## Conditions that are not met, as in the export: variableId, value, optional operator and kind.
var failing_conditions: Array = []


func _to_string() -> String:
	return text
