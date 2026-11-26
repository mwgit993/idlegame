# Udderly Idle (working title)

An idle game about milking a cow and growing a dairy empire, made in **Godot 4.7** (640x360 pixel art, integer-scaled). Everything is generated in code at startup: the cow, the farm, the icons, the sound effects (including a real-sounding moo and a squishy milking squeeze) and the bouncy barnyard background music. The only asset file is the font.

## How it plays
- **Milk the cow.** Click her (or press `Space` / `Enter` / controller `A`) to squeeze the udder. Every squeeze earns money.
- **MOO RUSH.** Milking fills the pink meter. When it's full, everything earns **x3** for 12 seconds.
- **Dairy businesses.** Eight of them, from a Milk Pail Stand up to a Moon Cow Ranch. Click a business's icon to sell a batch; the bar fills and pays out. Buy more of each with the buttons on the right (`x1`, `x10`, `x100`, `NEXT` milestone, or `MAX`; `B` cycles them). Owning 25, 50, 100, 200, 300 and 400 of a business doubles its speed; 500 and up double its profits.
- **Farmhands.** Hire one per business and it runs by itself, even while the game is closed. You'll be greeted with what they earned when you come back.
- **Upgrades.** One-time multipliers for a business, for everything, or for your squeezes.
- **Golden cowbells (prestige).** On the PASTURE tab, move to a bigger pasture: your farm resets, but you keep your cowbells and earn new ones from everything you've ever made. Each cowbell adds +2% profit.

The game saves every 10 seconds and when you close it.

## Running it
```bash
godot --headless --path . --import                         # once, on a fresh clone
godot --path .                                             # play
godot --headless --path . --quit-after 30 -- --smoke-test  # automated check: must print UDDERLY_SMOKE_TEST_PASSED
```
The smoke test uses its own save file, so it never touches a real save.

`export_presets.cfg` has `Windows` and `SteamDeck` (Linux) presets.
