
The board runs with the internal RC oscillator (8MHz), which may be
a bit unstable and off the target frequency.

The default board to use is this:

* RGB LED RING - ATmega168 / 8MHz RC OSC / optiboot


However, if you have trouble getting a reliable upload, use this:

* RGB LED RING - ATmega168 / 8MHz RC OSC / ATmegaBOOT_168_pro_8MHz


! Changing the board type also requires re-flashing the bootloader !


! Don't forget to copy the bootloader to the arduino folder !

