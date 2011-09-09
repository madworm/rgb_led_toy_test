#include <stdint.h>

/*
 * The LEDs are connected to these pins:
 *
 * all RED anodes go to: 'PD6' - equivalent Arduino pin: digital pin #6
 * all GREEN anodes go to: 'PD5' - equivalent Arduino pin: digital pin #5
 * all BLUE anodes go to: 'PD7' - equivalent Arduino pin: digital pin #7
 *
 * common cathode LED0: 'PB0' - equivalent Arduino pin: digital pin #8
 * common cathode LED1: 'PB1' - equivalent Arduino pin: digital pin #9
 * common cathode LED2: 'PB2' - equivalent Arduino pin: digital pin #10
 * common cathode LED3: 'PB3' - equivalent Arduino pin: digital pin #11
 * common cathode LED4: 'PB4' - equivalent Arduino pin: digital pin #12
 * common cathode LED5: 'PB5' - equivalent Arduino pin: digital pin #13
 * common cathode LED6: 'PB6' - equivalent Arduino pin: -none-
 * common cathode LED7: 'PB7' - equivalent Arduino pin: -none-
 *
 * The headers on the backside expose:
 *
 * SCL ('PC5') - equivalent Arduino pin: analog pin #5 / digital pin #19
 * SCA ('PC4') - equivalent Arduino pin: analog pin #4 / digital pin #18
 * 'PC3' - equivalent Arduino pin: analog pin #3 / digital pin #17
 * 'PC2' - equivalent Arduino pin: analog pin #2 / digital pin #16
 *
 */

void setup(void) {
  pinMode(5,OUTPUT); // get ready to give power to all RED LEDs
  pinMode(6,OUTPUT); // same for GREEN
  pinMode(7,OUTPUT); // same for BLUE
  pinMode(8,OUTPUT); // deal with LED0
}

void loop(void) {
  digitalWrite(6,HIGH); // give power to RED
  digitalWrite(8,LOW); // turn on LED0
  delay(1000); // wait 1 second
  digitalWrite(8,HIGH); // turn off LED0
  digitalWrite(6,LOW); // turn off power to RED
  delay(1000);

  digitalWrite(5,HIGH); // give power to GREEN
  digitalWrite(8,LOW); // turn on LED0
  delay(1000); // wait 1 second
  digitalWrite(8,HIGH); // turn off LED0
  digitalWrite(5,LOW); // turn off power to GREEN
  delay(1000);

  digitalWrite(7,HIGH); // give power to BLUE
  digitalWrite(8,LOW); // turn on LED0
  delay(1000); // wait 1 second
  digitalWrite(8,HIGH); // turn off LED0
  digitalWrite(7,LOW); // turn off power to BLUE
  delay(1000);

  digitalWrite(6,HIGH); // give power to RED
  digitalWrite(5,HIGH); // give power to GREEN
  digitalWrite(7,HIGH); // give power to BLUE
  digitalWrite(8,LOW); // turn on LED0
  delay(1000); // wait 1 second
  digitalWrite(8,HIGH); // turn off LED0
  digitalWrite(7,LOW); // turn off power to BLUE
  digitalWrite(5,LOW); // turn off power to GREEN
  digitalWrite(6,LOW); // turn off power to RED
  delay(1000);
}
