/*
 * 2010-01-30 (YYYY-MM-DD) - robert:aT:spitzenpfeil_d*t:org - RGB_LED_TOY_TEST
 */

/*
 * The boards run with the internal oscillator. To stay in sync the MASTER sends a sync pulse
 * and the SLAVE(s) listen to that. There must only by one MASTER, and as many SLAVE(s) as you like.
 * Syncing works more or less, it's not perfect. The best thing would be using I2C. Or play with the
 * OSCCAL registers somehow. Best thing would be a self-syncing algorithm.
 */

/*
 * If you run the Arduino IDE on windows (works on linux) and want to compile for an ATmega328 chip, you need to replace
 * _all_ the pin number definitions. Remove the comment marks on the PORT-FIX block in 'rgb_led_toy_test.h' to do so. Arduino-017 comes with a not
 * so up-to-date version of winavr. "portpins.h" doesn't have the mapping between the old style PB0 and newer PORTB0 names.
 */

/*
 * If you use an Arduino bootloader, I recommend the "ATmegaBOOT_168_pro_8MHz.hex".
 * Set the FUSE bytes to: LFUSE:0xE2 - HFUSE:0xDD - EFUSE:0x00 (avrdude convention)
 */


/*
 * Select if the board is a MASTER (sends sync pulse), or a slave (waits for sync pulse)
 */
#define MASTER

#ifndef MASTER
#define SLAVE
#endif


#define __leds 8
#define __max_led __leds - 1

#define __brightness_levels 64	// 0...15 above 28 is bad for ISR ( move to timer1, lower irq freq ! )
#define __max_brightness __brightness_levels-1

#define __TIMER1_MAX 0xFFFF	// 16 bit CTR
#define __TIMER1_CNT 0x0030	//

#define F_CPU 8000000UL
#define __AVR_ATmega168__
#include <util/delay.h>
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include "rgb_led_toy_test.h"	// needed to make the 'enum' work with Arduino IDE (and other things)

/*
 * uint8_t fix_led_numbering[8] = { 3, 5, 4, 6, 7, 0, 1, 2 };	// the PCBs I got still have an error, as the updated design wasn't taken into account by the fab house it seems
 */

uint8_t fix_led_numbering[8] = { 0, 1, 2, 3, 4, 5, 6, 7 }; // up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)

uint8_t brightness_red[__leds];	/* memory for RED LEDs */
uint8_t brightness_green[__leds];	/* memory for GREEN LEDs */
uint8_t brightness_blue[__leds];	/* memory for BLUE LEDs */

#define YES 1
#define NO 0
#define DOTCORR NO		/* enable/disable dot correction */

#if (DOTCORR == YES)
const int8_t PROGMEM dotcorr_red[__leds] = { 0, 0, 0, 0, 0, 0, 0, 0 };
const int8_t PROGMEM dotcorr_green[__leds] = { 0, 0, 0, 0, 0, 0, 0, 0 };
const int8_t PROGMEM dotcorr_blue[__leds] = { 0, 0, 0, 0, 0, 0, 0, 0 };

#define __fade_delay 5
#else
#define __fade_delay 5
#endif


void
setup (void)
{
  DDRB |= ((1 << LED0) | (1 << LED1) | (1 << LED2) | (1 << LED3) | (1 << LED4) | (1 << LED5) | (1 << LED6) | (1 << LED7));	// set PORTB as output
  PORTB = 0xFF;			// all pins HIGH --> cathodes HIGH --> LEDs off
  DDRD |= ((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));	// set PORTD #5-7 as output
  PORTD &= ~((1 << RED_A) | (1 << GREEN_A) | (1 << BLUE_A));	// pins #5-7 LOW --> anodes LOW --> LEDs off
  DDRC &= ~((1 << PC2) | (1 << PC3) | (1 << PC4) | (1 << PC5));	// PC2-5 is an input
  PORTC |= ((1 << PC4));	// internal pull-up on
  randomSeed (555);
  setup_timer1_ovf ();		/* set timer1 to normal mode (16bit counter) and prescaler. enable/disable via extra functions! */
  set_all_rgb (0, 0, 0);	/* set the display to BLACK. Only affects PWM mode */
}

void
loop (void)
{

/*
 * This block here is contains calibration values for the internal oscillator for boards running with it at about 8MHz. 
 * You need to determine them yourself. The easiest way is to make a LED blink for a well defined time and use an oscilloscope
 * to measure it. Adjust 'OSCCAL' to make the time right. There is some code on my blog to show how it may work for you.
 */
#define __sync_delay 75		// this really needs to be fixed by a much better oscillator calibration --> new digital scope !
#ifdef MASTER
  //OSCCAL = 122;            // MASTER board
#else
  //OSCCAL = 104;            // SLAVE board
#endif

  enable_timer1_ovf ();		// start PWM mode
  int ctr;
  for (ctr = 0; ctr < 2; ctr++)
    {
      fader ();
    }
  for (ctr = 0; ctr < 2; ctr++)
    {
      fader_hue ();
    }
  for (ctr = 0; ctr < 1000; ctr++)
    {
      color_wave (30);
    }
  disable_timer1_ovf ();	// end PWM mode

  sync (4 * __sync_delay);
  blink_all_red_times (10, 20);
  sync (__sync_delay);
  blink_all_green_times (10, 20);
  sync (__sync_delay);
  blink_all_blue_times (10, 20);
  sync (__sync_delay);
  blink_all_white_times (10, 20);

#ifdef MASTER
  sync (__sync_delay);
  wobble2 (wobble_pattern_1, 8, RED, CW, 10, 80);
  sync (__sync_delay);
  wobble2 (wobble_pattern_3, 8, YELLOW, CW, 10, 80);
  sync (__sync_delay);
  white_clockwise (10, 20);
  sync (__sync_delay);
  white_counterclockwise (10, 20);
  sync (__sync_delay);
  rotating_bar (BLUE, CCW, 15, 75);
  sync (__sync_delay);
  rotating_bar (GREEN, CW, 15, 75);
  sync (__sync_delay);
  rotating_bar (RED, CCW, 15, 75);
  sync (__sync_delay);
  rotating_bar (YELLOW, CW, 15, 75);
  sync (__sync_delay);
  rotating_bar (TURQUOISE, CCW, 15, 75);
  sync (__sync_delay);
  rotating_bar (PURPLE, CW, 15, 75);
  sync (__sync_delay);
  rotating_bar (WHITE, CCW, 15, 75);
#endif

#ifdef SLAVE
  sync (__sync_delay);
  wobble2 (wobble_pattern_1, 8, RED, CCW, 10, 80);
  sync (__sync_delay);
  wobble2 (wobble_pattern_3, 8, YELLOW, CCW, 10, 80);
  sync (__sync_delay);
  white_counterclockwise (10, 20);
  sync (__sync_delay);
  white_clockwise (10, 20);
  sync (__sync_delay);
  rotating_bar (BLUE, CW, 15, 75);
  sync (__sync_delay);
  rotating_bar (GREEN, CCW, 15, 75);
  sync (__sync_delay);
  rotating_bar (RED, CW, 15, 75);
  sync (__sync_delay);
  rotating_bar (YELLOW, CCW, 15, 75);
  sync (__sync_delay);
  rotating_bar (TURQUOISE, CW, 15, 75);
  sync (__sync_delay);
  rotating_bar (PURPLE, CCW, 15, 75);
  sync (__sync_delay);
  rotating_bar (WHITE, CW, 15, 75);
#endif
}

void
sync (int sync_delay)
{
#ifdef MASTER
  __delay_ms (sync_delay);
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
}

void
rotating_bar (enum COLOR_t led_color, enum DIRECTION_t direction,
	      uint8_t times, int delay_time)
{
  uint8_t ctr1;
  uint8_t ctr2;
  color_on (led_color);
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
		  (1 << fix_led_numbering[(ctr1 + 4)]));
	      __delay_ms (delay_time);
	    }
	}
      break;
    case CCW:
      for (ctr2 = 0; ctr2 < times; ctr2++)
	{
	  for (ctr1 = __max_led - 4 + 1; ctr1 >= 1; ctr1--)
	    {
	      PORTB = 0xFF;
	      PORTB &=
		~((1 << fix_led_numbering[ctr1]) |
		  (1 << fix_led_numbering[(ctr1 + 4) % 8]));
	      __delay_ms (delay_time);
	    }
	}
      break;
    default:
      break;
    }
  color_off (led_color);
}

void
white_clockwise (uint8_t times, int delay_time)
{
  color_on (WHITE);
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
  color_off (WHITE);
}

void
white_counterclockwise (uint8_t times, int delay_time)
{
  color_on (WHITE);
  uint8_t ctr1;
  uint8_t ctr2;
  for (ctr2 = 0; ctr2 < times; ctr2++)
    {
      for (ctr1 = __max_led + 1; ctr1 >= 1; ctr1--)
	{
	  PORTB = 0xFF;
	  PORTB &= ~(1 << fix_led_numbering[ctr1 % 8]);
	  __delay_ms (delay_time);
	}
    }
  color_off (WHITE);
}

void
blink_all_red_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  color_on (RED);
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  color_off (RED);
}

void
blink_all_green_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  color_on (GREEN);
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  color_off (GREEN);
}

void
blink_all_blue_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  color_on (BLUE);
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  color_off (BLUE);
}

void
blink_all_white_times (uint8_t times, int delay_time)
{
  uint8_t ctr;
  color_on (WHITE);
  for (ctr = 0; ctr < times; ctr++)
    {
      PORTB = 0x00;
      __delay_ms (delay_time);
      PORTB = 0xFF;		// off
      __delay_ms (delay_time);
    }
  color_off (WHITE);
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
set_byte (unsigned char data_byte)
{
  unsigned char ctr;
  unsigned char what_bit;
  for (ctr = 0; ctr <= 7; ctr++)
    {
      what_bit = (1 << ctr);
      if (data_byte & what_bit)
	{
	  PORTB &= ~(1 << fix_led_numbering[ctr]);	// cathode low, LED on
	}
      else
	{
	  PORTB |= (1 << fix_led_numbering[ctr]);
	}
    }
}

void
wobble2 (uint8_t * wobble_pattern_ptr, uint8_t pattern_length,
	 enum COLOR_t led_color, enum DIRECTION_t direction, uint8_t times,
	 int delay_time)
{
  uint8_t ctr1;
  uint8_t ctr2;
  color_on (led_color);
  switch (direction)
    {
    case CW:
      for (ctr1 = 0; ctr1 < times; ctr1++)
	{
	  for (ctr2 = 0; ctr2 < pattern_length; ctr2++)
	    {
	      set_byte (wobble_pattern_ptr[ctr2]);
	      __delay_ms (delay_time);
	    }
	}
      break;
    case CCW:
      for (ctr1 = 0; ctr1 < times; ctr1++)
	{
	  for (ctr2 = 0; ctr2 < pattern_length; ctr2++)
	    {
	      set_byte (rotate_byte (wobble_pattern_ptr[ctr2], 4, CW));
	      __delay_ms (delay_time);
	    }
	}
      break;
    default:
      break;
    }
  color_off (led_color);
}

uint8_t
rotate_byte (uint8_t in_byte, uint8_t steps, enum DIRECTION_t direction)
{
  uint8_t result = in_byte;
  uint8_t ctr1;
  switch (direction)
    {
    case CW:
      for (ctr1 = 0; ctr1 < steps; ctr1++)
	{
	  result = (result << 7) | (result >> 1);
	}
      break;
    case CCW:
      for (ctr1 = 0; ctr1 < steps; ctr1++)
	{
	  result = (result >> 7) | (result << 1);
	}
      break;
    default:
      break;
    }
  return result;
}

void
color_on (enum COLOR_t led_color)
{
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
    default:
      break;
    }
}

/*
 * PWM_BLOCK_START: all functions in this block are related to PWM mode !
 */

/*
 * other functions
 */

void
random_leds (void)
{
  set_led_hue ((uint8_t) (random (__leds)), (unsigned int) (random (360)));
}

void
fader (void)
{				/* fade the matrix form BLACK to WHITE and back */
  uint8_t ctr1;
  uint8_t led;

  for (ctr1 = 0; ctr1 <= __max_brightness; ctr1++)
    {
      for (led = 0; led <= __max_led; led++)
	{
	  set_led_rgb (led, ctr1, ctr1, ctr1);
	}
      delay (__fade_delay);
    }

  for (ctr1 = __max_brightness; (ctr1 >= 0) & (ctr1 != 255); ctr1--)
    {
      for (led = 0; led <= __max_led; led++)
	{
	  set_led_rgb (led, ctr1, ctr1, ctr1);
	}
      delay (__fade_delay);
    }
}

void
fader_hue (void)
{				/* cycle the color of the whole matrix */
  int ctr1;
  for (ctr1 = 0; ctr1 < 360; ctr1 = ctr1 + 3)
    {
      set_all_hue (ctr1);
      delay (__fade_delay);
    }
}

void
color_wave (int width)
{
  uint8_t led;
  static unsigned int shift = 0;
  for (led = 0; led <= __max_led; led++)
    {
      set_led_hue (led, (unsigned int) (led * width + shift));
    }
  shift++;
}


/*
 *basic functions to set the LEDs
 */

void
set_led_red (uint8_t led, uint8_t red)
{
#if (DOTCORR == YES)
  int8_t dotcorr =
    (int8_t) (pgm_read_byte (&dotcorr_red[led])) * red / __brightness_levels;
  uint8_t value;
  if (red + dotcorr < 0)
    {
      value = 0;
    }
  else
    {
      value = red + dotcorr;
    }
  brightness_red[led] = value;
#else
  brightness_red[led] = red;
#endif
}

void
set_led_green (uint8_t led, uint8_t green)
{
#if (DOTCORR == YES)
  int8_t dotcorr =
    (int8_t) (pgm_read_byte (&dotcorr_green[led])) * green /
    __brightness_levels;
  uint8_t value;
  if (green + dotcorr < 0)
    {
      value = 0;
    }
  else
    {
      value = green + dotcorr;
    }
  brightness_green[led] = value;
#else
  brightness_green[led] = green;
#endif
}

void
set_led_blue (uint8_t led, uint8_t blue)
{
#if (DOTCORR == YES)
  int8_t dotcorr =
    (int8_t) (pgm_read_byte (&dotcorr_blue[led])) * blue /
    __brightness_levels;
  uint8_t value;
  if (blue + dotcorr < 0)
    {
      value = 0;
    }
  else
    {
      value = blue + dotcorr;
    }
  brightness_blue[led] = value;
#else
  brightness_blue[led] = blue;
#endif
}

void
set_led_rgb (uint8_t led, uint8_t red, uint8_t green, uint8_t blue)
{
  set_led_red (led, red);
  set_led_green (led, green);
  set_led_blue (led, blue);
}

void
set_all_rgb (uint8_t red, uint8_t green, uint8_t blue)
{
  uint8_t ctr1;
  for (ctr1 = 0; ctr1 <= __max_led; ctr1++)
    {
      set_led_rgb (ctr1, red, green, blue);
    }
}

void
set_all_hue (unsigned int hue)
{
  uint8_t ctr1;
  for (ctr1 = 0; ctr1 <= __max_led; ctr1++)
    {
      set_led_hue (ctr1, hue);
    }
}

void
set_led_hue (uint8_t led, unsigned int hue)
{

  /* finally thrown out all of the float stuff and replaced with unsigned int */

  hue = hue % 360;
  uint8_t sector = hue / 60;
  uint8_t rel_pos = hue - (hue / 60) * 60;
  unsigned int modulation_depth = 0xFFFF;
  unsigned int slope = modulation_depth / 120;	/* 2*60 */
  unsigned int a = slope * rel_pos;
  unsigned int b = slope * rel_pos + modulation_depth / 2;
  unsigned int c = modulation_depth - slope * rel_pos;
  unsigned int d = modulation_depth / 2 - slope * rel_pos;

  unsigned int R, G, B;

  if (sector == 0)
    {
      R = c;
      G = a;
      B = 0;
    }
  else if (sector == 1)
    {
      R = d;
      G = b;
      B = 0;
    }
  else if (sector == 2)
    {
      R = 0;
      G = c;
      B = a;
    }
  else if (sector == 3)
    {
      R = 0;
      G = d;
      B = b;
    }
  else if (sector == 4)
    {
      R = a;
      G = 0;
      B = c;
    }
  else
    {
      R = b;
      G = 0;
      B = d;
    }

  unsigned int scale_factor = modulation_depth / __max_brightness;

  R = (uint8_t) (R / scale_factor);
  G = (uint8_t) (G / scale_factor);
  B = (uint8_t) (B / scale_factor);

  set_led_rgb (led, R, G, B);
}

void
set_all_byte_hue (uint8_t data_byte, unsigned int hue)
{
  uint8_t led;
  for (led = 0; led <= __max_led; led++)
    {
      if ((data_byte >> led) & (B00000001))
	{
	  set_led_hue (led, hue);
	}
      else
	{
	  set_led_rgb (led, 0, 0, 0);
	}
    }
}


/*
 * Functions dealing with hardware specific jobs / settings
 */

void
setup_timer1_ovf (void)
{
  // Arduino runs at 16 Mhz...
  // Timer1 (16bit) Settings:
  // prescaler (frequency divider) values:   CS12    CS11   CS10
  //                                           0       0      0    stopped
  //                                           0       0      1      /1  
  //                                           0       1      0      /8  
  //                                           0       1      1      /64
  //                                           1       0      0      /256 
  //                                           1       0      1      /1024
  //                                           1       1      0      external clock on T1 pin, falling edge
  //                                           1       1      1      external clock on T1 pin, rising edge
  //
  TCCR1B &= ~((1 << CS11));
  TCCR1B |= ((1 << CS12) | (1 << CS10));
  //normal mode (16bit counter)
  TCCR1B &= ~((1 << WGM13) | (1 << WGM12));
  TCCR1A &= ~((1 << WGM11) | (1 << WGM10));
  // enable global interrupts flag
  sei ();
}

void
enable_timer1_ovf (void)
{
  TIMSK1 |= (1 << TOIE1);
  TCNT1 = __TIMER1_MAX - __TIMER1_CNT;
}

void
disable_timer1_ovf (void)
{
  TIMSK1 &= ~(1 << TOIE1);
}

ISR (TIMER1_OVF_vect)
{				/* Framebuffer interrupt routine */
  TCNT1 = __TIMER1_MAX - __TIMER1_CNT;
  uint8_t cycle;

  for (cycle = 0; cycle < __max_brightness; cycle++)
    {
      uint8_t led;
      for (led = 0; led <= __max_led; led++)
	{

	  PORTB = 0xFF;		// all cathodes HIGH --> OFF
	  PORTD &= ~((1 << PD5) | (1 << PD6) | (1 << PD7));	// all relevant anodes LOW --> OFF
	  PORTB &= ~(1 << fix_led_numbering[led]);	// only turn on the LED that we deal with right now (current sink, on when zero)

	  if (cycle < brightness_red[led])
	    {
	      PORTD |= (1 << PD5);
	    }

	  if (cycle < brightness_green[led])
	    {
	      PORTD |= (1 << PD6);
	    }

	  if (cycle < brightness_blue[led])
	    {
	      PORTD |= (1 << PD7);
	    }
	}
    }
  PORTB = 0xFF;			// all cathodes HIGH --> OFF
}

/*
 * PWM_BLOCK_END: all functions in this block are related to PWM mode !
 */


/*
 * obsolete functions, only kept for reference
 */

void
wobble (enum COLOR_t led_color, enum DIRECTION_t direction,
	uint8_t times, int delay_time)
{
  uint8_t ctr;
  color_on (led_color);
  switch (direction)
    {
    case CW:
      for (ctr = 0; ctr < times; ctr++)
	{
	  set_byte (B01000000);
	  __delay_ms (delay_time);
	  set_byte (B10100000);
	  __delay_ms (delay_time);
	  set_byte (B00010001);
	  __delay_ms (delay_time);
	  set_byte (B00001010);
	  __delay_ms (delay_time);
	  set_byte (B00000100);
	  __delay_ms (delay_time);
	  set_byte (B00001010);
	  __delay_ms (delay_time);
	  set_byte (B00010001);
	  __delay_ms (delay_time);
	  set_byte (B10100000);
	  __delay_ms (delay_time);
	}
      break;
    case CCW:
      for (ctr = 0; ctr < times; ctr++)
	{
	  set_byte (B00000100);
	  __delay_ms (delay_time);
	  set_byte (B00001010);
	  __delay_ms (delay_time);
	  set_byte (B00010001);
	  __delay_ms (delay_time);
	  set_byte (B10100000);
	  __delay_ms (delay_time);
	  set_byte (B01000000);
	  __delay_ms (delay_time);
	  set_byte (B10100000);
	  __delay_ms (delay_time);
	  set_byte (B00010001);
	  __delay_ms (delay_time);
	  set_byte (B00001010);
	  __delay_ms (delay_time);
	}
      break;
    default:
      break;
    }
  color_off (led_color);
}
