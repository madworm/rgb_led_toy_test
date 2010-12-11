/*
 * Select if the board is a MASTER (sends sync pulse), or a slave (waits for sync pulse)
 */

#define MASTER

#define __RANDOM_SEED 1		// must be different for each board

/*
 * Select which board revision you have: OLD_PCB (10138), NEW_PCB_green (with DTR or V1.21), 
 * NEW_PCB_yellow (V1.21) and different RGB LEDs with the polarity mark facing towards the ATmega chip.
 * The silkscreen shows the little notches facing outward, which is now wrong for the new LEDs!
 */

#define NEW_PCB_yellow
//#define NEW_PCB_green
//#define OLD_PCB

#include <util/delay.h>
#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <Wire.h>
#include "xmas_chain.h"		// needed to make the 'enum' work with Arduino IDE (and other things)

#ifndef MASTER
#define SLAVE
#endif

#define __TWI_MASTER_ADDRESS 1	// decimal values
#define __TWI_SLAVE_ADDRESS_MIN 2	// 20 slave boards in this case
#define __TWI_SLAVE_ADDRESS_MAX 21	// 2 - 21
#define __TWI_SLAVE_ADDRESS 2	// adapt this for each slave board
#define __TWI_RX_BUFFER_LENGTH 6	// 6 bytes for the time being, should be enough
volatile uint8_t twi_rx_buffer[__TWI_RX_BUFFER_LENGTH];
volatile uint8_t twi_rx_complete_flag = 0;

uint8_t brightness_red[8];	/* memory for RED LEDs */
uint8_t brightness_green[8];	/* memory for GREEN LEDs */
uint8_t brightness_blue[8];	/* memory for BLUE LEDs */

/* all of these volatile variables will be set in setup_timer1_ctc() */
volatile uint8_t rgb_mode;	/* 0 for multiplexed TRUE-RGB (dim), 1 for multiplexed 7 color RGB (brighter and just 7 simultaneous colors including white) */
volatile uint8_t brightness_levels;
volatile uint8_t max_brightness;
#define __TRUE_RGB_OCR1A 0x0045;	// using a prescaler of 1024
#define __7_COLOR_OCR1A 0x0035;	// using a prescaler of 256

uint8_t do_twi_stuff = 0;

//#define DOTCORR  /* enable/disable dot correction - only valid for true RGB PWM mode ! */

#ifdef DOTCORR
const int8_t PROGMEM dotcorr_red[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
const int8_t PROGMEM dotcorr_green[8] =
    { -15, -15, -15, -15, -15, -15, -15, -15 };
const int8_t PROGMEM dotcorr_blue[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };

#define __fade_delay 2
#else
#define __fade_delay 5
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
	PORTC |= (_BV(PC4));	// internal pull-up on

	randomSeed(__RANDOM_SEED);
}

void loop(void)
{
	do_twi_stuff = 1;
	twi_stuff();
	TWCR = 0;		// disable TWI hardware 
	setup();		// run setup again. just to be sure that pin setup is right after TWI stuff
	non_twi_stuff();
}

void twi_stuff(void)
{

#ifdef MASTER
	uint8_t counter;
	Wire.begin();
	while (do_twi_stuff == 1) {
		for (counter = 0; counter < 5; counter++) {
			twi_white_chaser();
			twi_white_random_flasher();
		}
		twi_off_all_boards();	// do_twi_stuff = 0; // locally and remote via I2C
	}
#endif

#ifdef SLAVE
	Wire.begin(__TWI_SLAVE_ADDRESS);	// This has to be adapted for boards 1 to 8, as they are the slaves. Board 0 is the master and times the animation.
	Wire.onReceive(twi_slave_handler);	// slave_handler() will be executed after in interrupt for incoming TWI transmission has been triggered.
	while (do_twi_stuff == 1) {
		if (twi_rx_complete_flag == 1) {
			twi_rx_complete_flag = 0;	// reset to 0
			switch (twi_rx_buffer[0]) {
			case 0:
				set_all_rgb(0, 0, 0);
				break;
			case 1:
				random_delay_blink_color((COLOR_t)
							 (twi_rx_buffer[1]));
				break;
			case 3:
				setup_timer1_ctc(1);	// 7 color mode
				enable_timer1_ctc();	// start PWM mode
				break;
			case 4:
				disable_timer1_ctc();	// start PWM mode
				break;
			case 5:
				set_led_rgb(twi_rx_buffer[1],
					    (twi_rx_buffer[2] & 0x04),
					    (twi_rx_buffer[2] & 0x02),
					    (twi_rx_buffer[2] & 0x01));
				break;
			case 6:
				set_all_rgb(1, 1, 1);	// 7 color mode WHITE
				break;
			case 255:
				do_twi_stuff = 0;
				break;
			default:
				break;
			}
		}
	}
#endif

}

#ifdef MASTER
void twi_white_random_flasher(void)
{
	uint8_t twi_slave_address;
	uint16_t counter = 0;

	twi_7_color_mode_on_all_boards();

	while (counter < 500) {
		twi_slave_address = (uint8_t) (random(1, 22));	// should return rnd between 1 and 21 (inclusive)
		if (twi_slave_address == __TWI_MASTER_ADDRESS) {
			set_all_rgb(0, 0, 0);	// go dark
			delay(10);
			set_all_rgb(1, 1, 1);	// go white
			delay(10);
			set_all_rgb(0, 0, 0);	// go dark again
		} else {
			Wire.beginTransmission(twi_slave_address);
			Wire.send(0);	// go dark
			Wire.endTransmission();
			delay(10);
			Wire.beginTransmission(twi_slave_address);
			Wire.send(6);	// go white
			Wire.endTransmission();
			delay(10);
			Wire.beginTransmission(twi_slave_address);
			Wire.send(0);	// go dark
			Wire.endTransmission();
		}
		counter++;
	}
	twi_7_color_mode_off_all_boards();
}

void twi_7_color_mode_on_all_boards(void)
{
	uint8_t twi_slave_address;
	for (twi_slave_address = 1;
	     twi_slave_address <= __TWI_SLAVE_ADDRESS_MAX;
	     twi_slave_address++) {
		if (twi_slave_address == __TWI_MASTER_ADDRESS) {
			setup_timer1_ctc(1);	// 7 color mode
			enable_timer1_ctc();	// start PWM mode
		} else {
			Wire.beginTransmission(twi_slave_address);
			Wire.send(3);	// start 7 color mode
			Wire.endTransmission();
		}
	}
}

void twi_7_color_mode_off_all_boards(void)
{
	uint8_t twi_slave_address;
	for (twi_slave_address = 1;
	     twi_slave_address <= __TWI_SLAVE_ADDRESS_MAX;
	     twi_slave_address++) {
		if (twi_slave_address == __TWI_MASTER_ADDRESS) {
			disable_timer1_ctc();	// stop PWM mode
		} else {
			Wire.beginTransmission(twi_slave_address);
			Wire.send(4);	// stop 7 color mode
			Wire.endTransmission();
		}
	}
}

void twi_white_chaser(void)
{
	uint8_t twi_slave_address;

	twi_7_color_mode_on_all_boards();

	for (twi_slave_address = 1;
	     twi_slave_address <= __TWI_SLAVE_ADDRESS_MAX;
	     twi_slave_address++) {
		if (twi_slave_address == __TWI_MASTER_ADDRESS) {
			set_all_rgb(1, 1, 1);
			delay(5);
			set_all_rgb(0, 0, 0);
			delay(5);
		} else {
			Wire.beginTransmission(twi_slave_address);
			Wire.send(6);	// set_all_rgb(1,1,1); // 7 color mode WHITE
			Wire.endTransmission();
			delay(5);
			Wire.beginTransmission(twi_slave_address);
			Wire.send(0);	// all off
			Wire.endTransmission();
			delay(5);
		}
	}
	for (twi_slave_address = __TWI_SLAVE_ADDRESS_MAX;
	     twi_slave_address >= 1; twi_slave_address--) {
		if (twi_slave_address == __TWI_MASTER_ADDRESS) {
			set_all_rgb(1, 1, 1);
			delay(5);
			set_all_rgb(0, 0, 0);
			delay(5);
		} else {
			Wire.beginTransmission(twi_slave_address);
			Wire.send(6);	// set_all_rgb(1,1,1); // 7 color mode WHITE
			Wire.endTransmission();
			delay(5);
			Wire.beginTransmission(twi_slave_address);
			Wire.send(0);	// all off
			Wire.endTransmission();
			delay(5);
		}
	}

	twi_7_color_mode_off_all_boards();

}

void twi_off_all_boards(void)
{
	uint8_t twi_slave_address;
	for (twi_slave_address = 1;
	     twi_slave_address <= __TWI_SLAVE_ADDRESS_MAX;
	     twi_slave_address++) {
		if (twi_slave_address == __TWI_MASTER_ADDRESS) {
			do_twi_stuff = 0;
		} else {
			Wire.beginTransmission(twi_slave_address);
			Wire.send(255);	// do_twi_stuff = 0;
			Wire.endTransmission();
		}
	}
}

#endif

void non_twi_stuff(void)
{

#ifdef MASTER
	__delay_ms(1000);	//make sure all boards start at the same time after power on
	sync();
#endif

#ifdef SLAVE
	sync();
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

	blink_all_red_times(10, 20);
	blink_all_green_times(10, 20);
	blink_all_blue_times(10, 20);
	blink_all_white_times(10, 20);

	wobble2(wobble_pattern_1, 8, RED, CW, 10, 80);
	wobble2(wobble_pattern_3, 8, YELLOW, CW, 10, 80);

	white_clockwise(10, 20);
	white_counterclockwise(10, 20);

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

	blink_all_red_times(10, 20);
	blink_all_green_times(10, 20);
	blink_all_blue_times(10, 20);
	blink_all_white_times(10, 20);

	wobble2(wobble_pattern_1, 8, RED, CCW, 10, 80);
	wobble2(wobble_pattern_3, 8, YELLOW, CW, 10, 80);

	white_counterclockwise(10, 20);
	white_clockwise(10, 20);

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

void test_0(void)
{
	setup_timer1_ctc(1);	// 7 color mode
	set_all_rgb(0, 0, 0);
	enable_timer1_ctc();	// start PWM mode
	set_led_rgb(0, 1, 0, 0);
	delay(100);
	set_led_rgb(1, 1, 1, 0);
	delay(100);
	set_led_rgb(2, 0, 1, 0);
	delay(100);
	set_led_rgb(3, 0, 1, 1);
	delay(100);
	set_led_rgb(4, 0, 0, 1);
	delay(100);
	set_led_rgb(5, 1, 0, 1);
	delay(100);
	set_led_rgb(6, 1, 1, 1);
	delay(100);
	set_led_rgb(7, 1, 1, 1);
	delay(2000);
	disable_timer1_ctc();	// end PWM mode
}

void test_1(void)
{
	setup_timer1_ctc(1);	// 7 color mode
	set_all_rgb(0, 0, 0);
	enable_timer1_ctc();	// start PWM mode
	set_led_rgb(0, 1, 0, 0);
	delay(100);
	set_led_rgb(1, 0, 1, 0);
	delay(100);
	set_led_rgb(2, 1, 0, 0);
	delay(100);
	set_led_rgb(3, 0, 1, 0);
	delay(100);
	set_led_rgb(4, 1, 0, 0);
	delay(100);
	set_led_rgb(5, 0, 1, 0);
	delay(100);
	set_led_rgb(6, 1, 0, 0);
	delay(100);
	set_led_rgb(7, 0, 1, 0);
	delay(2000);
	disable_timer1_ctc();	// end PWM mode
}

#ifdef SLAVE
void twi_slave_handler(int dummy_rcvd_bytes)
{
	uint8_t buff_pos = 0;
	while (Wire.available() > 0) {
		if (buff_pos > (__TWI_RX_BUFFER_LENGTH - 1)) {
			buff_pos = 0;	// just wrap around to 0 again if received too much data. don't care if things get interpreted wrong
		}
		twi_rx_buffer[buff_pos] = Wire.receive();
		buff_pos++;
	}
	twi_rx_complete_flag = 1;
}
#endif

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
	while ((PINC & _BV(PC4))) {
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

void random_delay_blink_color(enum COLOR_t led_color)
{
	color_on(led_color);
	PORTB = 0x00;
	__delay_ms(random(500));
	PORTB = 0xFF;
	color_off(led_color);
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

void white_clockwise(uint8_t times, uint16_t delay_time)
{
	color_on(WHITE);
	uint8_t ctr1;
	uint8_t ctr2;
	for (ctr2 = 0; ctr2 < times; ctr2++) {
		for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
			PORTB = 0xFF;
			PORTB &= ~_BV(fix_led_numbering[ctr1]);
			sync_and_delay(delay_time);
		}
	}
	color_off(WHITE);
}

void white_counterclockwise(uint8_t times, uint16_t delay_time)
{
	color_on(WHITE);
	uint8_t ctr1;
	uint8_t ctr2;
	for (ctr2 = 0; ctr2 < times; ctr2++) {
		for (ctr1 = (8 - 1) + 1; ctr1 >= 1; ctr1--) {
			PORTB = 0xFF;
			PORTB &= ~_BV(fix_led_numbering[ctr1 % 8]);
			sync_and_delay(delay_time);
		}
	}
	color_off(WHITE);
}

void blink_all_red_times(uint8_t times, uint16_t delay_time)
{
	uint8_t ctr;
	color_on(RED);
	for (ctr = 0; ctr < times; ctr++) {
		PORTB = 0x00;
		sync_and_delay(delay_time);
		PORTB = 0xFF;	// off
		sync_and_delay(delay_time);
	}
	color_off(RED);
}

void blink_all_green_times(uint8_t times, uint16_t delay_time)
{
	uint8_t ctr;
	color_on(GREEN);
	for (ctr = 0; ctr < times; ctr++) {
		PORTB = 0x00;
		sync_and_delay(delay_time);
		PORTB = 0xFF;	// off
		sync_and_delay(delay_time);
	}
	color_off(GREEN);
}

void blink_all_blue_times(uint8_t times, uint16_t delay_time)
{
	uint8_t ctr;
	color_on(BLUE);
	for (ctr = 0; ctr < times; ctr++) {
		PORTB = 0x00;
		sync_and_delay(delay_time);
		PORTB = 0xFF;	// off
		sync_and_delay(delay_time);
	}
	color_off(BLUE);
}

void blink_all_white_times(uint8_t times, uint16_t delay_time)
{
	uint8_t ctr;
	color_on(WHITE);
	for (ctr = 0; ctr < times; ctr++) {
		PORTB = 0x00;
		sync_and_delay(delay_time);
		PORTB = 0xFF;	// off
		sync_and_delay(delay_time);
	}
	color_off(WHITE);
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
	uint8_t what_bit;
	for (ctr = 0; ctr <= 7; ctr++) {
		what_bit = (1 << ctr);
		if (data_byte & what_bit) {
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
	    brightness_levels;
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
	    brightness_levels;
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
	    brightness_levels;
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
		if ((data_byte >> led) & (B00000001)) {
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
		brightness_levels = 64;
		max_brightness = 63;	// brightness_levels - 1
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
		brightness_levels = 2;
		max_brightness = 1;
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
		for (cycle = 0; cycle < max_brightness; cycle++) {
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
