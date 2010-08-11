/*
 * 2010-08-11 (YYYY-MM-DD) - robert:aT:spitzenpfeil_d*t:org - RGB_LED_TOY_TEST
 */

#define NEW_PCB_yellow
//#define NEW_PCB_green
//#define OLD_PCB


#include <util/delay.h>
#include <stdint.h>
#include <avr/io.h>
#include <avr/pgmspace.h>
#include <Wire.h>
#include "I2C_tic_tac_toe.h"	// needed to make the 'enum' work with Arduino IDE (and other things)


#ifdef NEW_PCB_yellow
uint8_t fix_led_numbering[8] = { 0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef NEW_PCB_green
uint8_t fix_led_numbering[8] = { 0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef OLD_PCB
uint8_t fix_led_numbering[8] = { 3, 5, 4, 6, 7, 0, 1, 2 };	// this is necessary for older revisions (without DTR or >= 1.21 printed on the PCB)
#endif


#define MASTER

#ifndef MASTER
#define SLAVE
#endif


const uint8_t anim__twi_targets[9] PROGMEM = {0x10,0x11,0x14,0x18,0x15,0x13,0x12,0x16,0x17}; // the tic-tac-toe sequence is encoded in this
const COLOR_t anim__colors[9]      PROGMEM = {RED,GREEN,RED,GREEN,RED,GREEN,RED,GREEN,RED}; // colors
const uint8_t anim__delays[9]      PROGMEM = {100,100,100,100,100,100,100,100,300}; // delays in ms after each step

#define MASTER_TWI_DUMMY_ADDRESS 0x10 // just so the master board knows which part of the animation takes place using its own LEDS!
#define __GAME_TIMEOUT 1000 // 20 seconds
#define __DELAY_SCALER 2

void
setup (void)
{
  Wire.begin();  
  DDRB |= ((1 << LED0) | (1 << LED1) | (1 << LED2) | (1 << LED3) | (1 << LED4) | (1 << LED5) | (1 << LED6) | (1 << LED7));	// set PORTB as output
  PORTB = 0xFF;			// all pins HIGH --> cathodes HIGH --> LEDs off
  DDRD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));	// set PORTD #5-7 as output
  PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));	// pins #5-7 LOW --> anodes LOW --> LEDs off
  DDRC &= ~((1 << PC2) | (1 << PC3) | (1 << PC4) | (1 << PC5));	// PC2-5 is an input
  PORTC |= ((1<<PC4) | (1<<PC5)); // internal pullups on for the I2C lines
  //DDRC |= ((1 << PC2) | (1 << PC3)); // define as outputs. just a hack on the pcb to use 10k pullups for the I2C lines
  //PORTC |= ((1 << PC2) | (1 << PC3)); // set to high
}


void
loop (void)
{
#ifdef MASTER
  clear_game();
  __delay_ms(500);

  uint8_t counter;

  for(counter = 0; counter <=8; counter++) {
    uint8_t anim__target_addr = pgm_read_byte(&anim__twi_targets[counter]);
    uint8_t anim__color = pgm_read_byte(&anim__colors[counter]);
    uint8_t anim__delay = pgm_read_byte(&anim__delays[counter]);

    if(anim__target_addr == MASTER_TWI_DUMMY_ADDRESS) {
      color_on(BLACK); // turn everything off (anodes)
      PORTB = 0xFF; // turn everything off (cathodes)
      color_on((COLOR_t)(anim__color));
      PORTB = 0x00;
    }
    else {
      Wire.beginTransmission(anim__target_addr); // the position of the target board in the 3x3 matrix is encoded in its address
      Wire.send(anim__color);
      Wire.endTransmission(); 
    }
    __delay_ms((uint16_t)(__DELAY_SCALER*anim__delay));
  }  
  __delay_ms(__GAME_TIMEOUT);
#endif

#ifdef SLAVE
  Wire.begin(0x11); // This has to be adapted for boards 1 to 8, as they are the slaves. Board 0 is the master and times the animation.
  Wire.onReceive(slave_handler); // slave_handler() will be executed after in interrupt for incoming TWI transmission has been triggered.
  while(1) {
    // therefore we just wait here till we lose power
  } 
#endif
}

void slave_handler(int dummy_rcvd_bytes) { 
  uint8_t tmp = 0;
  tmp = Wire.receive(); // get the incoming data (not the address, that step is abstracted away in the library)
  color_off(WHITE); // turn everything off (anodes)
  PORTB = 0xFF; // turn everything off (cathodes)
  color_on((COLOR_t)(tmp));
  PORTB = 0x00;
}

void
__delay_ms (uint16_t delay_time)
{
  /*
   * this construct is needed to avoid a huge increase in codesize
   * if _delay_ms() is called like: _delay_ms(var)
   * instead of _delay_ms(const var)
   */
  uint16_t counter;
  for (counter = 0; counter < delay_time; counter++)
    {
      _delay_ms (1);
    }
}

void
color_on (enum COLOR_t led_color) {
  switch (led_color) {				// turn ON the necessary anodes
    case RED:
      PORTD |= ((1 << RED_A));
      break;
    case GREEN:
      PORTD |= ((1 << GREEN_A));
      break;
    case BLUE:
      PORTD |= ((1 << BLUE_A));
      break;
    case YELLOW:
      PORTD |= ((1 << RED_A) | (1 << GREEN_A));
      break;
    case TURQUOISE:
      PORTD |= ((1 << GREEN_A) | (1 << BLUE_A));
      break;
    case PURPLE:
      PORTD |= ((1 << RED_A) | (1 << BLUE_A));
      break;
    case WHITE:
      PORTD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
      break;
    case BLACK:
      PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
      break;
    default:
      break;
    }
}

void
color_off (enum COLOR_t led_color)
{
  switch (led_color)
    {				// turn OFF the anodes again when we're done
    case RED:
      PORTD &= ~((1 << RED_A));
      break;
    case GREEN:
      PORTD &= ~((1 << GREEN_A));
      break;
    case BLUE:
      PORTD &= ~((1 << BLUE_A));
      break;
    case YELLOW:
      PORTD &= ~((1 << RED_A) | (1 << GREEN_A));
      break;
    case TURQUOISE:
      PORTD &= ~((1 << GREEN_A) | (1 << BLUE_A));
      break;
    case PURPLE:
      PORTD &= ~((1 << RED_A) | (1 << BLUE_A));
      break;
    case WHITE:
      PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
      break;
    case BLACK:
      PORTD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
      break;
    default:
      break;
    }
}

void clear_game(void) {
  uint8_t counter;
  for(counter = 0; counter <=8; counter++) {
    uint8_t anim__target_addr = pgm_read_byte(&anim__twi_targets[counter]);
    uint8_t anim__color = BLACK;

    if(anim__target_addr == MASTER_TWI_DUMMY_ADDRESS) {
      color_on(BLACK); // turn everything off (anodes)
      PORTB = 0xFF; // turn everything off (cathodes)
    }
    else {
      Wire.beginTransmission(anim__target_addr); // the position of the target board in the 3x3 matrix is encoded in its address
      Wire.send(anim__color);
      Wire.endTransmission(); 
    }
  }  
}


