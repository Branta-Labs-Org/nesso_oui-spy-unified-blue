#!/usr/bin/env bash
# Prepare the project-local Arduino environment for the Nesso N1 sketch.
#
#  1. Shadow conflicting global libraries with project-controlled copies.
#  2. Vendor the patched ESP32Async stack from ../lib/async_web (shared with
#     the PlatformIO build) instead of the global AsyncTCP@1.1.4.
#  3. Mirror the canonical sources from ../src into this sketch directory.
#
# The mirrored *.cpp/*.c/*.h here and the raw/ subdir are GENERATED — they are
# git-ignored. Edit ../src (the single source of truth), never the copies.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$(cd "$ROOT/.." && pwd)"
USER_DIR="$ROOT/.arduino-cli-user/libraries"
GLOBAL="${HOME}/Documents/Arduino/libraries"
ASYNC="$PROJECT/lib/async_web"
SRC="$PROJECT/src"

mkdir -p "$USER_DIR"

link_global() {
  local name="$1"
  if [[ ! -d "$GLOBAL/$name" ]]; then
    echo "Missing global library: $GLOBAL/$name" >&2
    exit 1
  fi
  ln -sfn "$GLOBAL/$name" "$USER_DIR/$name"
}

# Board + deps from the normal sketchbook (not vendored in-repo).
for lib in Arduino_Nesso_N1 M5GFX Arduino_BMI270_BMM150 NimBLE-Arduino ArduinoJson; do
  link_global "$lib"
done

# Patched ESP32Async stack — single copy lives in ../lib/async_web, shared with
# the PlatformIO env. AsyncTCP carries the lwIP TCPIP-core-lock fix; must NOT
# fall back to the global AsyncTCP@1.1.4.
ln -sfn "$ASYNC/AsyncTCP" "$USER_DIR/AsyncTCP"
ln -sfn "$ASYNC/ESP_Async_WebServer" "$USER_DIR/ESP_Async_WebServer"

# Mirror canonical sources into the sketch dir (generated, git-ignored).
# Warn loudly if a generated copy was hand-edited instead of ../src so the
# edit is not silently overwritten by this sync.
warned=0
warn_if_diverged() {
  local gen="$1" canon="$2"
  if [[ -f "$gen" && -f "$canon" ]] && ! diff -q "$gen" "$canon" >/dev/null 2>&1; then
    if [[ "$warned" == 0 ]]; then
      echo "WARNING: generated sketch sources differ from ../src and will be overwritten:" >&2
      warned=1
    fi
    echo "  - ${gen#"$ROOT"/}  (edit ../src/${canon#"$SRC"/} instead)" >&2
  fi
}

shopt -s nullglob
for f in "$SRC"/*.cpp "$SRC"/*.c "$SRC"/*.h; do
  warn_if_diverged "$ROOT/$(basename "$f")" "$f"
  cp "$f" "$ROOT/"
done
for f in "$SRC"/raw/*; do
  warn_if_diverged "$ROOT/raw/$(basename "$f")" "$f"
done
rm -rf "$ROOT/raw"
mkdir -p "$ROOT/raw"
cp "$SRC"/raw/* "$ROOT/raw/"

echo "Arduino user libraries ready at $USER_DIR"
echo "  AsyncTCP            -> $ASYNC/AsyncTCP (patched 3.4.10, MARK_TCPIP_TASK)"
echo "  ESP_Async_WebServer -> $ASYNC/ESP_Async_WebServer (3.11.1)"
echo "Sketch sources mirrored from $SRC (generated, git-ignored)"
