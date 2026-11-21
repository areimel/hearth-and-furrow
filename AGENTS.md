# Agent guidelines

Hearth & Furrow is a Godot 4.6 (GDScript) cozy Tudor farming sim. Read **`CLAUDE.md`** first: it is the
source of truth for commands, architecture, conventions and gotchas, and applies to every agent and
human, not only Claude. **`docs/contracts.md`** is the API reference; `docs/mvp-roadmap.md` tracks scope.
This file only repeats the rules that must never be missed.

- **Never push.** `origin` is the upstream course repo. Work on a branch or worktree, never on `main`.
- **Run `tools/check.sh --full`** (Godot is at `~/.local/share/godot/4.6/godot`, not on `PATH`) and get `OK`
  before committing. `godot --check-only --script` does not work with autoloads.
- Typed GDScript, tabs, scripts under 300 lines, content as data in `data/*.gd` (ids are `StringName`),
  no colour or font overrides in scripts (theme type variations only), tests extend `TestCase`.
- Keep `.uid` / `.import` files with their assets. Every shipped asset needs a row in `ASSET_LICENSES.md`.
- Do not use Mana Seed or new Sprout Lands art. Never name any TV series, broadcaster or presenter.
- Do not duplicate guidance here: change `CLAUDE.md` or `docs/contracts.md` instead.
