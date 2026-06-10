#include "nesso_ui.h"

#ifdef NESSO_N1
#include <Arduino_Nesso_N1.h>

static NessoDisplay sDisplay;
static NessoBattery sBattery;
static bool sReady = false;
static char sModeName[24] = "OUI-SPY";
static char sStatusLine[32] = "";
static int sDetectionCount = 0;
static int sRssi = -100;
static unsigned long sAlertUntil = 0;
static unsigned long sLastBatteryDraw = 0;

static constexpr unsigned long kBatteryRefreshMs = 30000;

static void nessoUiDrawAlertBar() {
  if (millis() < sAlertUntil) {
    sDisplay.fillRect(0, 88, 135, 16, TFT_RED);
    sDisplay.setTextColor(TFT_WHITE);
    sDisplay.setTextSize(1);
    sDisplay.setCursor(8, 92);
    sDisplay.print("ALERT");
  } else {
    sDisplay.fillRect(0, 88, 135, 16, TFT_BLACK);
  }
}

static void nessoUiDrawBattery() {
  sDisplay.fillRect(0, 16, 135, 14, TFT_BLACK);
  sDisplay.setTextColor(TFT_GREEN);
  sDisplay.setTextSize(1);
  float volts = sBattery.getVoltage();
  uint16_t pct = sBattery.getChargeLevel();
  sDisplay.setCursor(4, 18);
  sDisplay.printf("Bat: %.2fV %u%%", volts, pct);
}

static void nessoUiDraw() {
  if (!sReady) return;

  sDisplay.fillScreen(TFT_BLACK);
  sDisplay.setTextColor(TFT_GREEN);
  sDisplay.setTextSize(1);
  sDisplay.setCursor(4, 4);
  sDisplay.print(sModeName);

  nessoUiDrawBattery();
  sLastBatteryDraw = millis();

  if (sDetectionCount > 0) {
    sDisplay.setCursor(4, 32);
    sDisplay.printf("Hits: %d", sDetectionCount);
  }

  if (sRssi > -95) {
    sDisplay.setCursor(4, 46);
    sDisplay.printf("RSSI: %d dBm", sRssi);
    int bar = map(constrain(sRssi, -100, -30), -100, -30, 0, 100);
    sDisplay.fillRect(4, 58, map(bar, 0, 100, 0, 120), 6, TFT_GREEN);
  }

  if (sStatusLine[0]) {
    sDisplay.setCursor(4, 72);
    sDisplay.print(sStatusLine);
  }

  nessoUiDrawAlertBar();

  sDisplay.setTextColor(TFT_DARKGREY);
  sDisplay.setCursor(4, 110);
  sDisplay.print("Hold KEY1 (front)");
}

void nessoUiInit() {
  if (sDisplay.begin()) {
    sDisplay.setRotation(1);
    sReady = true;
    sBattery.begin();
    nessoUiDraw();
  }
}

void nessoUiSetMode(const char *modeName) {
  if (modeName) {
    strncpy(sModeName, modeName, sizeof(sModeName) - 1);
    sModeName[sizeof(sModeName) - 1] = '\0';
  }
  nessoUiDraw();
}

void nessoUiSetStatus(const char *line) {
  if (line) {
    strncpy(sStatusLine, line, sizeof(sStatusLine) - 1);
    sStatusLine[sizeof(sStatusLine) - 1] = '\0';
  }
  nessoUiDraw();
}

void nessoUiSetDetectionCount(int count) {
  if (count == sDetectionCount) {
    return;
  }
  sDetectionCount = count;
  nessoUiDraw();
}

void nessoUiUpdateRssi(int rssi) {
  if (rssi == sRssi) {
    return;
  }
  sRssi = rssi;
  nessoUiDraw();
}

void nessoUiFlashAlert() {
  sAlertUntil = millis() + 500;
  if (!sReady) return;
  nessoUiDrawAlertBar();
}

void nessoUiTick() {
  if (!sReady) return;

  unsigned long now = millis();

  if (now - sLastBatteryDraw >= kBatteryRefreshMs) {
    nessoUiDrawBattery();
    sLastBatteryDraw = now;
  }

  if (sAlertUntil != 0 && now > sAlertUntil) {
    sAlertUntil = 0;
    nessoUiDrawAlertBar();
  }
}

#else

void nessoUiInit() {}
void nessoUiSetMode(const char *) {}
void nessoUiSetStatus(const char *) {}
void nessoUiSetDetectionCount(int) {}
void nessoUiUpdateRssi(int) {}
void nessoUiFlashAlert() {}
void nessoUiTick() {}

#endif
