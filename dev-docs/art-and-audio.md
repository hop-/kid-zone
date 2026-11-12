# Art and audio

Every sprite, the pixel font and every sound effect are built at runtime from JSON
in `content/`. Each one can be replaced by a file in `assets/` with no code change.
The `assets/sprites/`, `assets/sfx/` and `assets/music/` folders don't exist yet;
create one when the first file goes in. `make` re-imports and re-exports when
anything under `assets/` changes.

## Palette (`content/palette.json`)

16 colors keyed by one character, `0`–`9` and `a`–`f`, each with a name. `.` is
transparent (`"transparent": "."`).

| Key | Name | Key | Name |
|-----|------|-----|------|
| `0` | black | `8` | dark_green |
| `1` | dark_grey | `9` | sky |
| `2` | silver | `a` | blue |
| `3` | white | `b` | navy |
| `4` | red | `c` | purple |
| `5` | orange | `d` | pink |
| `6` | yellow | `e` | brown |
| `7` | green | `f` | tan |

- Code asks for colors by name (`Content.color("green")`) or by UI role
  (`Art.theme_color("highlight")`). The roles map to names in `Art.THEME_COLORS`
  (`autoload/art.gd`): background navy, text white, buttons white, highlight and
  gold yellow, silver silver, and so on. A recolor is an edit there or in the
  palette.
- Tile colors come from each mode's `color` in `catalog.json`.
- `project.godot`'s `default_clear_color` is the navy background. `Art` also sets
  the clear color from the palette on startup, so keep the two in step.

## Sprites (`content/sprites/*.json`)

```json
{ "sprites": {
    "apple": { "size": [12, 12], "rows": ["....00......", "...0110.....", "..."] }
} }
```

- One string per pixel row, one character per pixel: a palette key or `.`. There
  are `size[1]` rows of `size[0]` characters. Keep one row per line, so the grid
  stays editable.
- Sprite ids are unique across all files. The files are grouped by use:

| File | Sprites | Size |
|------|---------|------|
| `icons.json` | `icon_math`, `icon_words`, `icon_addition`, `icon_missing_letter`, `icon_sound_on`, `icon_sound_off`, `icon_back`, `icon_star_empty`, `icon_star_gold`, `icon_star_silver`, `icon_again`, `icon_home` | 16×16 |
| `icons.json` | `app_icon` (the source of `icon.svg`) | 32×32 |
| `objects.json` | apple, banana, cherry, strawberry, carrot, tomato, corn, pepper, ball, teddy, duck, block | 12×12 |
| `words.json` | `word_<id>` for each of the 20 words | 24×24 |

  `Content` also reads `sprites/ui.json` if it exists; v1 doesn't need one.
- `Art.sprite(id)` builds the texture with `core/sprite_builder.gd` and caches it.
  Textures use nearest filtering (the project default). Mode, game and round-end
  tile icons are drawn at 2×, level-tile stars at 1×, word pictures at 2× in the
  word game, and objects at 1×.
- To add a sprite, add its grid to the right file and use its id from the catalog,
  `objects.json`, a word pack or code. `make smoke` reports bad rows, unknown
  characters and missing referenced sprites. Sprites the UI uses directly are listed
  in `Content.REQUIRED_SPRITES`.

## PNG overrides

A PNG at `res://assets/sprites/<id>.png` replaces the grid sprite with that id. For
example, `assets/sprites/apple.png` replaces the apple everywhere.

- `Art.sprite(id)` uses the PNG whenever `ResourceLoader.exists()` finds it, so
  Godot must have imported it (`make run`, `make test` and the editor do that).
- Use the size of the sprite it replaces. Layouts are built around those sizes, and
  a different size changes the layout.
- A PNG also counts for an id with no grid, so a new sprite can be a PNG only.

## Pixel font (`content/font.json`)

```json
{ "height": 9, "baseline": 7, "spacing": 1,
  "glyphs": {
    "a": [".....", ".....", ".###.", "....#", ".####", "#...#", ".####", ".....", "....."],
    " ": {"advance": 4}
  } }
```

- Each glyph is `height` (9) rows of `#` (ink) and `.`, all rows the same length,
  with at most 5 px of ink width. Rows 7 and 8 (from `baseline`) are for
  descenders (g, j, p, q, y). The advance is the ink width plus `spacing`, unless
  the glyph is an object with `advance` (and optionally `rows`).
- v1 has a–z, A–Z, 0–9, `! + , - . : = ? _` and space.
- `core/font_builder.gd` packs the glyphs into one atlas and builds a `FontFile` with
  `fixed_size = 9` and integer-only scaling, so the only crisp sizes are 9, 18 and
  27 (`Art.FONT_SMALL`, `FONT_MEDIUM`, `FONT_LARGE`). The label's font color tints
  the glyphs.
- `Art.theme()` uses the font as the theme default, and is set on the root window,
  so every Control gets it.

## Sound effects (`content/sfx.json`)

```json
{ "sample_rate": 22050,
  "sounds": {
    "tap":   {"wave": "square",   "notes": [[880, 0.04]], "volume": 0.3, "attack": 0.002, "release": 0.025},
    "wrong": {"wave": "triangle", "sweep": [262, 196], "duration": 0.2, "volume": 0.45, "attack": 0.01, "release": 0.08}
  } }
```

| Param | Meaning |
|-------|---------|
| `wave` | `square` (band-limited), `triangle` or `noise` |
| `notes` | a list of `[hz, seconds]`, played in order |
| `sweep` + `duration` | an exponential glide from `sweep[0]` Hz to `sweep[1]` Hz over `duration` seconds |
| `volume` | 0–1 |
| `attack`, `release` | seconds of linear fade in and out (at least 2 ms each, so nothing clicks) |

A sound uses either `notes` or `sweep`, not both. `core/sfx_synth.gd` renders it to a
16-bit mono `AudioStreamWAV` at `sample_rate`. `Audio` renders every sound on
startup, and plays them on a pool of 6 players on the `SFX` bus.

The code plays `tap` (every button press; round end raises its pitch per star),
`back` (`Router.back()`), `correct`, `wrong` (`GameShell`) and `fanfare` (round
end). They're listed in `Content.REQUIRED_SFX`. To add a sound, add an entry and
call `Audio.play_sfx("<id>")`; add the id to `REQUIRED_SFX` if code depends on it.
Keep sounds soft: they're for kids, and `wrong` must stay gentle.

**Overrides:** a file at `res://assets/sfx/<id>.wav` or `<id>.ogg` (`.wav` is tried
first) replaces the synthesized sound with that id.

## Music

v1 ships no tracks, but the API and the `Music` bus are ready.

1. Put the track in `res://assets/music/<id>.ogg` (or `.wav`).
2. Call `Audio.play_music("<id>")` where it should start, for example in a screen's
   `_ready()`. It crossfades from the current track over `fade` seconds (default
   0.5) using two players. Playing the current track again does nothing.
3. `Audio.stop_music(fade)` fades out. A track restarts when it ends, so it loops
   even if it wasn't imported with looping.

An unknown id gives a warning and changes nothing. `Settings.music_on` and
`Settings.music_volume_db` drive the `Music` bus and are saved in
`user://settings.cfg`. There's no music toggle on screen yet; the sound toggle
controls `sfx_on` only.

## App icon

`icon.svg` is generated from the 32×32 `app_icon` grid by `tools/export_icon.gd`:
one `<rect>` per run of same-colored pixels, with `shape-rendering="crispEdges"`,
256×256 px. The exports render their icons from it, so they stay sharp. After
changing `app_icon`, run `make icon` and commit `icon.svg`. `make icon` always
rewrites the file, so the next export runs again.
