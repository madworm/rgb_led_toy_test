
As the board runs with the internal RC oscillator (8MHz), which may be
a bit unstable and off the target frequency, I recommend to use:

'ATmegaBOOT_168_pro_8MHz.hex' bootloader, which runs as 19200.

That is much more reliable than using 'optiboot' at 115200.

