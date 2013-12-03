
Use "Adafruit's" [Neopixel library][neopixel]!

The pixels are connected to the 'DAT' pin on the breakout board.
This is 'PB0' in AVR notation, 'digital pin 8' in Arduino lingo.

Use this line to initialize the library for this breakout board:

Adafruit_NeoPixel strip = Adafruit_NeoPixel(8, 8, NEO_GRB + NEO_KHZ800);


[neopixel]: https://github.com/adafruit/Adafruit_NeoPixel

