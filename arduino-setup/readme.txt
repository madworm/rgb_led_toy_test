
As the board runs with the internal RC oscillator (8MHz), which may be
a bit unstable and off the target frequency, I recommend to use:

'LilyPad' bootloader, which runs as 19200.

That is more reliable than using 'optiboot' at 115200.

