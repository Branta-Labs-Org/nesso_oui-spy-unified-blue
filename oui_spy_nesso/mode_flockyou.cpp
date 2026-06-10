/*
 * Mode 4: Flock-You
 * Surveillance device detector with web dashboard.
 * Scans BLE for Flock Safety, Raven, and surveillance device patterns.
 * Serves detection dashboard via WiFi AP "flockyou" / "flockyou123".
 * Detections stored in memory; exportable as JSON or CSV.
 */

// All includes from flock-you (outside namespace for proper linkage)
#include <Arduino.h>
#include <WiFi.h>
#include <DNSServer.h>
#include <NimBLEDevice.h>
#include <NimBLEScan.h>
#include <NimBLEAdvertisedDevice.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <stdint.h>
#include "esp_wifi.h"
#include "esp_wifi_types.h"
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <SPIFFS.h>
#ifndef NESSO_N1
#include <TinyGPS++.h>
#endif
#include "board_pins.h"
#include "board_hw.h"
#include "board_neopixel.h"
#include "nesso_ui.h"
#include "nimble_compat.h"
#ifndef NESSO_N1
#include <TinyGPS++.h>
#endif
#include "modes.h"

// Rename setup/loop
#define setup flockyou_ns_setup
#define loop  flockyou_ns_loop

namespace {
#include "raw/flockyou.cpp"
} // anonymous namespace

#undef setup
#undef loop

void flockyou_setup() { flockyou_ns_setup(); }
void flockyou_loop()  { flockyou_ns_loop(); }
