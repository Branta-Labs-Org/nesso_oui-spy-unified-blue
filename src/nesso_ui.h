#ifndef NESSO_UI_H
#define NESSO_UI_H

#include <Arduino.h>

void nessoUiInit();
void nessoUiSetMode(const char *modeName);
void nessoUiSetStatus(const char *line);
void nessoUiSetDetectionCount(int count);
void nessoUiUpdateRssi(int rssi);
void nessoUiFlashAlert();
void nessoUiTick();

#endif
