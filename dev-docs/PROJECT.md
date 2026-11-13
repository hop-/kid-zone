# Kid Zone — architecture

## Purpose and scope

A small, extendable educational game for young kids, played mostly by touch on
tablets and also with a mouse on desktops. It has:

- **Math** mode with two games on one shared equation layout
  (`MathEquationGame`), each with countable objects above its numbers:
  - `math_addition`, "add": `a + b = ?`, levels easy (`max_sum` 5), medium
    (`max_sum` 10) and hard (`max_addend` 12, `min_sum` 11)
  - `math_subtraction`, "minus": `a - b = ?` with a objects above `a` and b above
    `b`, b ≥ 1 and an answer ≥ 0; levels easy (`max_minuend` 5), medium
    (`max_minuend` 10) and hard (`min_minuend` 8, `max_minuend` 12)
- **Words** mode with `word_missing_letter`: a picture and its 3- or 4-letter
  English word with one blank and four letter choices. The 40 words are mixed at
  random, and are shown in UPPERCASE (default) or lowercase.
- generated sound effects with a remembered sound toggle, a remembered `ABC`/`abc`
  letter-case toggle, a music-ready audio layer (no tracks yet), and English-only
  but localization-ready content

The game has no music tracks, other languages or language picker, voice-over,
profiles or saved progress (only settings are saved), Web export, iOS `.ipa`
builds, or network access of any kind.

## Architecture

```
main.tscn (Main: ScreenHost + Fade)  ──attach──►  Router (autoload)
                                                    │ go_to / back / home
   MainMenu ─► ModeMenu ─► LevelSelect ─► GameShell ─► RoundEnd
                         (only for games    │
                          with levels)      ├─ instances the catalog game scene (a MiniGame)
                                            ├─ RoundController (pure logic)
                                            └─ StarBar, BackButton, input blocker

math_addition    ─┐ extend MathEquationGame ─► AdditionGenerator     (pure logic,
math_subtraction ─┘ (games/math_common)      ─► SubtractionGenerator   injected RNG)
word_missing_letter ─────────────────────────► MissingLetterGenerator
every game: answer buttons in a ChoiceRow; generators share QuestionUtils

Autoloads: Settings → Content → Art → Audio → Router
```

- **Data-driven catalog.** `content/catalog.json` lists the modes, each mode's
  games, each game's scene, round length, optional `levels`, and default `params`.
  The menus are built only from it.
- **Logic and view are separate.** Question generators and `RoundController` are
  `RefCounted` classes that take an injected `RandomNumberGenerator`. They don't use
  scenes or autoloads, so they are deterministic and unit-testable. Game scenes
  only present questions and report taps.
- **GameShell owns the round.** Every game gets the top bar (back button and star
  bar), sounds, input locking, stars and round end for free.
- **Shared game parts.** `ChoiceRow` (`ui/choice_row.gd`) is every game's row of
  answer buttons. `QuestionUtils` (`core/question_utils.gd`) holds the static
  shuffle, number-choice and letter-distractor rules that the generators and
  `Content` validation use. `MathEquationGame` (`games/math_common/`) is the view of
  both math games; each one only supplies its generator and operator sign. See
  [adding-a-game.md](adding-a-game.md).

## Autoloads and their order

Registered in `project.godot` `[autoload]`, in this order. Each one depends only on
the ones before it.

| # | Name | File | Role |
|---|------|------|------|
| 1 | `Settings` | `autoload/settings.gd` | Loads `user://settings.cfg` (`DEFAULT_PATH`): `sfx_on`, `music_on`, `sfx_volume_db`, `music_volume_db`, `locale`, `letter_case`. Setting a property applies it to the buses, saves and emits `changed`. `display_text(text)` applies the letter case. First, so `Content` sees `locale`. |
| 2 | `Content` | `autoload/content.gd` | Loads every JSON file under `res://content`, resolves the word pack for `Settings.locale` (fallback `en`), and pushes an error for each `validate()` problem without failing startup. |
| 3 | `Art` | `autoload/art.gd` | `sprite(id)`, `font()`, `theme()`, `theme_color(role)`, `bevel_style(...)`. Sets the theme and clear color on the root window. Reads `Content`. |
| 4 | `Audio` | `autoload/audio.gd` | `play_sfx(id, pitch_scale := 1.0)` on a pool of 6 players on the `SFX` bus; `play_music(id, fade)` / `stop_music(fade)` on the `Music` bus. Synthesizes every sound on startup. Reads `Content`. |
| 5 | `Router` | `autoload/router.gd` | Screen stack, stepped fade, back handling. Plays `back` through `Audio`. |

The buses (`Master`, `SFX`, `Music`) are in `default_bus_layout.tres`.

`Content`, `Art`, `Audio` and `Settings` can also be made as separate instances
(`preload("res://autoload/<name>.gd").new()`) with a fixture root, override folder
or temp settings path. Tests use that; see
[testing-and-export.md](testing-and-export.md).

## Startup and screen flow

1. `main.gd` reads the user args after `--`. With `--smoke-test` it runs the smoke
   check and quits. Otherwise it calls `Router.attach($ScreenHost, $Fade)`, then
   `Router.home()`, or builds the stack for `--open` / `--screen`.
2. `Router` keeps a stack of `{id, params}` entries. Only the top screen exists;
   `back()` rebuilds the previous one from its saved params. A screen's root
   script receives its params in `setup_screen(params)`, called before it enters
   the tree.

| Screen id | Scene | Params |
|-----------|-------|--------|
| `main_menu` | `screens/main_menu.tscn` | none: title, one tile per catalog mode (sized to fit), case and sound toggles |
| `mode_menu` | `screens/mode_menu.tscn` | `mode_id`: one tile per game of the mode |
| `level_select` | `screens/level_select.tscn` | `game_id`: one tile per level, with 1–3 stars |
| `game` | `core/game_shell.tscn` | `game_id`, `level_id` (`""` without levels), optional `seed` |
| `round_end` | `screens/round_end.tscn` | `game_id`, `level_id`, `stars` |

- A game without `levels` opens straight from the mode menu with `level_id` `""`.
- `GameShell` opens round end with `replace = true`, so round end takes the game's
  place on the stack. "again" reopens the game in round end's place, and back from
  round end returns to level select (or the mode menu). "home" calls
  `Router.home()`.
- Back requests: the on-screen `BackButton`, `ui_cancel` (Esc), and Android back
  (`NOTIFICATION_WM_GO_BACK_REQUEST`, with `application/config/quit_on_go_back=false`).
  `back()` on the main menu does nothing, so kids can't leave by accident.
- Transitions fade to palette black in 4 alpha steps out and 4 in, 0.2 s in all
  (`Router.fade_duration`). The `Fade` rect blocks input while it runs, and calls
  made during a transition are ignored, so a double tap opens one screen.

## The round loop (`core/game_shell.gd`)

1. Look up the game in the catalog, instance its scene into `GameSlot`, connect
   `choice_made`, and call `setup(Content.merged_params(game_id, level_id), rng)`.
   The RNG is seeded with the `seed` param, or `randi()` without one.
2. `RoundController.start(Content.round_length(game_id))` (catalog, default 10).
3. For each question: `next_question()` → `present(question)` → unlock → wait for
   `choice_made(value)` → lock → `RoundController.submit(correct)`.
   - Wrong: the `wrong` sound and `show_wrong(value)`, then unlock. No limit on
     tries.
   - Correct: the `correct` sound, a gold (first try) or silver star in the star
     bar, and `show_correct()`. The next question comes about 0.8 s
     (`NEXT_DELAY`) after the tap.
4. After `round_length` questions: `Router.go_to("round_end", {...}, true)`. Round
   end reveals the stars one by one with rising `tap` pitches, then plays
   `fanfare`.

Input to the game is blocked by an `InputBlocker` control from every tap until
its feedback has finished. The back button stays live. Answers match by value for
numbers (JSON numbers can be floats), otherwise by type and value.

## Display and input

- `project.godot`: 320×180 viewport, `stretch/mode="viewport"`, `aspect="expand"`,
  `scale_mode="integer"`, nearest texture filter, a 1280×720 desktop window, sensor
  landscape on mobile. On 4:3 and 16:10 screens the view gets taller (for example
  320×240 at 1024×768), and the layouts spread the extra height between their rows.
  Integer scaling can leave black bars, which is accepted.
- Touch and mouse share one path: Godot emulates the mouse from touch
  (`emulate_mouse_from_touch=true`, `emulate_touch_from_mouse=false`), and every
  button is a `KidButton` (`ui/kid_button.gd`). It plays `tap` on press, acts on
  release (dragging off cancels), takes no keyboard focus, and can grow its hit area
  with `touch_margin`. The 24×24 back button, sound toggle and case toggle use a
  4 px margin to reach 32×32. Nothing depends on hover.
- Font sizes are 9, 18 and 27 only (`Art.FONT_SMALL/MEDIUM/LARGE`; theme variations
  `LabelMedium`, `LabelLarge`, `ButtonMedium`, `ButtonLarge`), because the bitmap font
  scales by whole pixels.
- Headless runs don't scale touch or mouse coordinates to the 320×180 view. Check
  touch layout in a windowed run.

## Settings

`user://settings.cfg` is a `ConfigFile` with a `[settings]` section. On Linux it's
`~/.local/share/godot/app_userdata/Kid Zone/settings.cfg`. The autoload writes it
only when a setting changes. Missing or wrong-typed values fall back to
`Settings.DEFAULTS`. Any debug option (`--smoke-test`, `--open`, `--screen`) sets
`Settings.path = ""`, so nothing is saved during that run.

| Key | Default | Set by |
|-----|---------|--------|
| `sfx_on` | `true` | the speaker toggle on the main menu (`ui/sound_toggle.gd`) |
| `music_on`, `sfx_volume_db`, `music_volume_db` | `true`, `0.0`, `0.0` | code only, no UI yet |
| `locale` | `en` | code only (the word pack) |
| `letter_case` | `upper` | the `ABC`/`abc` toggle left of the speaker (`ui/case_toggle.gd`); `upper` or `lower`, anything else falls back to `upper` |

`locale` picks the word pack only. UI text follows Godot's translation locale (the
OS locale, falling back to `en`). There's no language picker, and changing
`Settings.locale` at runtime doesn't reload `Content`. `letter_case` changes only
how the word game shows its word and letter buttons; the content and the answers
stay lowercase. See [content-and-localization.md](content-and-localization.md).

## Key design decisions

- **An explicit catalog instead of scanning folders**: file names change in exports,
  so `DirAccess` listings aren't reliable there. Only the test runner scans a folder,
  and tests never ship.
- **JSON content, with `include_filter="*.json"`** on every export preset, and a
  smoke test of the exported binary (`make smoke-export`) that proves it's packed.
- **Retry until correct**, with gold and silver stars and no failure state.
- **Distractor letters are checked** against the pack and `known_words`, so exactly
  one letter makes a real word.
- **No add-ons.** The test runner is a small custom scene.

## Topic docs

- [adding-a-game.md](adding-a-game.md): the `MiniGame` contract and the catalog
- [content-and-localization.md](content-and-localization.md): content files,
  validation, words and languages
- [art-and-audio.md](art-and-audio.md): sprites, palette, font, sounds, music, icon
- [testing-and-export.md](testing-and-export.md): tests, smoke checks, screenshots,
  exports
