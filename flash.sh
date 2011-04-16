#!/bin/bash

#
# if you get write errors increase the -B xx value
#
# the bootloader is optiboot running at 115200
#

avrdude -c usbtiny -p atmega168 -P usb -b 115200 -e -B 100 -U lock:w:0x3f:m -U lfuse:w:0xE2:m -U hfuse:w:0xDD:m -U efuse:w:0x04:m
avrdude -c usbtiny -p atmega168 -B 1 -P usb -b 115200 -U flash:w:rgb_led_toy_test__plus__optiboot_pro_8Mhz.hex -U lock:w:0x0f:m

