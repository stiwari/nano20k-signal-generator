DDS project to generate audio frequency, for the Tang Nano 20K
Connections - usb-c, and a speaker to the 2 wire connector on the side of PCB
Usage:
1. Connect usb-c to laptop.
2. Find the correct device under "ls /dev/cu.*" (connect it and disconnect the nano, and note the one that disappears) mine is /dev/cu.usbserial123456
3. Run "$screen /dev/cu.usbserial123456 115200" (yeah I set the uart speed as 115200, you can change it)
4. Enter F or f, followed by a number from 1-nnn, e.g. f700 == generate 700hz

UART: F700

   ↓
   
command_parser

   ↓
   
frequency_hz
   
   ↓
   
frequency_to_phase
   
   ↓
   
phase_inc
   
   ↓
   
DDS / NCO @ 48 kHz
   
   ↓
   
sine ROM
   
   ↓
   
16-bit sine_sample
   
   ↓
   
I²S serializer
   
   ↓
   
DATA / LRCK / BCLK
   
   ↓
   
MAX98357A
   
   ↓
   
speaker → 700 Hz

Enjoy!
