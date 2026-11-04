# LAAF

**A third-person survival horror game set in Hollowmere, a fog-bound town that marks outsiders.**

LAAF is a short, story-driven horror game for Windows and Linux, built in Godot 4.7. It plays like a PSX/PS2-era horror game, with fog, film grain, dither and low-poly models, and its interface is built to modern standards. Alex comes to Hollowmere looking for their missing sister Lucía. On the first night Alex is branded with the Veil's Eye. Five childhood friends serve the Veil and each one hunts a part of the town. Across three chapters of about 10 minutes each, Alex hides, fights, decides the fate of each hunter, and finally faces The Harvester.

| | |
|---|---|
| Genre | Third-person action / survival horror |
| Engine | Godot 4.7 (Forward+, Jolt physics), GDScript |
| Platforms | Windows (installer), Linux (tarball + install script) |
| Input | Keyboard & mouse first, gamepad supported |
| Languages | English, Spanish (text and subtitles) |
| Length | 3 chapters × ~10 min critical path (~30–45 min with optional content) |
| Rating target | Mature (horror, violence) |

## Documentation

| Document | What it covers |
|---|---|
| [docs/project-documentation.md](docs/project-documentation.md) | **Start here.** The full specification: overview, features, functional and non-functional requirements, use cases, architecture, glossary |
| [docs/design-planning/](docs/design-planning/mockups.html) | UI design planning (open in a browser): mockups, the design system, the navigation flow, the product vision |
| [PRODUCT.md](PRODUCT.md) | Product brief: users, purpose, principles, brand commitments |
| [DESIGN.md](DESIGN.md) | The design system as built: tokens, components, rules |
| [maps/docs/requirements.md](maps/docs/requirements.md) | Game design documents index (story, characters, map, gameplay, minigames, progression, chapters), in English and Spanish |

## Running the project

1. Install **Godot 4.7** (the editor, standard build).
2. Open `project.godot` in the editor (Import → select the folder).
3. Press **F5**. The game boots into the main menu (`maps/main_menu.tscn`).

Developer shortcuts (command line, after `--`):

```sh
godot --path . -- --chapter=2          # start at a chapter
godot --path . -- --step=marcus        # start at a mission step
godot --path . -- --mark=60            # start with the Mark at 60 %
godot --path . --language es           # force Spanish
```

The main menu's **DEV** tab offers the same jumps without the command line. Dev runs are never saved and never unlock achievements.

## Final report

After the story ends, a report shows the run's numbers and a closing line on how the player did. The text comes from Groq when a key is set, and otherwise from a built-in set. In development, set the key in the `GROQ_API_KEY` environment variable or in `user://groq_key.txt`. `installer/build.sh` packs that key into release builds through a gitignored file that it deletes afterwards. Never commit the key. Anyone who has a release can extract it, so use a key with limits you can afford and replace it if it's abused. With no key, the game makes no network calls.

To test the AI text without finishing the game, use **AI result** in the main menu's DEV tab. It makes up a random run, sends it to Groq and shows the report. If the call fails, the report says why.

## Tests

Headless test scenes live in `tests/` (`*_test.gd`). Run one with:

```sh
godot --headless --path . --script tests/save_test.gd
```

They cover the chapters, combat, saving, the inventory, the menus' mouse handling, localization, minigames and more.

## Building the installers

```sh
installer/build.sh        # needs Godot 4.7 export templates; makensis for the Windows installer
```

This produces `build/LAAF-<version>-windows-setup.exe` and `build/LAAF-<version>-linux.tar.gz`.

## Project layout

```
maps/        scenes (main menu, the town Hollowmere) and the design docs (maps/docs)
player/      the player controller, weapons, HUD, weapon wheel, screen effects, minimap
scripts/     game flow (game.gd), chapter directors, enemies, menus, minigames, settings, audio
shaders/     the PS2 post-process, the menu CRT pass, pause blur, wheel grey
ui/icons/    rendered item icons used by the HUD, the wheel and the inventory
fonts/       IM Fell English and Barlow Semi Condensed (OFL)
locale/      translations (laaf.pot, es.po) and the glossary
models/, audio/, Characters_psx_02/   art and sound assets
tools/       asset build scripts (Blender/Python), screenshot and icon renderer, l10n tooling
tests/       headless tests
installer/   export and installer scripts
```
