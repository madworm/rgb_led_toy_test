#!/bin/bash

#
# if you get write errors increase the -B xx value
#
# the bootloader is 'optiboot_lilypad_8MHz_19k2.hex' running at 19200
#

function flash_bootloader {
  avrdude -c $PROGRAMMER -p atmega168 -B 100 -P $PORT -b $BAUDRATE -e -U lock:w:0x3F:m -U lfuse:w:0xE2:m -U hfuse:w:0xDD:m -U efuse:w:0x04:m
  avrdude -c $PROGRAMMER -p atmega168 -B 1 -P $PORT -b $BAUDRATE -U flash:w:$HEXFILE:i -U lock:w:0x0F:m
}

case $2 in
  avrispmkII)
    BAUDRATE="115200"
    PROGRAMMER=$2
    PORT="usb"
    HEXFILE=$1
    flash_bootloader
  ;;
  usbtiny)
    BAUDRATE="115200"
    PROGRAMMER=$2
    PORT="usb"
    HEXFILE=$1
    flash_bootloader
  ;;
  arduinoisp)
    BAUDRATE="19200"
    PROGRAMMER="arduino"
    PORT=${3:-/dev/ttyUSB0}
    HEXFILE=$1
    flash_bootloader
  ;;
  *)
    echo -e  "\n usage: $0 hexfile avrispmkII|usbtiny|arduinoisp port (default: /dev/ttyUSB0)
              \n"
  ;;
esac
