# Kid Zone build automation. Run `make` or `make help` for the targets.
#
# Exports use the presets in export_presets.cfg. Desktop builds need only the
# export templates; Android needs `make android-setup` once (JDK 17 + SDK);
# iOS needs your Apple Team ID in export_presets.cfg and a Mac to build the .ipa.
#
# Variables: GODOT=/path/to/godot   BUILD=release|debug
#            PLATFORMS="linux windows macos android ios"  (for `all` / `dist`)

SHELL := /bin/bash
.DEFAULT_GOAL := help

GODOT     ?= godot
BUILD     ?= release
PLATFORMS ?= linux windows macos android ios
NAME      := kid-zone

# Android release signing: a git-ignored .env of unquoted KEY=value lines, as printed
# by `make android-keystore`. Values from .env win over the same variables in the
# environment.
-include .env
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD

# "4.7.2.stable.arch_linux.ed1daf0bf" -> "4.7.2.stable" (templates folder name)
GODOT_VERSION := $(shell $(GODOT) --version 2>/dev/null | sed -E 's/^([0-9.]+[a-z]+[0-9]*)\..*/\1/')
# "4.7.2.stable" -> "4.7.2-stable" (GitHub release tag), "4.7" (editor settings file)
RELEASE_TAG   := $(shell echo '$(GODOT_VERSION)' | sed -E 's/\.([a-z]+[0-9]*)$$/-\1/')
GODOT_SERIES  := $(shell echo '$(GODOT_VERSION)' | cut -d. -f1-2)
DATA_HOME     := $(or $(XDG_DATA_HOME),$(HOME)/.local/share)
TEMPLATES_DIR := $(DATA_HOME)/godot/export_templates/$(GODOT_VERSION)
TEMPLATES_URL := https://github.com/godotengine/godot/releases/download/$(RELEASE_TAG)/Godot_v$(RELEASE_TAG)_export_templates.tpz
EDITOR_SETTINGS := $(or $(XDG_CONFIG_HOME),$(HOME)/.config)/godot/editor_settings-$(GODOT_SERIES).tres

# Android toolchain (versions from the Godot 4.7 "Exporting for Android" docs).
ANDROID_SDK          ?= $(HOME)/Android/Sdk
ANDROID_BUILD_TOOLS  := 35.0.1
CMDLINE_TOOLS_URL    := https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip
CMDLINE_TOOLS_SHA256 := 4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583
DEBUG_KEYSTORE       := $(DATA_HOME)/godot/keystores/debug.keystore
ANDROID_KEYSTORE     ?= $(HOME)/.android/$(NAME)-release.keystore

OUT_DIR     := build/$(BUILD)
LINUX_BIN   := $(OUT_DIR)/linux/$(NAME)
WINDOWS_BIN := $(OUT_DIR)/windows/$(NAME).exe
MACOS_BIN   := $(OUT_DIR)/macos/$(NAME).zip
ANDROID_BIN := $(OUT_DIR)/android/$(NAME).apk
IOS_PROJ    := $(OUT_DIR)/ios/$(NAME).xcodeproj

PKG_linux   := $(OUT_DIR)/$(NAME)-linux-x86_64.tar.gz
PKG_windows := $(OUT_DIR)/$(NAME)-windows-x86_64.zip
PKG_macos   := $(OUT_DIR)/$(NAME)-macos-universal.zip
PKG_android := $(OUT_DIR)/$(NAME)-android.apk
PKG_ios     := $(OUT_DIR)/$(NAME)-ios-xcode-project.zip

# Everything that ends up in the game; a change re-imports and re-exports.
# (The assets/ override folders may not exist; find's 2>/dev/null covers that.)
SOURCES := project.godot export_presets.cfg default_bus_layout.tres icon.svg main.tscn main.gd \
	$(shell find autoload core ui screens games content assets -type f 2>/dev/null)
# Test scripts declare and use global classes (TestCase), so they re-import too.
TEST_SOURCES := $(shell find tests -type f 2>/dev/null)
IMPORT_STAMP := .godot/.make-imported

.PHONY: help run edit test smoke smoke-export icon \
	linux windows macos android ios desktop mobile all dist \
	templates android-setup android-keystore android-install \
	check-templates check-android check-ios clean distclean

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[1m%-17s\033[0m %s\n", $$1, $$2}'
	@echo "  Godot $(or $(GODOT_VERSION),NOT FOUND)  BUILD=$(BUILD)  output: $(OUT_DIR)/"

run: $(IMPORT_STAMP) ## Play the game
	$(GODOT) --path .

edit: ## Open the project in the Godot editor
	$(GODOT) --editor --path .

test: $(IMPORT_STAMP) ## Run the headless tests (tests/test_*.gd)
	$(GODOT) --headless --path . res://tests/run_tests.tscn

smoke: $(IMPORT_STAMP) ## Check content, font, theme, sprites, sounds and scenes (headless)
	$(GODOT) --headless --path . -- --smoke-test

smoke-export: $(LINUX_BIN) ## Export Linux, then smoke-test the exported binary
	$(LINUX_BIN) --headless -- --smoke-test

icon: ## Regenerate icon.svg from the app_icon sprite grid
	$(GODOT) --headless --path . --script res://tools/export_icon.gd

linux: $(LINUX_BIN) ## Export the Linux x86_64 build

windows: $(WINDOWS_BIN) ## Export the Windows x86_64 build

macos: $(MACOS_BIN) ## Export the macOS universal build (.app in a .zip, ad-hoc signed)

android: $(ANDROID_BIN) ## Export the Android APK (arm64 + armv7)

ios: $(IOS_PROJ) ## Export the iOS Xcode project (build/sign the .ipa on a Mac)

desktop: linux windows macos ## Export Linux, Windows and macOS

mobile: android ios ## Export Android and iOS

all: $(PLATFORMS) ## Export every platform in PLATFORMS

dist: $(foreach p,$(PLATFORMS),$(PKG_$(p))) ## Export and package PLATFORMS to share

templates: ## Download and install export templates for this Godot version (~1 GB)
	@test -n "$(GODOT_VERSION)" || { echo "error: '$(GODOT)' not found" >&2; exit 1; }
	@if [ -d "$(TEMPLATES_DIR)" ]; then echo "templates already installed: $(TEMPLATES_DIR)"; exit 0; fi; \
	tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	echo "downloading $(TEMPLATES_URL)"; \
	curl -fL --progress-bar -o "$$tmp/templates.tpz" "$(TEMPLATES_URL)"; \
	unzip -q "$$tmp/templates.tpz" -d "$$tmp"; \
	mkdir -p "$(dir $(TEMPLATES_DIR))"; \
	mv "$$tmp/templates" "$(TEMPLATES_DIR)"; \
	echo "installed: $(TEMPLATES_DIR)"

android-setup: ## One-time Android setup: SDK, debug key, Godot editor settings (needs JDK 17)
	@command -v java >/dev/null && command -v keytool >/dev/null || { \
		echo "error: Java not found. Install JDK 17 first, for example:" >&2; \
		echo "       sudo pacman -S jdk17-openjdk      (Arch / Manjaro)" >&2; \
		echo "       sudo apt install openjdk-17-jdk   (Debian / Ubuntu)" >&2; exit 1; }
	@set -e; sdk="$(ANDROID_SDK)"; sdkmanager="$$sdk/cmdline-tools/latest/bin/sdkmanager"; \
	if [ ! -x "$$sdkmanager" ]; then \
		tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
		echo "downloading Android command-line tools (~180 MB)"; \
		curl -fL --progress-bar -o "$$tmp/tools.zip" "$(CMDLINE_TOOLS_URL)"; \
		echo "$(CMDLINE_TOOLS_SHA256)  $$tmp/tools.zip" | sha256sum -c --quiet; \
		unzip -q "$$tmp/tools.zip" -d "$$tmp"; \
		mkdir -p "$$sdk/cmdline-tools"; \
		mv "$$tmp/cmdline-tools" "$$sdk/cmdline-tools/latest"; \
	fi; \
	echo "installing platform-tools and build-tools $(ANDROID_BUILD_TOOLS) into $$sdk"; \
	yes | "$$sdkmanager" --sdk_root="$$sdk" --licenses >/dev/null; \
	"$$sdkmanager" --sdk_root="$$sdk" "platform-tools" "build-tools;$(ANDROID_BUILD_TOOLS)" >/dev/null; \
	ks="$(DEBUG_KEYSTORE)"; \
	if [ ! -f "$$ks" ]; then \
		echo "creating the debug signing key: $$ks"; \
		mkdir -p "$$(dirname "$$ks")"; \
		keytool -genkeypair -keystore "$$ks" -storepass android -keypass android \
			-alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
			-keyalg RSA -keysize 2048 -validity 10000 -noprompt 2>/dev/null; \
	fi; \
	f="$(EDITOR_SETTINGS)"; \
	if [ ! -f "$$f" ]; then \
		echo "error: $$f not found. Open the Godot editor once ('make edit'), then rerun." >&2; exit 1; \
	fi; \
	java_home=$$(dirname "$$(dirname "$$(readlink -f "$$(command -v java)")")"); \
	set_setting() { \
		if grep -q "^$$1 = " "$$f"; then sed -i "s|^$$1 = .*|$$1 = $$2|" "$$f"; else echo "$$1 = $$2" >> "$$f"; fi; }; \
	set_setting export/android/java_sdk_path "\"$$java_home\""; \
	set_setting export/android/android_sdk_path "\"$$sdk\""; \
	set_setting export/android/debug_keystore "\"$$ks\""; \
	set_setting export/android/debug_keystore_user '"androiddebugkey"'; \
	set_setting export/android/debug_keystore_pass '"android"'; \
	echo "Android is ready (Java: $$java_home). Try: make android BUILD=debug"

android-keystore: ## Create your Android release signing key (asks for a password)
	@command -v keytool >/dev/null || { echo "error: keytool not found; run 'make android-setup' first" >&2; exit 1; }
	@if [ -f "$(ANDROID_KEYSTORE)" ]; then echo "already exists: $(ANDROID_KEYSTORE)"; else \
		mkdir -p "$(dir $(ANDROID_KEYSTORE))"; \
		keytool -genkeypair -v -keystore "$(ANDROID_KEYSTORE)" -alias $(NAME) \
			-keyalg RSA -keysize 2048 -validity 10000; fi
	@echo; echo "Keep this file and its password safe and private; app-store updates must be signed with it."
	@echo "Before 'make android' (release), put these lines in .env (git-ignored, no quotes):"
	@echo "  GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$(ANDROID_KEYSTORE)"
	@echo "  GODOT_ANDROID_KEYSTORE_RELEASE_USER=$(NAME)"
	@echo "  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<your password>"

android-install: $(ANDROID_BIN) ## Install the APK on a USB-connected phone (USB debugging on)
	"$(ANDROID_SDK)/platform-tools/adb" install -r $(ANDROID_BIN)

check-templates:
	@test -d "$(TEMPLATES_DIR)" || { \
		echo "error: export templates for Godot $(GODOT_VERSION) are missing." >&2; \
		echo "       run 'make templates', or install them in the editor:" >&2; \
		echo "       Editor > Manage Export Templates." >&2; exit 1; }

check-android:
	@f="$(EDITOR_SETTINGS)"; \
	java=$$(sed -n 's|^export/android/java_sdk_path = "\(.*\)"$$|\1|p' "$$f" 2>/dev/null); \
	sdk=$$(sed -n 's|^export/android/android_sdk_path = "\(.*\)"$$|\1|p' "$$f" 2>/dev/null); \
	if [ -z "$$java" ] || [ ! -x "$$sdk/platform-tools/adb" ] || ! ls "$$sdk"/build-tools/*/apksigner >/dev/null 2>&1; then \
		echo "error: the Android toolchain is not set up. Run 'make android-setup' once (needs JDK 17)." >&2; exit 1; fi
	@if [ "$(BUILD)" = release ] && [ -z "$$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then \
		echo "error: a release APK must be signed with your own key." >&2; \
		echo "       run 'make android-keystore' once and put the lines it prints in .env," >&2; \
		echo "       or build a debug APK for your own phone: make android BUILD=debug" >&2; exit 1; fi

check-ios:
	@grep -qE '^application/app_store_team_id="[A-Z0-9]{10}"' export_presets.cfg || { \
		echo "error: iOS needs your 10-character Apple Team ID (e.g. ABCDE12XYZ)." >&2; \
		echo "       Put it in export_presets.cfg: application/app_store_team_id=\"...\"" >&2; \
		echo "       Find it at developer.apple.com > Account > Membership (a free Apple ID works)." >&2; exit 1; }

clean: ## Remove build output
	rm -rf build

distclean: clean ## Also remove Godot's import cache (.godot/)
	rm -rf .godot

# --- file targets --------------------------------------------------------------

# Builds the import cache (the CSV translation) and the global class cache that the
# game, the tests and the exports rely on.
$(IMPORT_STAMP): $(SOURCES) $(TEST_SOURCES)
	$(GODOT) --headless --path . --import
	@touch $@

# Only when icon.svg is missing; `make icon` regenerates it on purpose.
icon.svg:
	$(GODOT) --headless --path . --script res://tools/export_icon.gd

$(LINUX_BIN): $(SOURCES) | $(IMPORT_STAMP) check-templates
	@mkdir -p $(@D)
	$(GODOT) --headless --path . --export-$(BUILD) "Linux" $@

$(WINDOWS_BIN): $(SOURCES) | $(IMPORT_STAMP) check-templates
	@mkdir -p $(@D)
	$(GODOT) --headless --path . --export-$(BUILD) "Windows" $@

# Godot zips the .app itself; macOS can't be exported as a bare .app bundle
# without losing permissions, and .dmg images can only be made on a Mac.
$(MACOS_BIN): $(SOURCES) | $(IMPORT_STAMP) check-templates
	@mkdir -p $(@D)
	$(GODOT) --headless --path . --export-$(BUILD) "macOS" $@

$(ANDROID_BIN): $(SOURCES) | $(IMPORT_STAMP) check-templates check-android
	@mkdir -p $(@D)
	$(GODOT) --headless --path . --export-$(BUILD) "Android" $@

# Godot writes the .xcodeproj plus the game data and frameworks next to it.
$(IOS_PROJ): $(SOURCES) | $(IMPORT_STAMP) check-templates check-ios
	@mkdir -p $(@D)
	$(GODOT) --headless --path . --export-$(BUILD) "iOS" $@
	@touch $@

$(PKG_linux): $(LINUX_BIN)
	tar -czf $@ -C $(<D) $(<F)

$(PKG_windows): $(WINDOWS_BIN)
	cd $(<D) && zip -q -9 $(abspath $@) $(<F)

$(PKG_macos): $(MACOS_BIN)
	cp $< $@

$(PKG_android): $(ANDROID_BIN)
	cp $< $@

$(PKG_ios): $(IOS_PROJ)
	cd $(OUT_DIR) && rm -f $(abspath $@) && zip -qry $(abspath $@) ios
