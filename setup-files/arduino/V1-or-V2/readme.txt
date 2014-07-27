
* Append the contents of the boards.txt.modif... files to the 'boards.txt' file
  of your Arduino IDE setup. It is in the '../hardware/arduino/' folder.

  Make sure you select the right file depending on the version of the IDE.

* Copy the bootloader .hex-file to the ../hardware/arduino/bootloaders/optiboot folder.

* Restart the IDE !

Now you will find the following new boards in the 'boards menu':

+ RGB LED RING - ATmega168 / 8MHz RC OSC / optiboot 19k2 (default)
+ RGB LED RING - ATmega168 / 8MHz RC OSC / ISP
+ RGB LED RING - ATmega168 / 8MHz RC OSC / ATmegaBOOT_168_pro_8MHz (alternative)

The first board should work.

