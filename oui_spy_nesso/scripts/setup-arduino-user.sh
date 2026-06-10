#!/usr/bin/env bash
# Shadow conflicting global Arduino libraries with project-controlled copies.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USER_DIR="$ROOT/.arduino-cli-user/libraries"
GLOBAL="${HOME}/Documents/Arduino/libraries"

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

# Patched ESP32Async AsyncTCP (lwIP TCPIP core lock) — must NOT use global AsyncTCP@1.1.4.
ln -sfn "$ROOT/libraries/AsyncTCP" "$USER_DIR/AsyncTCP"

echo "Arduino user libraries ready at $USER_DIR"
echo "  AsyncTCP -> $ROOT/libraries/AsyncTCP (patched 3.4.10)"
ls -la "$USER_DIR"
