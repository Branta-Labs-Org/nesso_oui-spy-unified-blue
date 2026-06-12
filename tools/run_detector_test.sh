#!/usr/bin/env bash
# 1) Flash NVS for Detector mode + Espressif OUIs
# 2) Or fall back: force selector via NVS, join AP, curl mode select + OUI config
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-/dev/cu.usbmodem14401}"
VENV="${VENV:-/tmp/nesso-serial-venv}"
NVS_BIN="/tmp/nesso-detector-test.nvs.bin"
NVS_SIZE=0x5000
NVS_OFFSET=0x9000
WIFI_IF="${WIFI_IF:-en0}"

if [[ ! -x "$VENV/bin/python3" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q pyserial esp-idf-nvs-partition-gen esptool
fi

"$VENV/bin/python3" -m esp_idf_nvs_partition_gen generate \
  "$ROOT/tools/nvs_detector_test.csv" "$NVS_BIN" "$NVS_SIZE"

echo "Flashing NVS at $NVS_OFFSET..."
"$VENV/bin/esptool" --chip esp32c6 --port "$PORT" write-flash "$NVS_OFFSET" "$NVS_BIN"

reset_device() {
  "$VENV/bin/python3" - <<PY
import serial, time
ser = serial.Serial("$PORT", 115200, timeout=0.5)
ser.setDTR(False); ser.setRTS(True); time.sleep(0.05)
ser.setDTR(True); ser.setRTS(False); time.sleep(0.05)
ser.setDTR(False)
time.sleep(3)
ser.close()
PY
}

echo "Resetting..."
reset_device

echo "Capturing boot banner (15s)..."
"$VENV/bin/python3" - <<'PY'
import serial, time
port = "/dev/cu.usbmodem14401"
ser = serial.Serial(port, 115200, timeout=0.5)
ser.reset_input_buffer()
end = time.time() + 15
mode = "unknown"
while time.time() < end:
    line = ser.readline().decode("utf-8", "replace").rstrip()
    if not line:
        continue
    print(line)
    if "STARTING DETECTOR" in line:
        mode = "detector"
    elif "FLOCK-YOU" in line and "Surveillance" in line:
        mode = "flockyou"
    elif "OUI SPY" in line and "selector" in line.lower():
        mode = "selector"
ser.close()
open("/tmp/nesso_boot_mode.txt", "w").write(mode)
PY

BOOT_MODE="$(cat /tmp/nesso_boot_mode.txt)"
echo "Detected boot mode: $BOOT_MODE"

if [[ "$BOOT_MODE" != "detector" ]]; then
  echo "NVS mode switch did not stick; using WiFi selector fallback..."
  # Force selector on next boot via minimal NVS patch
  cat > /tmp/nvs_selector.csv <<'CSV'
key,type,encoding,value
nvs,namespace,,
unified-mode,namespace,,
selector,data,u8,1
CSV
  "$VENV/bin/python3" -m esp_idf_nvs_partition_gen generate /tmp/nvs_selector.csv /tmp/nvs_selector.bin "$NVS_SIZE"
  "$VENV/bin/esptool" --chip esp32c6 --port "$PORT" write-flash "$NVS_OFFSET" /tmp/nvs_selector.bin
  reset_device
  sleep 5
  echo "Joining oui-spy AP on $WIFI_IF..."
  networksetup -setairportnetwork "$WIFI_IF" "oui-spy" "ouispy123" || true
  sleep 4
  curl -sf --max-time 10 "http://192.168.4.1/select?mode=1" && echo "Selected mode 1"
  sleep 8
  reset_device
  sleep 5
fi

echo "Joining detector config AP (snoopuntothem) if needed..."
networksetup -setairportnetwork "$WIFI_IF" "snoopuntothem" "astheysnoopuntous" 2>/dev/null || true
sleep 4

if curl -sf --max-time 5 "http://192.168.4.1/" >/dev/null 2>&1; then
  echo "Posting Espressif OUIs (LilyGo T-Deck targets)..."
  curl -sf --max-time 15 -X POST "http://192.168.4.1/save" \
    -F "ouis=24:6f:28
10:20:ba
94:b5:55
48:f6:ee" \
    -F "macs=" \
    -F "buzzer=on" \
    -F "led=on" \
    -F "ssid=snoopuntothem" \
    -F "password=astheysnoopuntous" && echo "Config saved"
  sleep 2
  curl -sf --max-time 10 -X POST "http://192.168.4.1/api/lock-config" \
    -F "ouis=24:6f:28
10:20:ba
94:b5:55
48:f6:ee" \
    -F "macs=" && echo "Config locked -> scanning mode"
  sleep 5
fi

echo "--- Monitoring serial for BLE matches (120s) ---"
"$VENV/bin/python3" - <<'PY'
import serial, time, json
port = "/dev/cu.usbmodem14401"
ser = serial.Serial(port, 115200, timeout=0.5)
time.sleep(1)
ser.reset_input_buffer()
end = time.time() + 120
matches = []
while time.time() < end:
    line = ser.readline().decode("utf-8", "replace").rstrip()
    if not line:
        continue
    print(line)
    if line.startswith('{"mac":'):
        try:
            matches.append(json.loads(line))
        except json.JSONDecodeError:
            pass
ser.close()
print("\n=== MATCH SUMMARY ===")
if matches:
    for m in matches:
        print(f"  {m.get('mac')} rssi={m.get('rssi')} alias={m.get('alias','')}")
else:
    print("  No JSON BLE matches in 120s window.")
PY
