#include <Arduino_Nesso_N1.h>

NessoDisplay display;
NessoBattery battery;

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("Nesso N1 hello");

  if (display.begin()) {
    display.setRotation(1);
    display.fillScreen(TFT_WHITE);
    display.setTextColor(TFT_BLACK);
    display.setTextSize(2);
    display.drawString("Hello!", 50, 60);
    Serial.println("Display initialized");
  } else {
    Serial.println("Display init failed");
  }

  battery.begin();
  Serial.printf("Battery: %.2f V, %u%%\n", battery.getVoltage(), battery.getChargeLevel());
}

void loop() {
  static unsigned long lastHeartbeat = 0;

  if (millis() - lastHeartbeat >= 1000) {
    lastHeartbeat = millis();
    Serial.printf("heartbeat uptime=%lu ms\n", millis());
  }
}
