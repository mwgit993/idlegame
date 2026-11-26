# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Udderly Idle is a Godot 4.7 (GDScript) idle/clicker game: milk a cow, build dairy businesses, hire farmhands, prestige with golden cowbells. Gameplay is described in `README.md`. The style follows Matthew's other game, Star Viper (`mwgit993/spacegame`): everything generated in code, strict static typing, pixel art at an integer scale, a headless smoke test.

## Commands

`godot` means the Godot 4.7.x editor binary.

```bash
godot --headless --path . --import                         # once on a fresh clone
godot --headless --path . --quit-after 30 -- --smoke-test  # must print UDDERLY_SMOKE_TEST_PASSED with zero script errors
godot --path .                                             # play
```

The smoke test (`_run_smoke_test` in `scripts/main.gd`) drives the economy and every tab by calling methods directly, checks the results with `_check`, and exits 1 on any failure. It points `Farm.save_path` at `user://smoke_test_save.json`, so real saves are safe. If you add a business, upgrade kind or tab, extend it.

## Code conventions

- Explicit static types everywhere. Don't use `:=` when the right-hand side is a `Variant` (a Dictionary lookup or an untyped Array element); cast instead, e.g. `float(b["cost"])`.
- A ternary (`a if c else b`) or `.filter()` produces an untyped Array; assigning that to an `Array[int]` / `Array[Dictionary]` variable fails at runtime. Use an `if` or a loop.
- The whole UI is built in code in `main.gd` with literal pixel coordinates on a 640x360 canvas. `scenes/main.tscn` is just a `Node2D` with `main.gd`.
- Text uses the bitmap font at `font_size = 10` (or 20 for the money counter). Texture filtering is nearest-neighbour.
- `game_data.gd` and `num_fmt.gd` are loaded with `preload` constants (`Data`, `Fmt`), not `class_name`, so a fresh clone doesn't need an import step to resolve them.

## Architecture

Autoloads, in load order:

| Autoload | Role |
| --- | --- |
| `Farm` (`scripts/autoload/farm.gd`) | All game state and economy: money, businesses, farmhands, upgrades, MOO RUSH, golden cowbells, offline earnings, save/load (`user://udderly_save.json`, autosave every 10 s and on quit). |
| `Art` (`scripts/autoload/pixel_art.gd`) | Paints every sprite into an `Image` at startup. `Art.tex("name")`; unknown names warn and fall back to the coin. |
| `Sfx` (`scripts/autoload/sfx.gd`) | Synthesizes the sound effects into `AudioStreamWAV`s. `Sfx.play("name")`; unknown names are silently ignored. |

- **Balance data** is all in `scripts/game_data.gd`: `BUSINESSES` (cost, growth, revenue, cycle time, farmhand), `UPGRADES` (kinds `biz`, `all`, `click`, `click_share`), milestones, MOO RUSH and cowbell constants. Change numbers there, not in `farm.gd`.
- **Economy rules** (in `farm.gd`): the next unit of a business costs `cost * growth^owned`; one cycle pays `revenue * owned * profit_mult * rush_mult`; `cycle_time` halves at each speed milestone. Without a farmhand a cycle must be started by clicking the business and stops after paying; with one it loops forever and catches up multiple cycles per frame when cycles get very short. Offline earnings pay `idle_income_per_sec() * seconds away` (farmhand-run businesses only, no MOO RUSH).
- **Prestige:** `bells_for_total(total_earned) = floor(BELL_SCALE * sqrt(total / BELL_UNIT))`. `move_pasture()` grants the difference, then `reset_pasture()` (keeps bells and lifetime stats).
- **UI** (`main.gd`): the left panel is the farm and the cow (a flat Button over the cow sprite calls `_on_squeeze`); the right panel has four pages (`Tab.DAIRY`, `UPGRADES`, `FARMHANDS`, `PASTURE`), each a `Control` toggled by `_set_tab`. `_process` calls `Farm.tick(delta)` and then `_refresh_all()`, which only refreshes the visible page. Progress bars, the MOO RUSH meter and the milk drops / floating "+$" texts are drawn with `draw.connect(...)` callbacks.
- Money is a `float` (64-bit), so it goes far past what an `int` can hold; `num_fmt.gd` names big numbers up to duodecillion.

## Adding content

- **Business:** add an entry to `Data.BUSINESSES` (with a farmhand), an icon `icon_<id>` in `Art._build_all`, and check the dairy and farmhands pages still fit (8 rows of 38 px fill the panel; a 9th needs scrolling).
- **Upgrade:** add to `Data.UPGRADES`. The upgrades page lists the 7 cheapest not yet bought.
