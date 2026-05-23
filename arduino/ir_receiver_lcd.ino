#include <IRremote.hpp>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

const int IR_PIN = 11;
const uint8_t END_MARK = 0x0A;

LiquidCrystal_I2C lcd(0x27, 16, 2); // change to 0x3F if needed

char message[50];
int length = 0;
bool waitingForNewMessage = true;

void clearMessageBuffer() {
  length = 0;
  for (int i = 0; i < 50; i++) {
    message[i] = '\0';
  }
}

void showMessageOnLCD() {
  int cursorPos = length;

  lcd.setCursor(0, 0);
  for (int i = 0; i < 16; i++) {
    if (i < length) {
      lcd.print(message[i]);
    } else if (i == cursorPos && cursorPos < 32) {
      lcd.print('_');
    } else {
      lcd.print(' ');
    }
  }

  lcd.setCursor(0, 1);
  for (int i = 0; i < 16; i++) {
    int msgIndex = i + 16;

    if (msgIndex < length) {
      lcd.print(message[msgIndex]);
    } else if (msgIndex == cursorPos && cursorPos < 32) {
      lcd.print('_');
    } else {
      lcd.print(' ');
    }
  }
}

void setup() {
  Serial.begin(9600);
  IrReceiver.begin(IR_PIN, ENABLE_LED_FEEDBACK);

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("puk puk ssay somethingg");

  clearMessageBuffer();

  Serial.println("readyyyy!");
}

void loop() {
  if (IrReceiver.decode()) {
    uint8_t cmd = IrReceiver.decodedIRData.command;

    Serial.print("Received byte: 0x");
    Serial.print(cmd, HEX);
    Serial.print(" char: ");
    Serial.println((char)cmd);

    if (cmd == END_MARK) {
      Serial.println("=== END MARK received ===");
      waitingForNewMessage = true;
    } else {
      if (waitingForNewMessage) {
        lcd.clear();
        clearMessageBuffer();
        waitingForNewMessage = false;
      }

      if (length < 49) {
        message[length++] = (char)cmd;
        message[length] = '\0';
      }

      showMessageOnLCD();
    }

    IrReceiver.resume();
  }
}