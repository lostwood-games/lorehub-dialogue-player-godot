# Changelog

All notable changes to LoreHub Dialogue Player for Godot. The version follows the OSF schema version. Each release
copies its section into the GitHub release notes and the Godot Asset Store changelog.

## 0.0.0

First build.


- Plays dialogues from LoreHub's JSON export (Export Schema v2) by the same rules as the player in LoreHub: options,
  links with conditions, number and boolean variables, played and selected state, node meta data.
- `LoreHubRunner` with signals for lines, choices, variable changes and the end of a dialogue; save and load with
  `get_state()` / `set_state()`.
- Loads a `.json` export as a Godot `JSON` resource, from a path, a Dictionary or JSON text.
- Sample `LoreHubDialogueBox` scene, demo and headless tests. Godot 4.3 and later, standard and .NET builds.
