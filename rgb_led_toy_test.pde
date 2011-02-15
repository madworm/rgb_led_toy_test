/*
 * 2010-08-19 (YYYY-MM-DD) - robert:aT:spitzenpfeil_d*t:org - RGB_LED_TOY_TEST
 */

 /*
  * change log:
  *
  * 2010-08-21 added true 7 simultaneous color mode. brighter than true RGB mode.
  *
  * 2010-08-19 added wobble3() for 2 color animations in 'high brightness' mode. kinda works.
  *
  * 2010-07-26 removed all the OSCCAL code, it just doesn't work good enough (drift).
  *            Next time I'll use a quartz crystal in SMD format...
  *            Now the syncing is done manually in functions after each "step" or "time slice",
  *            but NOT in PWM mode as it gets too slow.
  *
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
 * For boards that support auto-reset (version >= 1.21 or DTR printed on PCB): 
 *
 * ! DO NOT USE THE ARDUINO IDE FOR BURNING THE BOOTLOADER
 * ! IT WILL USE THE WRONG FUSE SETTINGS AND BRICK THE BOARD
 *
 * If you use an Arduino bootloader, I recommend the "ATmegaBOOT_168_pro_8MHz.hex".
 *
 * avrdude -c usbtiny -p atmega168 -P usb -b 115200 -e -u -U lock:w:0x3f:m -U efuse:w:0x00:m -U hfuse:w:0xDD:m -U lfuse:w:0xE2:m
 * avrdude -c usbtiny -p atmega168 -B 10 -P usb -b 115200 -U flash:w:ATmegaBOOT_168_pro_8MHz.hex -U lock:w:0x0f:m
 *
 *
 * For all other/beta/old boards:
 *
 * If you use an Arduino bootloader, I recommend the "LilyPadBOOT_168.hex".
 * Set the FUSE bytes to: LFUSE:0xE2 - HFUSE:0xDD - EFUSE:0x00 (avrdude convention)
 *
 */

/*
 * Select debugging mode
 */

//#define DEBUG_BLINK

/*
 * Select if the board is a MASTER (sends sync pulse), or a slave (waits for sync pulse)
 */

#define MASTER

#ifndef MASTER
#define SLAVE
#endif

/*
 * Select which board revision you have: OLD_PCB (10138), NEW_PCB_green (with DTR or V1.21), 
 * NEW_PCB_yellow (V1.21) and different RGB LEDs with the polarity mark facing towards the ATmega chip.
 * The silkscreen shows the little notches facing outward, which is now wrong for the new LEDs!
 */

//#define V122
#define NEW_PCB_yellow
//#define NEW_PCB_green
//#define OLD_PCB

#include <util/delay.h>
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include "rgb_led_toy_test.h"	// needed to make the 'enum' work with Arduino IDE (and other things)

uint8_t brightness_red[8];	/* memory for RED LEDs */
uint8_t brightness_green[8];	/* memory for GREEN LEDs */
uint8_t brightness_blue[8];	/* memory for BLUE LEDs */

/* all of the volatile variables will be set in setup_timer1_ctc() */
volatile uint8_t rgb_mode;	/* 0 for multiplexed TRUE-RGB (dim), 1 for multiplexed 7 color RGB (brighter and just 7 simultaneous colors including white) */
volatile uint8_t max_brightness;
#define __TRUE_RGB_OCR1A 0x040;	// using a prescaler of 1024
#define __7_COLOR_OCR1A 0x0035;	// using a prescaler of 256

//#define DOTCORR  /* enable/disable dot correction - only valid for true RGB PWM mode ! */

#ifdef DOTCORR
const int8_t PROGMEM dotcorr_red[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
const int8_t PROGMEM dotcorr_green[8] =
    { -24, -24, -24, -24, -15, -15, -15, -15 };
const int8_t PROGMEM dotcorr_blue[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };

#define __fade_delay 2
#else
#define __fade_delay 5
#endif

#ifdef V122
uint8_t fix_led_numbering[8] = { 0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef NEW_PCB_yellow
uint8_t fix_led_numbering[8] = { 0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef NEW_PCB_green
uint8_t fix_led_numbering[8] = { 0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef OLD_PCB
uint8_t fix_led_numbering[8] = { 3, 5, 4, 6, 7, 0, 1, 2 };	// this is necessary for older revisions (without DTR or >= 1.21 printed on the PCB)
#endif

void setup(void)
{
	DDRB |= 0xFF;		// set PORTB as output
	PORTB = 0xFF;		// all pins HIGH --> cathodes HIGH --> LEDs off

	DDRD |= (RED_Ax | GREEN_Ax | BLUE_Ax);	// set relevant pins as outputs
	PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);	// relevant pins LOW --> anodes LOW --> LEDs off

	DDRC &= ~(_BV(PC2) | _BV(PC3) | _BV(PC4) | _BV(PC5));	// PC2-5 is an input
	PORTC |= _BV(PC4);	// internal pull-up on

	randomSeed(555);
	setup_timer1_ctc(0);	/* set timer1 to normal mode (16bit counter) and prescaler. enable/disable via extra functions! */
	set_all_rgb(0, 0, 0);	/* set the display to BLACK. Only affects PWM mode */
}

void loop(void)
{

#ifdef DEBUG_BLINK
	color_on(WHITE);
	while (1) {
		uint8_t ctr;
		for (ctr = 0; ctr <= 7; ctr++) {
			PORTB = 0xFF;
			PORTB &= ~_BV(fix_led_numbering[ctr]);
			__delay_ms(1000);
		}
	}
#endif

#ifdef MASTER
	__delay_ms(1000);	//make sure all boards start at the same time after power on
	sync();
#endif

#ifdef SLAVE
	sync();
#endif

#ifdef V122
	more_light_hack_test();
#endif

	uint16_t ctr;

	setup_timer1_ctc(0);	// true RGB PWM mode
	enable_timer1_ctc();	// start PWM mode
	{
		for (ctr = 0; ctr < 3; ctr++) {
			fader();
		}
		for (ctr = 0; ctr < 4; ctr++) {
			fader_hue();
		}
		for (ctr = 0; ctr < 1000; ctr++) {
			color_wave(45);
		}
		for (ctr = 0; ctr < 20; ctr++) {
			set_all_rgb(255, 255, 255);
			delay(20);
			set_all_rgb(0, 0, 0);
			delay(20);
		}
	}
	disable_timer1_ctc();	// end PWM mode

	setup_timer1_ctc(1);	// 7 color mode
	enable_timer1_ctc();	// start PWM mode
	{
		set_led_rgb(0, 1, 0, 0);
		delay(1000);
		set_led_rgb(1, 1, 1, 0);
		delay(1000);
		set_led_rgb(2, 0, 1, 0);
		delay(1000);
		set_led_rgb(3, 0, 1, 1);
		delay(1000);
		set_led_rgb(4, 0, 0, 1);
		delay(1000);
		set_led_rgb(5, 1, 0, 1);
		delay(1000);
		set_led_rgb(6, 1, 1, 1);
		delay(1000);
		set_led_rgb(7, 1, 1, 1);
		delay(5000);

		for (ctr = 0; ctr < 20; ctr++) {
			set_all_rgb(255, 90, 45);
			delay(20);
			set_all_rgb(0, 0, 0);
			delay(20);
		}
	}
	disable_timer1_ctc();	// end PWM mode

#ifdef MASTER
	__delay_ms(2500);	// wait for the slave to finish after the _un-synced_ PWM demo
	sync();

	blink_all(RED, 10, 20);
	blink_all(GREEN, 10, 20);
	blink_all(BLUE, 10, 20);
	blink_all(WHITE, 10, 20);

	wobble2(wobble_pattern_1, 8, RED, CW, 10, 80);
	wobble2(wobble_pattern_3, 8, YELLOW, CW, 10, 80);

	rotating_dot(WHITE, CW, 10, 20);
	rotating_dot(WHITE, CCW, 10, 20);

	rotating_bar(BLUE, CCW, 15, 75);
	rotating_bar(GREEN, CW, 15, 75);
	rotating_bar(RED, CCW, 15, 75);
	rotating_bar(YELLOW, CW, 15, 75);
	rotating_bar(TURQUOISE, CCW, 15, 75);
	rotating_bar(PURPLE, CW, 15, 75);
	rotating_bar(WHITE, CCW, 15, 75);

	wobble3(wobble_pattern_1, 8, RED, GREEN, 10, 50);	// runs unsynced between MASTER and SLAVE !
	wobble3(wobble_pattern_1, 4, RED, PURPLE, 10, 10);
	wobble3(wobble_pattern_1, 8, YELLOW, BLUE, 10, 10);
#endif

#ifdef SLAVE
	sync();

	blink_all(RED, 10, 20);
	blink_all(GREEN, 10, 20);
	blink_all(BLUE, 10, 20);
	blink_all(WHITE, 10, 20);

	wobble2(wobble_pattern_1, 8, RED, CCW, 10, 80);
	wobble2(wobble_pattern_3, 8, YELLOW, CW, 10, 80);

	rotating_dot(WHITE, CCW, 10, 20);
	rotating_dot(WHITE, CW, 10, 20);

	rotating_bar(BLUE, CW, 15, 75);
	rotating_bar(GREEN, CCW, 15, 75);
	rotating_bar(RED, CW, 15, 75);
	rotating_bar(YELLOW, CCW, 15, 75);
	rotating_bar(TURQUOISE, CW, 15, 75);
	rotating_bar(PURPLE, CCW, 15, 75);
	rotating_bar(WHITE, CW, 15, 75);

	wobble3(wobble_pattern_1, 8, RED, GREEN, 10, 50);
	wobble3(wobble_pattern_1, 4, RED, PURPLE, 10, 10);
	wobble3(wobble_pattern_1, 8, YELLOW, BLUE, 10, 10);
#endif
}

void sync(void)
{
#ifdef MASTER
	DDRC |= _BV(PC4);	// PC4 is an output
	PORTC &= ~_BV(PC4);	// set PC4 low
	__delay_ms(2);
	PORTC |= _BV(PC4);	// set PC4 high
	DDRC &= ~_BV(PC4);	// PC4 is an input
	PORTC |= _BV(PC4);	// internal pull-up on
#endif

#ifdef SLAVE
	while (PINC & _BV(PC4)) {
	};			// wait for sync pulse (low) from master
#endif
}

#ifdef MASTER
inline void sync_and_delay(uint16_t delay_time)
{
	__delay_ms(delay_time);
	sync();
}
#else
inline void sync_and_delay(uint16_t delay_time)
{
	sync();
	__delay_ms(delay_time);
}
#endif

void more_light_hack_test(void)
{
	//
	// only works with V1.22 hack
	// no effect on un-hacked boards
	// If RED_A, RED_A2 ... are not switched at the same time
	// the one that should be off must be set to input + pullup off
	// If it is just set to LOW, it quasi shorts the other one to GND.
	// 
	PORTB = 0x00;		// LED cathodes low --> on
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= _BV(RED_A);
	PORTD |= _BV(RED_A);
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= RED_Ax;
	PORTD |= RED_Ax;
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= _BV(GREEN_A);
	PORTD |= _BV(GREEN_A);
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= GREEN_Ax;
	PORTD |= GREEN_Ax;
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= _BV(BLUE_A);
	PORTD |= _BV(BLUE_A);
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= BLUE_Ax;
	PORTD |= BLUE_Ax;
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= (_BV(RED_A) | _BV(GREEN_A) | _BV(BLUE_A));
	PORTD |= (_BV(RED_A) | _BV(GREEN_A) | _BV(BLUE_A));
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	DDRD |= (RED_Ax | GREEN_Ax | BLUE_Ax);
	PORTD |= (RED_Ax | GREEN_Ax | BLUE_Ax);
	delay(500);
	DDRD = 0x00;		// anodes high z --> off
	PORTD = 0x00;		// pull-ups off
	delay(500);
	setup();		// restore pin states...
}

void
rotating_bar(enum COLOR_t led_color, enum DIRECTION_t direction, uint8_t times,
	     uint16_t delay_time)
{
	uint8_t ctr1;
	uint8_t ctr2;
	color_on(led_color);
	switch (direction) {
	case CW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = 0; ctr1 <= (8 - 1) - 4; ctr1++) {
				PORTB = 0xFF;
				PORTB &=
				    ~(_BV(fix_led_numbering[ctr1]) |
				      _BV(fix_led_numbering[(ctr1 + 4)]));
				sync_and_delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = (8 - 1) - 4 + 1; ctr1 >= 1; ctr1--) {
				PORTB = 0xFF;
				PORTB &=
				    ~(_BV(fix_led_numbering[ctr1]) |
				      _BV(fix_led_numbering[(ctr1 + 4) % 8]));
				sync_and_delay(delay_time);
			}
		}
		break;
	default:
		break;
	}
	color_off(led_color);
}

void
rotating_dot(enum COLOR_t led_color, enum DIRECTION_t direction, uint8_t times,
	     uint16_t delay_time)
{
	uint8_t ctr1;
	uint8_t ctr2;
	color_on(led_color);
	switch (direction) {
	case CW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
				PORTB = 0xFF;
				PORTB &= ~_BV(fix_led_numbering[ctr1]);
				sync_and_delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = (8 - 1) + 1; ctr1 >= 1; ctr1--) {
				PORTB = 0xFF;
				PORTB &= ~_BV(fix_led_numbering[ctr1 % 8]);
				sync_and_delay(delay_time);
			}
		}
		break;
	default:
		break;
	}
	color_off(led_color);
}

void blink_all(COLOR_t color, uint8_t times, uint16_t delay_time)
{
	uint8_t ctr;
	color_on(color);
	for (ctr = 0; ctr < times; ctr++) {
		PORTB = 0x00;	// on
		sync_and_delay(delay_time);
		PORTB = 0xFF;	// off
		sync_and_delay(delay_time);
	}
	color_off(color);
}

void __delay_ms(uint16_t delay_time)
{
	/*
	 * this construct is needed to avoid a huge increase in codesize
	 * if _delay_ms() is called like: _delay_ms(var)
	 * instead of _delay_ms(const var)
	 */
	uint16_t counter;
	for (counter = 0; counter < delay_time; counter++) {
		_delay_ms(1);
	}
}

void set_byte(uint8_t data_byte)
{
	uint8_t ctr;
	for (ctr = 0; ctr <= 7; ctr++) {
		if (data_byte & _BV(ctr)) {
			PORTB &= ~_BV(fix_led_numbering[ctr]);	// cathode low, LED on
		} else {
			PORTB |= _BV(fix_led_numbering[ctr]);
		}
	}
}

void
wobble2(uint8_t * wobble_pattern_ptr, uint8_t pattern_length,
	enum COLOR_t led_color, enum DIRECTION_t direction, uint8_t times,
	uint16_t delay_time)
{
	uint8_t ctr1;
	uint8_t ctr2;
	color_on(led_color);
	switch (direction) {
	case CW:
		for (ctr1 = 0; ctr1 < times; ctr1++) {
			for (ctr2 = 0; ctr2 < pattern_length; ctr2++) {
				set_byte(wobble_pattern_ptr[ctr2]);
				sync_and_delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr1 = 0; ctr1 < times; ctr1++) {
			for (ctr2 = 0; ctr2 < pattern_length; ctr2++) {
				set_byte(rotate_byte
					 (wobble_pattern_ptr[ctr2], 4, CW));
				sync_and_delay(delay_time);
			}
		}
		break;
	default:
		break;
	}
	color_off(led_color);
}

void
wobble3(uint8_t * wobble_pattern_ptr, uint8_t pattern_length,
	enum COLOR_t led_color_1, enum COLOR_t led_color_2, uint8_t times,
	uint16_t delay_time)
{

	// still somewhat unpolished !
	// it doesn not run well - or at all - with MASTER/SLAVE syncing !

	uint8_t ctr1;
	uint8_t ctr2;
	uint8_t pov_ctr;

	for (ctr1 = 0; ctr1 < times; ctr1++) {
		for (ctr2 = 0; ctr2 < pattern_length; ctr2++) {
			for (pov_ctr = 0; pov_ctr < 25; pov_ctr++) {
				color_on(led_color_1);
				set_byte(wobble_pattern_ptr[ctr2]);
				__delay_ms(2);	// this should be dynamically adapted to 'delay_time'
				color_off(led_color_1);
				color_on(led_color_2);
				set_byte(rotate_byte
					 (wobble_pattern_ptr[ctr2], 4, CW));
				__delay_ms(2);	// this should be dynamically adapted to 'delay_time'
				color_off(led_color_2);
			}
		}
	}
}

uint8_t rotate_byte(uint8_t in_byte, uint8_t steps, enum DIRECTION_t direction)
{
	uint8_t result = in_byte;
	uint8_t ctr1;
	switch (direction) {
	case CW:
		for (ctr1 = 0; ctr1 < steps; ctr1++) {
			result = (result << 7) | (result >> 1);
		}
		break;
	case CCW:
		for (ctr1 = 0; ctr1 < steps; ctr1++) {
			result = (result >> 7) | (result << 1);
		}
		break;
	default:
		break;
	}
	return result;
}

void color_on(enum COLOR_t led_color)
{
	switch (led_color) {	// turn ON the necessary anodes
	case RED:
		PORTD |= RED_Ax;
		break;
	case GREEN:
		PORTD |= GREEN_Ax;
		break;
	case BLUE:
		PORTD |= BLUE_Ax;
		break;
	case YELLOW:
		PORTD |= (RED_Ax | GREEN_Ax);
		break;
	case TURQUOISE:
		PORTD |= (GREEN_Ax | BLUE_Ax);
		break;
	case PURPLE:
		PORTD |= (RED_Ax | BLUE_Ax);
		break;
	case WHITE:
		PORTD |= (RED_Ax | GREEN_Ax | BLUE_Ax);
		break;
	case BLACK:
		PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);
		break;
	default:
		break;
	}
}

void color_off(enum COLOR_t led_color)
{
	switch (led_color) {	// turn OFF the anodes again when we're done
	case RED:
		PORTD &= ~(RED_Ax);
		break;
	case GREEN:
		PORTD &= ~(GREEN_Ax);
		break;
	case BLUE:
		PORTD &= ~(BLUE_Ax);
		break;
	case YELLOW:
		PORTD &= ~(RED_Ax | GREEN_Ax);
		break;
	case TURQUOISE:
		PORTD &= ~(GREEN_Ax | BLUE_Ax);
		break;
	case PURPLE:
		PORTD &= ~(RED_Ax | BLUE_Ax);
		break;
	case WHITE:
		PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);
		break;
	case BLACK:
		PORTD |= (RED_Ax | GREEN_Ax | BLUE_Ax);
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

void random_leds(void)
{
	set_led_hsv((uint8_t) (random(8)), (uint16_t) (random(360)), 255, 255);
}

void fader(void)
{				/* fade the matrix form BLACK to WHITE and back */
	uint8_t ctr1;
	uint8_t led;

	for (ctr1 = 0; ctr1 <= max_brightness; ctr1++) {
		for (led = 0; led <= (8 - 1); led++) {
			set_led_rgb(led, ctr1, ctr1, ctr1);
		}
		delay(__fade_delay);
	}

	for (ctr1 = max_brightness; (ctr1 >= 0) & (ctr1 != 255); ctr1--) {
		for (led = 0; led <= (8 - 1); led++) {
			set_led_rgb(led, ctr1, ctr1, ctr1);
		}
		delay(__fade_delay);
	}
}

void fader_hue(void)
{				/* cycle the color of the whole matrix */
	uint16_t ctr1;
	for (ctr1 = 0; ctr1 < 360; ctr1 = ctr1 + 3) {
		set_all_hsv(ctr1, 255, 255);
		delay(__fade_delay);
	}
}

void color_wave(uint8_t width)
{
	uint8_t led;
	static uint16_t shift = 0;
	for (led = 0; led <= (8 - 1); led++) {
		set_led_hsv(led, (uint16_t) (led) * (uint16_t) (width) + shift,
			    255, 255);
	}
	shift++;
}

/*
 *basic functions to set the LEDs
 */

void set_led_red(uint8_t led, uint8_t red)
{
#ifdef DOTCORR
	int8_t dotcorr =
	    (int8_t) (pgm_read_byte(&dotcorr_red[led])) * red /
	    max_brightness;
	uint8_t value;
	if (red + dotcorr < 0) {
		value = 0;
	} else {
		value = red + dotcorr;
	}
	brightness_red[led] = value;
#else
	brightness_red[led] = red;
#endif
}

void set_led_green(uint8_t led, uint8_t green)
{
#ifdef DOTCORR
	int8_t dotcorr =
	    (int8_t) (pgm_read_byte(&dotcorr_green[led])) * green /
	    max_brightness;
	uint8_t value;
	if (green + dotcorr < 0) {
		value = 0;
	} else {
		value = green + dotcorr;
	}
	brightness_green[led] = value;
#else
	brightness_green[led] = green;
#endif
}

void set_led_blue(uint8_t led, uint8_t blue)
{
#ifdef DOTCORR
	int8_t dotcorr =
	    (int8_t) (pgm_read_byte(&dotcorr_blue[led])) * blue /
	    max_brightness;
	uint8_t value;
	if (blue + dotcorr < 0) {
		value = 0;
	} else {
		value = blue + dotcorr;
	}
	brightness_blue[led] = value;
#else
	brightness_blue[led] = blue;
#endif
}

void set_led_rgb(uint8_t led, uint8_t red, uint8_t green, uint8_t blue)
{
	set_led_red(led, red);
	set_led_green(led, green);
	set_led_blue(led, blue);
}

void set_all_rgb(uint8_t red, uint8_t green, uint8_t blue)
{
	uint8_t ctr1;
	for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
		set_led_rgb(ctr1, red, green, blue);
	}
}

void set_all_hsv(uint16_t hue, uint8_t sat, uint8_t val)
{
	uint8_t ctr1;
	for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
		set_led_hsv(ctr1, hue, sat, val);
	}
}

void set_all_byte_hsv(uint8_t data_byte, uint16_t hue, uint8_t sat, uint8_t val)
{
	uint8_t led;
	for (led = 0; led <= (8 - 1); led++) {
		if (data_byte & _BV(led)) {
			set_led_hsv(led, hue, sat, val);
		} else {
			set_led_rgb(led, 0, 0, 0);
		}
	}
}

void set_led_hsv(uint8_t led, uint16_t hue, uint8_t sat, uint8_t val)
{

	/* BETA */

	/* finally thrown out all of the float stuff and replaced with uint16_t
	 *
	 * hue: 0-->360 (hue, color)
	 * sat: 0-->255 (saturation)
	 * val: 0-->255 (value, brightness)
	 *
	 */

	hue = hue % 360;
	uint8_t sector = hue / 60;
	uint8_t rel_pos = hue - (sector * 60);
	uint16_t const mmd = 255 * 255;	/* maximum modulation depth */
	uint16_t top = val * 255;
	uint16_t bottom = val * (255 - sat);	/* (val*255) - (val*255)*(sat/255) */
	uint16_t slope = (uint16_t) (val) * (uint16_t) (sat) / 120;	/* dy/dx = (top-bottom)/(2*60) -- val*sat: modulation_depth dy */
	uint16_t a = bottom + slope * rel_pos;
	uint16_t b =
	    bottom + (uint16_t) (val) * (uint16_t) (sat) / 2 + slope * rel_pos;
	uint16_t c = top - slope * rel_pos;
	uint16_t d =
	    top - (uint16_t) (val) * (uint16_t) (sat) / 2 - slope * rel_pos;

	uint16_t R, G, B;

	if (sector == 0) {
		R = c;
		G = a;
		B = bottom;
	} else if (sector == 1) {
		R = d;
		G = b;
		B = bottom;
	} else if (sector == 2) {
		R = bottom;
		G = c;
		B = a;
	} else if (sector == 3) {
		R = bottom;
		G = d;
		B = b;
	} else if (sector == 4) {
		R = a;
		G = bottom;
		B = c;
	} else {
		R = b;
		G = bottom;
		B = d;
	}

	uint16_t scale_factor = mmd / max_brightness;

	R = (uint8_t) (R / scale_factor);
	G = (uint8_t) (G / scale_factor);
	B = (uint8_t) (B / scale_factor);

	set_led_rgb(led, R, G, B);
}

/*
 * Functions dealing with hardware specific jobs / settings
 */

void setup_timer1_ctc(uint8_t mode)
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
	uint8_t _sreg = SREG;	/* save SREG */
	cli();			/* disable all interrupts while messing with the register setup */
	switch (mode) {
	case 0:		/* multiplexed TRUE-RGB PWM mode (quite dim) */
		/* set prescaler to 1024 */
		TCCR1B |= (_BV(CS10) | _BV(CS12));
		TCCR1B &= ~_BV(CS11);
		/* set WGM mode 4: CTC using OCR1A */
		TCCR1A &= ~(_BV(WGM10) | _BV(WGM11));
		TCCR1B |= _BV(WGM12);
		TCCR1B &= ~_BV(WGM13);
		/* normal operation - disconnect PWM pins */
		TCCR1A &=
		    ~(_BV(COM1A1) | _BV(COM1A0) | _BV(COM1B1) | _BV(COM1B0));
		/* set top value for TCNT1 */
		OCR1A = __TRUE_RGB_OCR1A;
		/* rest */
		rgb_mode = mode;
		max_brightness = 64;	
		break;
	case 1:		/* multiplexed 7 color RGB mode (brighter) */
		/* set prescaler to 256 */
		TCCR1B &= ~(_BV(CS11) | _BV(CS10));
		TCCR1B |= _BV(CS12);
		/* set WGM mode 4: CTC using OCR1A */
		TCCR1A &= ~(_BV(WGM10) | _BV(WGM11));
		TCCR1B |= _BV(WGM12);
		TCCR1B &= ~_BV(WGM13);
		/* normal operation - disconnect PWM pins */
		TCCR1A &=
		    ~(_BV(COM1A1) | _BV(COM1A0) | _BV(COM1B1) | _BV(COM1B0));
		/* set top value for TCNT1 */
		OCR1A = __7_COLOR_OCR1A;
		/* rest */
		rgb_mode = mode;
		break;
	default:
		break;
	}
	/* restore SREG with global interrupt flag */
	SREG = _sreg;
}

void enable_timer1_ctc(void)
{
	uint8_t _sreg = SREG;
	cli();
	TIMSK1 |= _BV(OCIE1A);
	SREG = _sreg;
}

void disable_timer1_ctc(void)
{
	uint8_t _sreg = SREG;
	cli();
	TIMSK1 &= ~_BV(OCIE1A);
	SREG = _sreg;
}

ISR(TIMER1_COMPA_vect)
{				/* Framebuffer interrupt routine */
	uint8_t led;
	switch (rgb_mode) {
	case 0:
		uint8_t cycle;
		for (cycle = 0; cycle <= (max_brightness -1); cycle++) {
			uint8_t led;
			for (led = 0; led <= (8 - 1); led++) {

				PORTB = 0xFF;	// all cathodes HIGH --> OFF
				PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);	// all relevant anodes LOW --> OFF
				PORTB &= ~_BV(fix_led_numbering[led]);	// only turn on the LED that we deal with right now (current sink, on when zero)

				if (cycle < brightness_red[led]) {
					PORTD |= RED_Ax;
				}
				if (cycle < brightness_green[led]) {
					PORTD |= GREEN_Ax;
				}
				if (cycle < brightness_blue[led]) {
					PORTD |= BLUE_Ax;
				}
			}
		}

		break;
	case 1:
		for (led = 0; led <= (8 - 1); led++) {

			PORTB = 0xFF;	// all cathodes HIGH --> OFF
			PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);	// all relevant anodes LOW --> OFF
			PORTB &= ~_BV(fix_led_numbering[led]);	// only turn on the LED that we deal with right now (current sink, on when zero)

			if (brightness_red[led] > 0) {
				PORTD |= RED_Ax;
			}
			if (brightness_green[led] > 0) {
				PORTD |= GREEN_Ax;
			}
			if (brightness_blue[led] > 0) {
				PORTD |= BLUE_Ax;
			}
			_delay_us(200);	// pov delay
		}
		break;
	default:
		break;
	}
	PORTB = 0xFF;		// all cathodes HIGH --> OFF
}

/*
 * PWM_BLOCK_END: all functions in this block are related to PWM mode !
 */
