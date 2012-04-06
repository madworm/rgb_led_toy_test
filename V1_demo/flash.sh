#!/bin/bash

#
# if you get write errors increase the -B xx value
#
# the bootloader is LilyPadBOOT_168.hex running at 19200
#

function flash_bootloader {
  avrdude -c $PROGRAMMER -p atmega168 -B 100 -P $PORT -b $BAUDRATE -e -U lock:w:0x3F:m -U lfuse:w:0xE2:m -U hfuse:w:0xDD:m -U efuse:w:0x00:m
  avrdude -c $PROGRAMMER -p atmega168 -B 1 -P $PORT -b $BAUDRATE -U flash:w:V1_demo__plus__LilyPadBOOT_168_8Mhz.hex -U lock:w:0x0F:m
}

case $1 in
  usbtiny)
    BAUDRATE="115200"
    PROGRAMMER=$1
    PORT="usb"
    flash_bootloader
  ;;
  arduinoisp)
    BAUDRATE="19200"
    PROGRAMMER="arduino"
    PORT=${2:-/dev/ttyUSB0}
    flash_bootloader
  ;;
  *)
    echo -e  "\n usage: $0 usbtiny|arduinoisp port (default: /dev/ttyUSB0)
              \n"
  ;;
esac
