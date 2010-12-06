#!/bin/bash

# no bootloader, internal RC oscillator @ 8MHz

HEXFILE="xmas_chain.cpp.hex"

find /tmp/build* -iname "$HEXFILE" -exec cp {} . \;
avrdude -c usbtiny -p atmega168 -P usb -b 115200 -e -B 100 -U lock:w:0x3F:m -U lfuse:w:0xE2:m -U hfuse:w:0xDD:m -U efuse:w:0x01:m
avrdude -v -B 1 -c usbtiny -p atmega168 -U flash:w:$HEXFILE:i \;
