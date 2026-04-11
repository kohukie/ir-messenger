# ir-messenger

This project implements a custom IR communication system between a Flipper Zero and an Arduino. ASCII characters are encoded into NEC-like IR signals and decoded on the Arduino side, where they are displayed on an LCD.

## How it works:
1. A character (e.g. 'A') is converted to its ASCII value (`0x41`)
2. The byte is split into bits (LSB first)
3. Each bit is encoded into IR timings:
   - `0` → 560 µs ON + 560 µs OFF  
   - `1` → 560 µs ON + 1690 µs OFF  
4. A full message is sent as: `START → ADDRESS → ~ADDRESS → COMMAND → ~COMMAND → END`
5. The Arduino receives the signal, decodes it, and reconstructs the message
6. The message is displayed on an LCD screen

## Hardware:
- Flipper Zero
- Arduino Uno
- IR receiver
- 16x2 LCD (I2C)

## Project structure:
- `.cpp` → application logic  
- `.fam` → Flipper app metadata  
- `.fap` → compiled binary (generated with `ufbt build`)
- `.ino` → Arduino
