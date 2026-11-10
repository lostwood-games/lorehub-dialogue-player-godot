# LoreHub Dialogue for Godot

[![CI](https://github.com/lostwood-games/lorehub-dialogue-player-godot/actions/workflows/ci.yml/badge.svg)](https://github.com/lostwood-games/lorehub-dialogue-player-godot/actions/workflows/ci.yml)

Play dialogues written in [LoreHub](https://lorehub.app) in Godot 4.3 and later. The addon reads LoreHub's
[Export Schema v2](https://lorehub.app/documentation/dialogue-schema-api/export-schema-v2) and follows the same rules as the player in LoreHub: nodes,
options, links with conditions, number and boolean variables, played and selected state, and node meta data.

Pure GDScript: works in the standard and .NET builds of Godot and in every export target, web included. Open source
under MIT at [lostwood-games/lorehub-dialogue-player-godot](https://github.com/lostwood-games/lorehub-dialogue-player-godot).

**Guide with screenshots: [Dialogue System for Godot](https://lorehub.app/documentation/tutorials/dialogue-system-for-godot)** in the LoreHub docs. It covers installing,
exporting from LoreHub, the drop-in dialogue box, building your own UI on `LoreHubRunner`, the playback rules, save
and load, and C#.

## Quick start

1. Install **LoreHub Dialogue Player** from the Asset Store tab in the Godot editor (search for LoreHub), or copy
   `addons/lorehub_dialogue` into your project's `addons/` folder.
2. Turn on **LoreHub Dialogue** in **Project > Project Settings > Plugins**.
3. In LoreHub open the dialogue, go to **Export** and click **Export JSON**. Put the `.json` file anywhere under
   `res://`: Godot imports it as a `JSON` resource, so there is nothing to convert.
4. Add `addons/lorehub_dialogue/ui/lorehub_dialogue_box.tscn` to a scene, drag the `.json` onto its **Dialogue**
   property and turn on **Autostart**. Or play it from code:

```gdscript
$LoreHubDialogueBox.play(preload("res://dialogues/tavern.json"))
```

For your own UI, `LoreHubRunner` emits `line_started`, `choices_presented` and `dialogue_finished`, takes the
player's pick with `choose()` and `advance()`, and saves with `get_state()` / `set_state()`. See the
[guide](https://lorehub.app/documentation/tutorials/dialogue-system-for-godot).

## Sample project

Open the repo folder in Godot 4.3+ and press Play. `samples/tavern/` is a small game screen built on `LoreHubRunner`
with its own UI: a typewriter line with a speaker badge, choices, node meta data driving the scene (`mood` tints the
background, `wait` delays the line), gold buttons that feed game state into LoreHub variables, and save/load
mid-dialogue. `demo/` shows the drop-in `LoreHubDialogueBox`. Both play `demo/tavern.json`, a LoreHub export.

## Demo and tests

Open this folder as a Godot project and run it to play `demo/tavern.json`. Tests run headless:

```sh
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```

## Versions

The addon's version follows the OSF schema version; 0.0.0 is the first build. It reads LoreHub's Export Schema 2.x
JSON today and refuses a file from an unknown major schema version with an error that says to update the addon.

## Releasing

1. Set the version in `addons/lorehub_dialogue/plugin.cfg`.
2. Add a section for it to `CHANGELOG.md`.
3. Push the tag `vX.Y.Z`. CI runs the tests, builds the zip, creates the GitHub release and writes the Asset Store
   fields in the job summary.
4. Upload the zip by hand in the asset's **Versions** tab on [store.godotengine.org](https://store.godotengine.org)
   (the store has no upload API yet).

MIT licensed. Made by [Lostwood Games](https://lorehub.app).
