# Kid Zone

A small 8-bit learning game for young kids, made with Godot 4. It's built for
tablets and touch, and works just as well with a mouse on a desktop. A kid who
can't read yet picks a mode from big picture tiles and plays a round of 10
questions:

- **Math, add.** `a + b = ?`, with that many fruits, vegetables or toys above
  each number to count. Three levels: easy (sums up to 5), medium (up to 10) and
  hard (each number 1–12, sums of 11 or more).
- **Math, minus.** `a - b = ?`, with a objects above `a` and b objects above `b`.
  Three levels: easy (`a` up to 5), medium (up to 10) and hard (`a` from 8 to 12).
  `b` is at least 1, and the answer can be 0.
- **Words, missing letter.** A picture and its English word with one letter
  missing (`S_N` and a sun). The 40 words have three or four letters, mixed at
  random. Exactly one of the four letters makes a real word. Words and letters
  show in UPPERCASE, or in lowercase with the `ABC`/`abc` toggle.

Every sprite, the pixel font and every sound effect are generated from JSON
data in `content/`. The project has no image, font or audio files, except the
app icon, which is also generated.

## How to play

1. On the main menu, tap **math** or **words**.
2. Tap a game: **add** or **minus** in math, **letters** in words. Math then asks
   for a level: **easy**, **medium** or **hard**, shown with 1, 2 or 3 stars.
3. Tap the answer. A wrong answer plays a soft sound, and its button shakes,
   greys out and can't be tapped again. Try again until it's right. A right
   answer fills the blank, and the next question comes.
4. After 10 questions, the round end shows your stars: gold when the first try
   was right, silver when it took more. Tap **again** for the same game and
   level, or **home**.

| Action          | Touch                        | Mouse          | Keyboard |
|-----------------|------------------------------|----------------|----------|
| Choose          | Tap                          | Click          | none     |
| Back one screen | `<` at the top left, Android back | Click `<` | Esc      |
| Sound on/off    | Speaker at the top right of the main menu | Click it | none |
| UPPERCASE/lowercase words | `AB`/`ab` button left of the speaker | Click it | none |

Buttons act when you let go, so sliding a finger off a button cancels the tap.
Back does nothing on the main menu, so a kid can't leave the game by accident.
Close the window, or use the phone's home button, to quit.

The sound and letter-case settings are remembered in `user://settings.cfg`. The
letter case changes only the word game's word and letter buttons. On Linux that's
`~/.local/share/godot/app_userdata/Kid Zone/settings.cfg`.

## Running

You need Godot 4.7 (standard build, not .NET). It was made with 4.7.2.

```bash
make run                  # play (imports the project first when needed)
make edit                 # open it in the Godot editor
godot --path .            # play, once the project has been imported
```

On a fresh clone, use `make run` (or open the editor once) rather than plain
`godot --path .`. The first `make` target imports the project, which builds the UI
translation and the class cache the game needs.

These options, after `--`, open a screen directly. They're for screenshots and
debugging, and work in exported builds too (`./kid-zone -- --open=...`). While
one is in use, the game never saves settings.

```bash
godot --path . -- --open=math_addition:hard --seed=3   # a game (and level), with fixed questions
godot --path . -- --open=math_subtraction:easy
godot --path . -- --open=word_missing_letter
godot --path . -- --screen=mode_menu:words             # main_menu | mode_menu:<mode> |
godot --path . -- --screen=level_select:math_addition  #   level_select:<game> |
godot --path . -- --screen=round_end                   #   round_end[:<game>[:<level>]]
godot --headless --path . -- --smoke-test              # check the content (or: make smoke)
```

Back works from any opened screen, as if the kid had tapped their way there.
A bad option prints the problem and the usage, and exits 1.

## Building

Builds are driven by the `Makefile` and the presets in `export_presets.cfg`.
Everything is built on Linux: Windows, macOS, Android and iOS themselves aren't
needed, except a Mac for the final iOS step. Linux and Windows each produce a
single file with the game data embedded.

```bash
make templates          # once per Godot version: download export templates (~1 GB)
make desktop            # build/release/{linux/kid-zone, windows/kid-zone.exe, macos/kid-zone.zip}
make mobile             # build/release/{android/kid-zone.apk, ios/kid-zone.xcodeproj}
make linux              # or one platform: linux | windows | macos | android | ios
make all                # every platform in PLATFORMS (default: all five)
make dist               # also make archives to share, in build/release/
make dist PLATFORMS="linux windows macos"   # only some platforms
make all BUILD=debug    # debug builds (console + error output) in build/debug/
make help               # every target
```

The export templates must match `godot --version` exactly. You can also install
them from the editor: **Editor → Manage Export Templates**. Set `GODOT=/path/to/godot`
to use a different Godot binary.

Exports only rebuild when a game file changes. `make icon` regenerates `icon.svg`
from the `app_icon` sprite and always rewrites the file, so the next export runs
again. The headless import and export steps may print
`cannot connect to daemon at tcp:5037`. That's Godot looking for Android devices
over adb, and it's harmless.

**macOS.** The build is a `.zip` containing `Kid Zone.app`, a universal binary
for both Intel and Apple Silicon Macs. It has a basic (ad-hoc) signature from
Godot and is not notarized, because that needs a paid Apple Developer ID.
Gatekeeper blocks it the first time it's opened after being downloaded. Players
can allow it in **System Settings → Privacy & Security → Open Anyway**, or run
`xattr -dr com.apple.quarantine "Kid Zone.app"`. `.dmg` images can only be made
on a Mac.

**Windows.** A debug build also writes `kid-zone.console.exe` next to
`kid-zone.exe`; run it to see the game's output. `make dist` packages only
`kid-zone.exe`.

**Android.** One-time setup: install JDK 17 (`sudo pacman -S jdk17-openjdk` on
Arch/Manjaro), then run `make android-setup`. It downloads the Android
command-line tools (checksum-verified) and installs platform-tools and
build-tools into `~/Android/Sdk`. It also creates the standard debug signing key
and points Godot's editor settings at Java and the SDK. Close the Godot editor
first, because it rewrites its settings file on exit.

```bash
make android BUILD=debug   # APK signed with the debug key: fine for your own tablet
make android-install       # install it over USB (USB debugging on)
make android-keystore      # once: your own release key (keep it and its password safe)
make android               # release APK; needs the GODOT_ANDROID_KEYSTORE_RELEASE_* variables
```

A release APK is signed with your own key. `make android-keystore` creates it in
`~/.android/kid-zone-release.keystore` and prints three lines to put in a `.env`
file in the project folder (git-ignored):

```make
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/home/you/.android/kid-zone-release.keystore
GODOT_ANDROID_KEYSTORE_RELEASE_USER=kid-zone
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=your password
```

`make` reads `.env` as makefile lines, not as a shell script:

- Don't quote the values; quotes would become part of the value. Leave no
  trailing spaces.
- Write a `$` in the password as `$$`, and a `#` as `\#`. An unescaped `#` starts
  a comment, which silently cuts the password short there.
- A value in `.env` wins over the same variable in your environment. A variable
  on the command line (`make android GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...`)
  wins over `.env`. Without a `.env`, exported environment variables work, as in
  any Godot export.

The APK runs on 32- and 64-bit ARM phones and tablets, in landscape. The Play
Store wants an AAB, which needs Godot's Gradle build; this setup makes APKs for
sideloading.

**iOS.** Set your 10-character Apple Team ID in `export_presets.cfg`
(`application/app_store_team_id`); a free Apple ID's personal team works. Until
then, `make ios` stops with a message saying so. Then `make ios` exports an Xcode
project to `build/release/ios/`, and `make dist` zips it. Building, signing and
installing the `.ipa` is done in Xcode on a Mac. The app targets iPhone and iPad.

**Ids.** The macOS and iOS bundle ID is `io.github.hop-.kid-zone`, and Android's
package name is `io.github.hop_.kidzone` (Android doesn't allow hyphens). Change
them in `export_presets.cfg`.

## Tests

```bash
make test           # the headless test suite (every tests/test_*.gd)
make smoke          # load and check the content, font, theme, sprites, sounds and scenes
make smoke-export   # export the Linux build and run the same check on the exported binary
```

`make smoke` and `make smoke-export` print `SMOKE OK`. The exported check proves
the JSON content made it into the game data. Add `BUILD=debug` to
`make smoke-export` to check a debug export. See
[dev-docs/testing-and-export.md](dev-docs/testing-and-export.md) for the test runner.

## Layout

```
Makefile              run / test / smoke / icon / export / package targets
export_presets.cfg    Linux, Windows, macOS, Android and iOS export presets
project.godot         320×180 viewport, integer-scaled; the autoloads
default_bus_layout.tres  audio buses: Master, SFX, Music
icon.svg              app icon, generated from the app_icon sprite (make icon)
main.tscn, main.gd    root scene: screen host + fade; debug options and smoke test
autoload/             Settings, Content, Art, Audio, Router (loaded in that order)
core/                 MiniGame contract, GameShell (round loop), RoundController,
                      QuestionUtils, sprite/font builders, sound synthesizer
games/                one folder per game: its scene, view script and question generator;
                      math_common/ holds the equation view both math games share
screens/              main menu, mode menu, level select, round end
ui/                   buttons, tiles, choice buttons and row, star bar, back button,
                      sound and letter-case toggles
content/              catalog, palette, objects, font, sounds, sprites, word packs, UI text
tools/export_icon.gd  writes icon.svg
tests/                test runner, TestCase base, test_*.gd
dev-docs/             developer docs
```

Developer docs start at [AGENTS.md](AGENTS.md). Adding a game is described in
[dev-docs/adding-a-game.md](dev-docs/adding-a-game.md).
