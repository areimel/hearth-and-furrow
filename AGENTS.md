# Repository Guidelines

## Project Structure & Module Organization

This is a Godot 4.6 farming simulation using GDScript and the Forward+ renderer. Open `project.godot`; the main scene is `scenes/levels/level.tscn`.

- `scripts/`: active gameplay code, organized into `characters/`, `objects/`, `machines/`, `ui/`, `vfx/`, and `global/`.
- `scenes/`: corresponding `.tscn` scenes; keep scene connections aligned with their scripts.
- `scripts/global/`: `Data` and `Enum` autoloads configured in `project.godot`.
- `graphics/`, `audio/`, `shaders/`, and `resources/`: artwork, sound, shader effects, and resource definitions.
- `premade/`: course starter material; `readme_assets/`: documentation images.

Check scene references before editing similarly named files: root `global/`, root `mouse.gd`, and `scenes/characters/player.gd` are legacy duplicates.

## Build, Test, and Development Commands

Use a Godot 4.6 executable on your PATH as `godot`, or substitute its absolute path. Run from the repository root:

- `godot --path . --editor`: open the project editor.
- `godot --path .`: launch the game.
- `godot --path . --headless --import`: import assets and refresh the local cache.
- `godot --path . --headless --export-release "Windows Desktop"`: build using the configured Windows preset; install matching export templates first. A `Web` preset is also available.

## Coding Style & Naming Conventions

Use UTF-8, tab indentation, and the surrounding GDScript style. Prefer `snake_case` for new files, functions, and variables, and `UPPER_SNAKE_CASE` for constants. Use type annotations where practical. No formatter or linter is configured.

Preserve node paths, signal connections, and enum ordering. Update corresponding `Data` dictionaries when adding enum members. Move assets through Godot to preserve references and retain associated `.uid` and `.import` metadata. Exclude generated `.godot/`, exports, and new editor temporary files.

## Testing Guidelines

No automated testing framework or coverage threshold is configured. Validate changes in Godot and check the debugger for errors. Exercise affected farming, fishing, shop, building, and day-transition flows; check keyboard and gamepad input when changing controls. Record reproduction steps and observed results in the PR.

## Commit & Pull Request Guidelines

History uses short descriptive subjects such as `Update README.md`. Use imperative subjects and focused commits.

PRs should explain the behavior change, link relevant issues, list manual checks, and include screenshots or clips for visual changes. Preserve asset credits and licensing information when adding media.
