# LoreHub Dialogue for Godot

[![CI](https://github.com/lostwood-games/lorehub-dialogue-player-godot/actions/workflows/ci.yml/badge.svg)](https://github.com/lostwood-games/lorehub-dialogue-player-godot/actions/workflows/ci.yml)

Play dialogues written in [LoreHub](https://lorehub.app) in Godot 4.3 and later. The addon reads LoreHub's
[Export Schema v2](https://lorehub.app/documentation) and follows the same rules as the player in LoreHub: nodes,
options, links with conditions, number and boolean variables, played and selected state, and node meta data.

Pure GDScript: works in the standard and .NET builds of Godot and in every export target, web included. Open source
under MIT at [lostwood-games/lorehub-dialogue-player-godot](https://github.com/lostwood-games/lorehub-dialogue-player-godot).

## Sample project

Open the repo folder in Godot 4.3+ and press Play. `samples/tavern/` is a small game screen built on `LoreHubRunner`
with its own UI: a typewriter line with a speaker badge, choices, node meta data driving the scene (`mood` tints the
background, `wait` delays the line), gold buttons that feed game state into LoreHub variables, and save/load
mid-dialogue. `demo/` shows the drop-in `LoreHubDialogueBox`. Both play `demo/tavern.json`, a LoreHub export.

## Install

1. Copy `addons/lorehub_dialogue` into your project's `addons/` folder (or install it from the Godot Asset Store).
2. Enable **LoreHub Dialogue** in **Project > Project Settings > Plugins**.

## Get a dialogue from LoreHub

In LoreHub open the dialogue, click **Export** and **Export JSON**, and put the `.json` file in your project. Godot
loads `.json` files as `JSON` resources and packs them into exported games, so there is nothing to convert.

Files downloaded at runtime load too: `LoreHubDialogue.from_source("user://intro.json")` takes a path, a `JSON`
resource, a parsed Dictionary or JSON text.

## Play it

The quickest way is the sample dialogue box: instance `addons/lorehub_dialogue/ui/lorehub_dialogue_box.tscn` and call

```gdscript
$LoreHubDialogueBox.play(preload("res://dialogues/tavern.json"))
```

For your own UI, use the runner:

```gdscript
var runner := LoreHubRunner.new(preload("res://dialogues/tavern.json"))

func _ready() -> void:
	runner.line_started.connect(_on_line)          # LoreHubLine: speaker_name, speaker_id, text, meta, has_options
	runner.choices_presented.connect(_on_choices)  # Array of LoreHubChoice: id, text, index, available
	runner.dialogue_finished.connect(_on_finished)
	runner.set_variable("gold", PlayerData.gold)   # feed the game's state in by LoreHub variable name
	runner.start("", true)                         # true keeps the variable set above

func _on_line(line: LoreHubLine) -> void:
	label.text = "%s: %s" % [line.speaker_name, line.text]
	if line.meta.has("event"):                     # node meta data by name, ints for integer fields
		trigger(line.meta["event"])

func _on_choices(choices: Array) -> void:
	for choice in choices:
		add_button(choice.text, runner.choose.bind(choice))

# On Continue for a node without options:
func _on_continue() -> void:
	runner.advance()
```

### Rules

- Entering a node applies the variables it sets (number variables can be added to or subtracted from; an
  `unsignedNumber` never goes below 0) and marks it played.
- Options show in LoreHub's order. An option whose conditions fail is hidden; set `runner.hide_unavailable_choices =
  false` to get it with `available == false`, for example to grey it out.
- Picking an option marks it selected and follows its first link whose conditions all pass. `advance()` does the
  same with the links of a node without options. No passing link ends the dialogue.
- Conditions can check variables (`==`, `!=`, `<`, `<=`, `>`, `>=` for numbers) or whether a node was played or an
  option selected.

### Save and load

`runner.get_state()` returns a plain Dictionary (variables by name, played nodes, selected options, current node)
that you can store with your save. `runner.set_state(state)` puts it back; call `runner.resume()` to show the
current line again.

### From C#

The addon is GDScript, so call it through Godot's API:

```csharp
var script = GD.Load<GDScript>("res://addons/lorehub_dialogue/lorehub_runner.gd");
var runner = script.New(GD.Load<Resource>("res://dialogues/tavern.json")).AsGodotObject();
runner.Connect("line_started", Callable.From<GodotObject>(line => GD.Print(line.Get("text"))));
runner.Call("start");
```

## Demo and tests

Open this folder as a Godot project and run it to play `demo/tavern.json`. Tests run headless:

```sh
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```

## Versions

The addon's version follows the OSF schema version; 0.1.0 is the first build. It reads LoreHub's Export Schema 2.x
JSON today and refuses a file from an unknown major schema version with an error that says to update the addon.

## Releasing

1. Set the version in `addons/lorehub_dialogue/plugin.cfg`.
2. Add a section for it to `CHANGELOG.md`.
3. Push the tag `vX.Y.Z`. CI runs the tests, builds the zip, creates the GitHub release and writes the Asset Store
   fields in the job summary.
4. Upload the zip by hand in the asset's **Versions** tab on [store.godotengine.org](https://store.godotengine.org)
   (the store has no upload API yet).

MIT licensed. Made by [Lostwood Games](https://lorehub.app).
