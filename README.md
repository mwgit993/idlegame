# Udderly Idle (working title)

An idle game about milking a cow and growing a dairy empire, made in **Godot 4.7**, with bright, goofy cartoon art on a 640x360 layout that scales smoothly to any window and stays sharp up to 4K. On a big screen the window opens at about 80% of the screen. Everything is drawn or synthesized in code: the cow, the farm, the icons, the sound effects (a real-sounding moo and a squishy milking squeeze) and the bouncy barnyard background music. The only asset file is the font, [Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka) (SIL Open Font License, see `assets/fonts/OFL.txt`).

## How it plays
- **Milk the cow.** Click her (or press `Space`, or controller `X` from anywhere) to squeeze the udder. Every squeeze earns money, and her milk squirts into the pail under her. A full pail waits beside her until a little red wagon rolls up and collects it (every few seconds, or right away once two are waiting).
- **MOO RUSH.** Milking fills the pink meter. When it's full, everything earns **x3** for 12 seconds.
- **Dairy businesses.** Eight of them, from a Milk Pail Stand up to a Moon Cow Ranch. Click a business's icon to sell a batch; the bar fills and pays out. Buy more of each with the buttons on the right (`x1`, `x10`, `x100`, `NEXT` milestone, or `MAX`; `B` or controller `Y` cycles them). Owning 25, 50, 100, 200, 300 and 400 of a business doubles its speed; 500 and up double its profits.
- **Farmhands.** Hire one per business and it runs by itself, even while the game is closed. You'll be greeted with what they earned when you come back.
- **Upgrades.** One-time multipliers for a business, for everything, or for your squeezes.
- **Golden cowbells (prestige).** On the PASTURE tab, move to a bigger pasture: your farm resets, but you keep your cowbells and earn new ones from everything you've ever made. Each cowbell adds +2% profit.
- **The hen, the monkey and the bee.** At **20 golden cowbells** the hen house opens: click the hen and she lays eggs into her nest. She has her own egg businesses (an Egg Basket up to a Fancy Egg Museum), upgrades, farmhands, CLUCK RUSH and her own prestige, **golden eggs**. At **3 golden eggs** the banana grove opens: a monkey who picks bananas into a crate, with banana businesses (a Banana Tree up to Planet Banana), BANANA RUSH and **golden bananas**. At **3 golden bananas** the bee meadow opens: a bumblebee who flicks honey from her dipper into a jar, with honey businesses (a Honey Jar Stand up to the Honeymoon Hive), BUZZ RUSH and **golden honeypots**. The round buttons above the animal switch between them any time. Each animal has its own money and run, every animal's farmhands keep earning while you look at another one (and while the game is closed), and each golden item boosts its own animal by +2%.
- **Settings.** The gear at the right end of the top bar opens SETTINGS: windowed or fullscreen, music and sound volume (10% steps), how big numbers are written (`$1.500 BILLION`, `$1.50B` or `$1.500e9`), SAVE NOW, and DELETE, which asks "ARE YOU SURE?" before wiping your farm, cowbells and stats (your settings stay). Every change is saved.

The game saves every 10 seconds and when you close it.

## Controls
Mouse or touch: click or tap anything.

A controller or the arrow keys move a big gold selection ring around everything you can press: the animal and the buttons that switch animals, the tabs, the buy-amount buttons, each business's icon and buy button, upgrades, farmhands, the PASTURE button, the settings gear and both popups. Moving the mouse hides the ring; the next controller or arrow press brings it back where you left it.

| | Controller | Keyboard |
| --- | --- | --- |
| Move the selection | D-pad or left stick (one step per push; hold to repeat) | Arrow keys |
| Press the selected button | `A` | `Enter` |
| Milk the cow from anywhere | `X` | `Space` |
| Close the popup / jump back to the cow | `B` | `Esc` |
| Open / close settings | `Start` (`≡`) | |
| Fullscreen on / off | | `F11` |
| Cycle the buy amount | `Y` | `B` |
| Switch tabs | `LB` / `RB` | |

While the ring is hidden, `Enter` milks the cow like `Space`.

## Running it
```bash
godot --headless --path . --import                         # once, on a fresh clone
godot --path .                                             # play
godot --headless --path . --quit-after 30 -- --smoke-test  # automated check: must print UDDERLY_SMOKE_TEST_PASSED
```
The smoke test uses its own save file, so it never touches a real save.

`export_presets.cfg` has `Windows` and `SteamDeck` (Linux) presets.
