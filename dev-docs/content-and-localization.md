# Content and localization

All game data is JSON under `res://content/`, read with `FileAccess` by the `Content`
autoload (`autoload/content.gd`). The UI text is a Godot CSV translation. Nothing is
found by scanning folders: the catalog and the fixed file names say what exists.

## Files

| File | Holds |
|------|-------|
| `catalog.json` | modes → games → levels: ids, title keys, icons, scenes, params (see [adding-a-game.md](adding-a-game.md)) |
| `palette.json` | the 16 colors, keyed `0`–`9`, `a`–`f`, each with a name; `.` is transparent |
| `objects.json` | the 12 counting objects for math: `id`, `category` (fruit, vegetable, toy), `sprite` |
| `font.json` | the pixel font's glyph grids (see [art-and-audio.md](art-and-audio.md)) |
| `sfx.json` | the sound effects as synth parameters (see [art-and-audio.md](art-and-audio.md)) |
| `sprites/icons.json`, `objects.json`, `words.json` | sprite grids; `sprites/ui.json` is also read if it exists |
| `<locale>/words.json` | a word pack; v1 has `en/words.json` |
| `locale/ui.csv` | UI text: `keys,en`, one key per line |

Ids (modes, games, levels, objects, words, sounds, sprites) are lowercase
snake_case and stable, because sprites, sounds and translations refer to them.

## Validation

`Content.validate()` returns every problem as `"<file>: <problem>"`, and an empty
list means valid. On startup the autoload pushes each problem as an error
(`Content: ...`) without stopping the game, and `make smoke` fails on any of them.
Loading never crashes on bad data: accessors return empty values instead. It checks:

- JSON syntax and structure, unique snake_case ids, and known palette color names
- catalog scenes exist, and every title key and `REQUIRED_UI_KEYS` key has an `en`
  text
- every referenced sprite (mode and game icons, objects, word pictures,
  `REQUIRED_SPRITES`) has a grid or an override PNG
- sprite rows match their `size`, and use only palette keys and `.`
- word texts and `known_words` use only the pack's `alphabet`, `blank` indices are
  valid, `locale` matches the folder, and every allowed blank has at least 3 valid
  distractor letters (`MIN_DISTRACTORS`)
- `sfx.json` structure, and the 5 sounds the code plays (`REQUIRED_SFX`)
- `font.json` structure, and a glyph for every character of the active word pack,
  its alphabet, `0123456789+=?` and the `en` UI strings

The constants (`REQUIRED_SFX`, `REQUIRED_UI_KEYS`, `REQUIRED_SPRITES`,
`REQUIRED_GLYPHS`) are at the top of `autoload/content.gd`. When code starts using a
new sound, UI key or sprite directly, add it there so validation covers it.

## UI text (`locale/ui.csv`)

```csv
keys,en
APP_TITLE,Kid Zone
MODE_MATH,math
...
```

- Every visible string goes through `tr()`. Screens call `tr(key)` themselves and
  turn off `auto_translate_mode` on those labels, so text isn't translated twice.
  Digits, signs and words from a word pack aren't translated.
- Godot imports the CSV into `content/locale/ui.<lang>.translation` files. They are
  generated, git-ignored, and rebuilt by `make` (any `make` target that imports) or
  by the editor. The project setting `internationalization/locale/translations`
  lists them; only `ui.en.translation` is registered today.
- Labels are short lowercase words, and every one sits next to an icon, because
  most players can't read yet.

## Word packs (`<locale>/words.json`)

```json
{
  "locale": "en",
  "alphabet": "abcdefghijklmnopqrstuvwxyz",
  "words": [
    {"id": "sun", "text": "sun", "picture": "word_sun"},
    {"id": "egg", "text": "egg", "picture": "word_egg", "blank": [0]}
  ],
  "known_words": ["cut", "cot", "..."]
}
```

- `text` uses only characters from `alphabet`. v1's 20 words are lowercase and three
  letters long.
- `picture` is a sprite id, normally a 24×24 grid `word_<id>` in
  `sprites/words.json`, drawn at 2×.
- `blank` (optional) lists the indices that may be hidden. Without it any letter may
  be. `egg` and `bee` use `[0]`, because hiding one of their double letters is
  confusing.
- `known_words` (370 words in `en`) are common short words that aren't in the pack.
  A distractor letter is never offered when putting it in the blank would spell a
  pack word or a known word, so exactly one choice makes a real word. For example,
  `c_t` never offers `u` (cut) or `o` (cot).

The generator is `games/word_missing_letter/missing_letter_generator.gd`, and
`Content.count_distractors()` uses the same rule for validation.

### Adding a word

1. Add the word to `words` in `content/en/words.json`:
   `{"id": "jam", "text": "jam", "picture": "word_jam"}`.
2. Draw its 24×24 picture as `word_jam` in `content/sprites/words.json` (see
   [art-and-audio.md](art-and-audio.md)), or drop `assets/sprites/word_jam.png`.
3. Make sure the common words that differ from it by one letter are in
   `known_words`, so they can't appear as wrong choices that are actually right.
   For `jam`, the `en` list already has `ham`, `jab`, `jaw` and `jar`. Only words of
   the same length can collide. A word may be in both the pack and `known_words`.
4. Run `make smoke`. It reports a missing picture, characters outside the alphabet,
   a missing glyph, or a blank with fewer than 3 possible distractors. If a blank
   has too few, limit it with `blank`.

Letter boxes are 28 px wide, so words up to about 10 letters fit the 320 px view.

## Adding a language

v1 ships English only, and has no language picker. Two things choose the language:

- **UI text** follows Godot's translation locale, which is the device's OS locale,
  falling back to `en` when there's no translation for it. To preview a language,
  set `internationalization/locale/test` in the project settings.
- **The word pack** follows `Settings.locale`, saved as `locale` in
  `user://settings.cfg` (default `en`). `Content` resolves it on load: the exact
  locale (`hy_AM`), then its language (`hy`), then `en`. Changing it while the game
  runs doesn't reload the content.

Steps, using Armenian (`hy`) as the example:

1. **UI text.** Add a column to `content/locale/ui.csv` (`keys,en,hy`) and fill it
   for every key. After an import, Godot writes `content/locale/ui.hy.translation`.
   Add that path to `internationalization/locale/translations` in `project.godot`
   (Project Settings → Localization → Translations).
2. **Word pack.** Create `content/hy/words.json` with `"locale": "hy"`, the
   language's `alphabet`, its words and `known_words`. Word `id`s stay ASCII
   snake_case; `text` and `alphabet` can use any characters. Give each word a
   picture sprite.
3. **Glyphs.** Add a glyph to `content/font.json` for every new character of the
   alphabet and the UI texts. A glyph is at most 5 px of ink wide and 9 rows tall
   (`MAX_GLYPH_WIDTH` in `content.gd`).
4. **Check it.** `make smoke` validates the active word pack (from `Settings.locale`)
   and the `en` UI strings only. To check the new pack, load it explicitly, for
   example in a test:

   ```gdscript
   var content := preload("res://autoload/content.gd").new()
   content.load_content("res://content", "hy")
   assert_eq(content.validate(), PackedStringArray())
   content.free()
   ```

   Check the new UI column's characters against the font by hand, or with a test.
5. Choosing the language is up to a future picker: set `Settings.locale`, call
   `TranslationServer.set_locale()`, reload `Content` and rebuild the screen.
