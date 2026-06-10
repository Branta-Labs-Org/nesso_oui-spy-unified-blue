#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/setup-arduino-user.sh"

EXTRA_FLAGS=(
  "build.extra_flags=-DNESSO_N1=1 -DNESSO_DISPLAY_UI=1 -DCONFIG_BT_NIMBLE_ENABLED=1 -DCONFIG_LWIP_TCPIP_CORE_LOCKING=1 -Iraw"
)

ARGS=(compile --clean --config-file arduino-cli-nesso.yaml --fqbn esp32:esp32:arduino_nesso_n1 --libraries libraries)
ARGS+=("--build-property" "${EXTRA_FLAGS[0]}")

if [[ "${1:-}" == "-u" || "${1:-}" == "--upload" ]]; then
  PORT="${2:-/dev/cu.usbmodem14401}"
  ARGS+=(-u -p "$PORT")
fi

arduino-cli "${ARGS[@]}" .

ELF="$(find "${HOME}/Library/Caches/arduino/sketches" -name 'oui_spy_nesso.ino.elf' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1)"
if [[ -z "$ELF" ]]; then
  echo "Could not locate built ELF for link verification." >&2
  exit 1
fi

if strings "$ELF" | rg -q 'Documents/Arduino/libraries/AsyncTCP'; then
  echo "ERROR: firmware still links global AsyncTCP@1.1.4 from Documents." >&2
  strings "$ELF" | rg 'AsyncTCP.cpp' | head -5 >&2
  exit 1
fi

if ! strings "$ELF" | rg 'projects/nesso/oui_spy_nesso/libraries/AsyncTCP' >/dev/null 2>&1; then
  echo "ERROR: patched vendored AsyncTCP was not linked." >&2
  strings "$ELF" | rg 'AsyncTCP' | head -8 >&2
  exit 1
fi

echo "OK: firmware links patched AsyncTCP from oui_spy_nesso/libraries/AsyncTCP"
