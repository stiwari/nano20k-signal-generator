DSP on FPGA using the tiny Tang Nano 20K.
------------------------------------------
Goal:
- Detect CW signals buried way below in noise
- Humans can detect upto 17db below noise
- FT8 can do upto -23 to -27db
- This project aims to lower it to -30 or -40db or even -50db (though this chip tang nano20k, will not have enough power to do beyond -30db

Steps
1. Generate audio frequency tone (DDS), controlled from terminal window via the USB port.
2. Generate tone, and Noise (LFSR) and add them, tone at 50db below the noise - Baseband
     This is a simulated version of a baseband coming out of an RF front end that has been mixed down. (Direct Conversion)
3. Generate another 700Hz tone (or reuse the same one) mix it with the baseband - Mixer
4. Integrate the ouput from mixer for just energy detection - Integrator
5. Regenerate the Detected CW signal

Step 1
-------

Connections - usb-c, and a speaker to the 2 wire connector on the side of PCB
Usage:
1. Connect usb-c to laptop.
2. Find the correct device under "ls /dev/cu.*" (connect it and disconnect the nano, and note the one that disappears) mine is /dev/cu.usbserial123456
3. Run "$screen /dev/cu.usbserial123456 115200" (yeah I set the uart speed as 115200, you can change it)
4. Enter F or f, followed by a number from 1-nnn, e.g. f700 == generate 700hz

Here are the verilog modules starting from laptop connecting over USB (UART at 115200bps), and sending a command like f700 to sound coming from the speaker

Terminal: F700<Enter> -> command_parser -> frequency_hz -> frequency_to_phase -> phase_inc -> DDS/NCO@48kHz ->sine ROM -> 16-bit sine_sample -> 
I²S serializer -> DATA/LRCK/BCLK -> MAX98357A -> Speaker → 700 Hz
