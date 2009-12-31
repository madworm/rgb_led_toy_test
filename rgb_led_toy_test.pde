/*
2009 - robert:aT:spitzenpfeil_d*t:org - RGB_LED_TOY_TEST
*/

/*
The boards run with the internal oscillator. To stay in sync the MASTER sends a sync pulse
and the SLAVE(s) listen to that. There must only by one MASTER, and as many SLAVE(s) as you like.
Syncing works more or less, it's not perfect. The best thing would be using I2C. Or play with the
OSCCAL registers somehow. Best thing would be a self-syncing algorithm.
*/

/*
If you run the Arduino IDE on windows (works on linux) and want to compile for an ATmega328 chip, you need to replace
_all_ the pin number definitions. Remove the comment marks on the PORT-FIX block in 'rgb_led_toy_test.h' to do so. Arduino-017 comes with a not
so up-to-date version of winavr. "portpins.h" doesn't have the mapping between the old style PB0 and newer PORTB0 names.
*/


/*
Select if the board is a MASTER (sends sync pulse), or a slave (waits for sync pulse)
*/
#define MASTER

#ifndef MASTER
#define SLAVE
#endif


#define __leds 8
#define __max_led __leds - 1

#define F_CPU 8000000UL
#define __AVR_ATmega168__
#include <util/delay.h>
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include "rgb_led_toy_test.h"	// needed to make the 'enum' work with Arduino IDE (and other things)

uint8_t fix_led_numbering[8] = { 0, 1, 2, 3, 5, 4, 6, 7 };	// the PCBs I got still have an error, as the updated design wasn't taken into account by the fab house it seems

/*
void setup(void);
void loop(void);
void white_clockwise(uint8_t times, int delay_time);
void white_counterclockwise(uint8_t times, int delay_time);
void blink_all_red_times(uint8_t times, int delay_time);
void blink_all_green_times(uint8_t times, int delay_time);
void blink_all_blue_times(uint8_t times, int delay_time);
void blink_all_white_times(uint8_t times, int delay_time);
void rotating_bar (enum COLOR_t led_color, enum DIRECTION_t direction,uint8_t times, int delay_time);
void __delay_ms(uint16_t delay_time);

// the arduino IDE doesn't like main...
int main(void);
int main(void) {
  setup();
  while(1) {
    loop();
  }
}
*/

void
setup (void)
{
  DDRB |= ((1 << LED0) | (1 << LED1) | (1 << LED2) | (1 << LED3) | (1 << LED4) | (1 << LED5) | (1 << LED6) | (1 << LED7));	// set PORTB as output
  PORTB = 0xFF;			// all pins HIGH --> cathodes HIGH --> LEDs off
  DDRD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));	// set PORTD #5-7 as output
  PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));	// pins #5-7 LOW --> anodes LOW --> LEDs off
  DDRC &= ~((1 << PC2) | (1 << PC3) | (1 << PC4) | (1 << PC5));	// PC2-5 is an input
  PORTC |= ((1 << PC4));	// internal pull-up on
}

void
loop (void)
{

/*
This block here is contains calibration values for the internal oscillator for boards running with it at about 8MHz. 
You need to determine them yourself. The easiest way is to make a LED blink for a well defined time and use an oscilloscope
to measure it. Adjust 'OSCCAL' to make the time right. There is some code on my blog to show how it may work for you.
*/
#ifdef MASTER
  OSCCAL = 122;			// MASTER board
#else
  OSCCAL = 104;			// SLAVE board
#endif


#ifdef MASTER
  __delay_ms (500);
  DDRC |= ((1 << PC4));		// PC4 is an output
  PORTC &= ~((1 << PC4));	// set PC4 low
  __delay_ms (1);
  PORTC |= ((1 << PC4));	// set PC4 high
  DDRC &= ~((1 << PC4));	// PC4 is an input
  PORTC |= ((1 << PC4));	// internal pull-up on
#endif

#ifdef SLAVE
  while ((PINC & (1 << PC4)))
    {
    };				// wait for sync pulse (low) from master
  __delay_ms (1);
#endif

  blink_all_red_times (10, 20);
  blink_all_green_times (10, 20);
  blink_all_blue_times (10, 20);
  blink_all_white_times (10, 15);

#ifdef MASTER
  white_clockwise (10, 20);
  white_counterclockwise (10, 20);
  rotating_bar (BLUE, CCW, 15, 75);
  rotating_bar (GREEN, CW, 15, 75);
  rotating_bar (RED, CCW, 15, 75);
  rotating_bar (YELLOW, CW, 15, 75);
  rotating_bar (TURQUOISE, CCW, 15, 75);
  rotating_bar (PURPLE, CW, 15, 75);
  rotating_bar (WHITE, CCW, 15, 75);
#endif

#ifdef SLAVE
  white_counterclockwise (10, 20);
  white_clockwise (10, 20);
  rotating_bar (BLUE, CW, 15, 75);
  rotating_bar (GREEN, CCW, 15, 75);
  rotating_bar (RED, CW, 15, 75);
  rotating_bar (YELLOW, CCW, 15, 75);
  rotating_bar (TURQUOISE, CW, 15, 75);
  rotating_bar (PURPLE, CCW, 15, 75);
  rotating_bar (WHITE, CW, 15, 75);
#endif
}

void
rotating_bar (enum COLOR_t led_color, enum DIRECTION_t direction,
	      uint8_t times, int delay_time)
{
  uint8_t ctr1;
  uint8_t ctr2;

  switch (led_color)
    {				// turn ON the necessary anodes
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
    default:
      break;
    }
  switch (direction)
    {
    case CW:
      for (ctr2 = 0; ctr2 < times; ctr2++)
	{
	  for (ctr1 = 0; ctr1 <= __max_led - 4; ctr1++)
	    {
	      PORTB = 0xFF;
	      PORTB &=
		~((1 << fix_led_numbering[ctr1]) |
		  (1 <<
		   fix_led_numbering[((ctr1 + 4) > 7) ? 0 : (ctr1 + 4)]));
	      __delay_ms (delay_time);
	    }
	}
      break;
    case CCW:
      for (ctr2 = 0; ctr2 < times; ctr2++)
	{
	  for (ctr1 = __max_led - 4; (ctr1 >= 0 && ctr1 != 255); ctr1--)
	    {
	      PORTB = 0xFF;
	      PORTB &=
		~((1 << fix_led_numbering[ctr1]) |
		  (1 <<
		   fix_led_numbering[((ctr1 + 4) > 7) ? 0 : (ctr1 + 4)]));
	      __delay_ms (delay_time);
	    }
	}
      break;
    default:
      break;
    }
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
    default:
      break;
    }

}

void
white_clockwise (uint8_t times, int delay_time)
{
  PORTD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
  uint8_t ctr1;
  uint8_t ctr2;
  for (ctr2 = 0; ctr2 < times; ctr2++)
    {
      for (ctr1 = 0; ctr1 <= __max_led; ctr1++)
	{
	  PORTB = 0xFF;
	  PORTB &= ~(1 << fix_led_numbering[ctr1]);
	  __delay_ms (delay_time);
	}
    }
  PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
}

void
white_counterclockwise (uint8_t times, int delay_time)
{
  PORTD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
  uint8_t ctr1;
  uint8_t ctr2;
  for (ctr2 = 0; ctr2 < times; ctr2++)
    {
      for (ctr1 = __max_led; (ctr1 >= 0 && ctr1 != 255); ctr1--)
	{
	  PORTB = 0xFF;
	  PORTB &= ~(1 << fix_led_numbering[ctr1]);
	  __delay_ms (delay_time);
	}
    }
  PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
}

void
blink_all_red_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  PORTD |= ((1 << RED_A));
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  PORTD &= ~((1 << RED_A));
}

void
blink_all_green_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  PORTD |= ((1 << GREEN_A));
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  PORTD &= ~((1 << GREEN_A));
}

void
blink_all_blue_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  PORTD |= ((1 << BLUE_A));
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  PORTD &= ~((1 << BLUE_A));
}

void
blink_all_white_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  PORTD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));
}

void
__delay_ms (uint16_t delay_time)
{
  /*
     this construct is needed to avoid a huge increase in codesize
     if _delay_ms() is called like: _delay_ms(var)
     instead of _delay_ms(const var)
   */
  uint16_t counter;
  for (counter = 0; counter < delay_time; counter++)
    {
      _delay_ms (1);
    }
}
