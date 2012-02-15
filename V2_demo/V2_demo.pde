/*
 * 2012 - robert:aT:spitzenpfeil_d*t:org - RGB_LED_Ring Demo
 */

#define V20final
//#define V20beta
//#define V20alpha

#ifdef V20alpha
#define DOTCORR
#endif

#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include "V2_demo.h"		// needed to make the 'enum' work with Arduino IDE (and other things)

#define COLOR_BIT_DEPTH 6
#define MAX_BRIGHTNESS 63	// ( (2^COLOR_BIT_DEPTH) - 1 )

// if COLOR_BIT_DEPTH and MAX_BRIGHTENSS (both at the same time!) are changed, this array must be adapted as well
// it goes from 1 ... ( 2^ (COLOR_BIT_DEPTH-1) ) ... and symetrical back to 1
uint8_t bit_weight[] = { 1, 2, 4, 8, 16, 32, 32, 16, 8, 4, 2, 1 };

uint8_t brightness_red[8];	/* memory for RED LEDs */
uint8_t brightness_green[8];	/* memory for GREEN LEDs */
uint8_t brightness_blue[8];	/* memory for BLUE LEDs */

uint8_t sbcm_red_a[(2 * COLOR_BIT_DEPTH)] = { };
uint8_t sbcm_green_a[(2 * COLOR_BIT_DEPTH)] = { };
uint8_t sbcm_blue_a[(2 * COLOR_BIT_DEPTH)] = { };

uint8_t sbcm_red_b[(2 * COLOR_BIT_DEPTH)] = { };
uint8_t sbcm_green_b[(2 * COLOR_BIT_DEPTH)] = { };
uint8_t sbcm_blue_b[(2 * COLOR_BIT_DEPTH)] = { };

uint8_t which_buffer = 0;	// 0 for sbcm_a, 1 for sbcm_b

uint8_t *sbcm_red_live = sbcm_red_a;
uint8_t *sbcm_green_live = sbcm_green_a;
uint8_t *sbcm_blue_live = sbcm_blue_a;

volatile uint8_t want_buffer_flip;

#ifdef DOTCORR
#define DOTCORR_RED 0
#define DOTCORR_GREEN -32
#define DOTCORR_BLUE -32

#define __fade_delay 2
#else
#define __fade_delay 5
#endif

void setup(void)
{

#ifdef V20final
	DDRB |= _BV(PB2) | _BV(PB3) | _BV(PB5) | _BV(PB6);	// set LATCH, MOSI, SCK, OE as outputs
	DDRD |= _BV(PD6);	// same as pinMode(6,OUTPUT);
	analogWrite(6, 255);	// off
#endif

#ifdef V20beta
	DDRB |= _BV(PB2) | _BV(PB3) | _BV(PB5) | _BV(PB6);	// set LATCH, MOSI, SCK, OE as outputs
#endif

#ifdef V20alpha
	DDRD |= _BV(RED_GATE) | _BV(GREEN_GATE) | _BV(BLUE_GATE);	// P-MOSFET gates as outputs
	DDRB |= _BV(PB2) | _BV(PB3) | _BV(PB5) | _BV(PB6);	// set LATCH, MOSI, SCK, OE as outputs
#endif

	randomSeed(555);
	setup_hardware_spi();
	setup_timer1_ctc();	/* set timer1 to normal mode (16bit counter) and prescaler. enable/disable via extra functions! */
	set_all_rgb(0, 0, 0, 1);	/* set the display to BLACK. Only affects PWM mode */
}

void loop(void)
{
	uint16_t ctr = 0;

#ifdef V20final
	set_all_rgb(63, 0, 0, 1);

	uint8_t ctr2;
	for (ctr2 = 0; ctr2 <= 25; ctr2++) {

		for (ctr = 255; ctr > 0; ctr--) {
			analogWrite(6, ctr);
			delay(5);
		}
		for (ctr = 0; ctr <= 255; ctr++) {
			analogWrite(6, ctr);
			delay(5);
		}
	}
#endif

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
		set_all_rgb(255, 255, 255, 1);
		delay(20);
		set_all_rgb(0, 0, 0, 1);
		delay(20);
	}

	set_led_rgb(0, 63, 0, 0, 1);
	delay(1000);
	set_led_rgb(1, 63, 63, 0, 1);
	delay(1000);
	set_led_rgb(2, 0, 63, 0, 1);
	delay(1000);
	set_led_rgb(3, 0, 63, 63, 1);
	delay(1000);
	set_led_rgb(4, 0, 0, 63, 1);
	delay(1000);
	set_led_rgb(5, 63, 0, 63, 1);
	delay(1000);
	set_led_rgb(6, 63, 63, 63, 1);
	delay(1000);
	set_led_rgb(7, 63, 63, 63, 1);
	delay(5000);

	for (ctr = 0; ctr < 20; ctr++) {
		set_all_rgb(63, 63, 63, 1);
		delay(20);
		set_all_rgb(0, 0, 0, 1);
		delay(20);
	}

	blink_all(63, 0, 0, 10, 20);
	blink_all(0, 63, 0, 10, 20);
	blink_all(0, 0, 63, 10, 20);
	blink_all(63, 63, 63, 10, 20);

	wobble2(wobble_pattern_1, 8, 63, 0, 0, CW, 10, 80);
	wobble2(wobble_pattern_3, 8, 63, 63, 0, CW, 10, 80);

	rotating_dot(63, 63, 63, CW, 10, 20);
	rotating_dot(63, 63, 63, CCW, 10, 20);

	rotating_bar(0, 0, 63, CCW, 15, 75);
	rotating_bar(0, 63, 0, CW, 15, 75);
	rotating_bar(63, 0, 0, CCW, 15, 75);
	rotating_bar(63, 63, 0, CW, 15, 75);
	rotating_bar(0, 63, 63, CCW, 15, 75);
	rotating_bar(63, 0, 63, CW, 15, 75);
	rotating_bar(63, 63, 63, CCW, 15, 75);

	wobble3(wobble_pattern_1, 8, 63, 0, 0, 0, 63, 0, 10, 0);
	wobble3(wobble_pattern_1, 8, 63, 0, 0, 63, 0, 63, 10, 0);
	wobble3(wobble_pattern_1, 8, 63, 63, 0, 0, 0, 63, 10, 0);

	set_all_rgb(0, 0, 0, 1);
}

void
rotating_bar(uint8_t red, uint8_t green, uint8_t blue,
	     enum DIRECTION_t direction, uint8_t times, uint16_t delay_time)
{
	uint8_t ctr1;
	uint8_t ctr2;
	switch (direction) {
	case CW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = 0; ctr1 <= (8 - 1) - 4; ctr1++) {
				set_byte_rgb(_BV(ctr1) | _BV(ctr1 + 4), red,
					     green, blue, 1);
				delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = (8 - 1) - 4 + 1; ctr1 >= 1; ctr1--) {
				set_byte_rgb((_BV(ctr1) | _BV((ctr1 + 4) % 8)),
					     red, green, blue, 1);
				delay(delay_time);
			}
		}
		break;
	default:
		break;
	}
	set_all_rgb(0, 0, 0, 1);
}

void
rotating_dot(uint8_t red, uint8_t green, uint8_t blue,
	     enum DIRECTION_t direction, uint8_t times, uint16_t delay_time)
{
	uint8_t ctr1;
	uint8_t ctr2;
	switch (direction) {
	case CW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
				set_byte_rgb(_BV(ctr1), red, green, blue, 1);
				delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = (8 - 1) + 1; ctr1 >= 1; ctr1--) {
				set_byte_rgb(_BV(ctr1 % 8), red, green, blue,
					     1);
				delay(delay_time);
			}
		}
		break;
	default:
		break;
	}
	set_all_rgb(0, 0, 0, 1);
}

void blink_all(uint8_t red, uint8_t green, uint8_t blue, uint8_t times,
	       uint16_t delay_time)
{
	uint8_t ctr;
	for (ctr = 0; ctr < times; ctr++) {
		set_all_rgb(red, green, blue, 1);
		delay(delay_time);
		set_all_rgb(0, 0, 0, 1);
		delay(delay_time);
	}
}

void
wobble2(uint8_t * wobble_pattern_ptr, uint8_t pattern_length,
	uint8_t red, uint8_t green, uint8_t blue, enum DIRECTION_t direction,
	uint8_t times, uint16_t delay_time)
{
	uint8_t ctr1;
	uint8_t ctr2;

	switch (direction) {
	case CW:
		for (ctr1 = 0; ctr1 < times; ctr1++) {
			for (ctr2 = 0; ctr2 < pattern_length; ctr2++) {
				set_byte_rgb(wobble_pattern_ptr[ctr2], red,
					     green, blue, 1);
				delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr1 = 0; ctr1 < times; ctr1++) {
			for (ctr2 = 0; ctr2 < pattern_length; ctr2++) {
				set_byte_rgb(rotate_byte
					     (wobble_pattern_ptr[ctr2], 4, CW),
					     red, green, blue, 1);
				delay(delay_time);
			}
		}
		break;
	default:
		break;
	}

}

void
wobble3(uint8_t * wobble_pattern_ptr, uint8_t pattern_length,
	uint8_t red1, uint8_t green1, uint8_t blue1, uint8_t red2,
	uint8_t green2, uint8_t blue2, uint8_t times, uint16_t delay_time)
{
	uint8_t ctr1;
	uint8_t ctr2;
	uint8_t pov_ctr;

	for (ctr1 = 0; ctr1 < times; ctr1++) {
		for (ctr2 = 0; ctr2 < pattern_length; ctr2++) {
			for (pov_ctr = 0; pov_ctr < 25; pov_ctr++) {
				set_byte_rgb(wobble_pattern_ptr[ctr2], red1,
					     green1, blue1, 1);
				delay(1);	// this should be dynamically adapted to 'delay_time'

				set_byte_rgb(rotate_byte
					     (wobble_pattern_ptr[ctr2], 4, CW),
					     red2, green2, blue2, 1);
				delay(1);	// this should be dynamically adapted to 'delay_time'

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

void random_leds(void)
{
	set_led_hsv((uint8_t) (random(8)), (uint16_t) (random(360)), 255, 255,
		    1);
}

void fader(void)
{				/* fade the matrix form BLACK to WHITE and back */
	uint8_t ctr1;
	uint8_t led;

	for (ctr1 = 0; ctr1 <= MAX_BRIGHTNESS; ctr1++) {
		for (led = 0; led <= (8 - 1); led++) {
			set_led_rgb(led, ctr1, ctr1, ctr1, 0);	// don't flip buffers after each led change here
		}
		flip_buffers();
		delay(__fade_delay);
	}

	for (ctr1 = MAX_BRIGHTNESS; (ctr1 >= 0) & (ctr1 != 255); ctr1--) {
		for (led = 0; led <= (8 - 1); led++) {
			set_led_rgb(led, ctr1, ctr1, ctr1, 0);	// don't flip buffers after each led change here
		}
		flip_buffers();
		delay(__fade_delay);
	}
}

void fader_hue(void)
{				/* cycle the color of the whole matrix */
	uint16_t ctr1;
	for (ctr1 = 0; ctr1 < 360; ctr1 = ctr1 + 3) {
		set_all_hsv(ctr1, 255, 255, 1);
		delay(__fade_delay);
	}
}

void color_wave(uint8_t width)
{
	uint8_t led;
	static uint16_t shift = 0;
	for (led = 0; led <= (8 - 1); led++) {
		set_led_hsv(led, (uint16_t) (led) * (uint16_t) (width) + shift,
			    255, 255, 0);
	}
	flip_buffers();
	shift++;
}

/*
 *basic functions to set the LEDs
 */

void set_led_red(uint8_t led, uint8_t red, uint8_t buffer_flip)
{
#ifdef DOTCORR
	int8_t dotcorr =
	    (int8_t) ((int16_t) (DOTCORR_RED) * red / MAX_BRIGHTNESS);
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
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_led_green(uint8_t led, uint8_t green, uint8_t buffer_flip)
{
#ifdef DOTCORR
	int8_t dotcorr =
	    (int8_t) ((int16_t) (DOTCORR_GREEN) * green / MAX_BRIGHTNESS);
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
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_led_blue(uint8_t led, uint8_t blue, uint8_t buffer_flip)
{
#ifdef DOTCORR
	int8_t dotcorr =
	    (int8_t) ((int16_t) (DOTCORR_BLUE) * blue / MAX_BRIGHTNESS);
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
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_led_rgb(uint8_t led, uint8_t red, uint8_t green, uint8_t blue,
		 uint8_t buffer_flip)
{
	set_led_red(led, red, 0);	// don't flip buffers after each led change here
	set_led_green(led, green, 0);	// don't flip buffers after each led change here
	set_led_blue(led, blue, 0);	// don't flip buffers after each led change here
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_all_rgb(uint8_t red, uint8_t green, uint8_t blue, uint8_t buffer_flip)
{
	uint8_t ctr1;
	for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
		set_led_rgb(ctr1, red, green, blue, 0);	// don't flip buffers after each led change here
	}
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_all_hsv(uint16_t hue, uint8_t sat, uint8_t val, uint8_t buffer_flip)
{
	uint8_t ctr1;
	for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
		set_led_hsv(ctr1, hue, sat, val, 0);	// don't flip buffers after each led change here
	}
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_byte_hsv(uint8_t data_byte, uint16_t hue, uint8_t sat, uint8_t val,
		  uint8_t buffer_flip)
{
	uint8_t led;
	for (led = 0; led <= (8 - 1); led++) {
		if (data_byte & _BV(led)) {
			set_led_hsv(led, hue, sat, val, 0);	// don't flip buffers after each led change here
		} else {
			set_led_rgb(led, 0, 0, 0, 0);	// don't flip buffers after each led change here
		}
	}
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_byte_rgb(uint8_t data_byte, uint8_t red, uint8_t green, uint8_t blue,
		  uint8_t buffer_flip)
{
	uint8_t ctr;
	for (ctr = 0; ctr <= 7; ctr++) {
		if (data_byte & _BV(ctr)) {
			set_led_rgb(ctr, red, green, blue, 0);	// don't flip buffers after each led change here
		} else {
			set_led_rgb(ctr, 0, 0, 0, 0);	// don't flip buffers after each led change here
		}
	}
	if (buffer_flip == 1) {
		flip_buffers();
	}
}

void set_led_hsv(uint8_t led, uint16_t hue, uint8_t sat, uint8_t val,
		 uint8_t buffer_flip)
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
	uint16_t const mmd = 65025;	// 255 * 255 /* maximum modulation depth */
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

	uint16_t scale_factor = mmd / MAX_BRIGHTNESS;

	R = (uint8_t) (R / scale_factor);
	G = (uint8_t) (G / scale_factor);
	B = (uint8_t) (B / scale_factor);

	set_led_rgb(led, R, G, B, buffer_flip);
}

/*
 * Functions dealing with hardware specific jobs / settings
 */

void setup_timer1_ctc(void)
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

#ifdef V20final
	/* set prescaler to 64 */
	TCCR1B |= (_BV(CS11) | _BV(CS10));
	TCCR1B &= ~(_BV(CS12));
#endif

#ifdef V20beta
	/* set prescaler to 64 */
	TCCR1B |= (_BV(CS11) | _BV(CS10));
	TCCR1B &= ~(_BV(CS12));
#endif

#ifdef V20alpha
	/* set prescaler to 64 */
	TCCR1B |= (_BV(CS11) | _BV(CS10));
	TCCR1B &= ~(_BV(CS12));
#endif

	/* set WGM mode 4: CTC using OCR1A */
	TCCR1A &= ~(_BV(WGM10) | _BV(WGM11));
	TCCR1B |= _BV(WGM12);
	TCCR1B &= ~_BV(WGM13);
	/* normal operation - disconnect PWM pins */
	TCCR1A &= ~(_BV(COM1A1) | _BV(COM1A0) | _BV(COM1B1) | _BV(COM1B0));
	/* set some top value for TCNT1 */
	OCR1A = 10;
	/* start interrupt */
	TIMSK1 |= _BV(OCIE1A);
	/* restore SREG with global interrupt flag */
	SREG = _sreg;
}

ISR(TIMER1_COMPA_vect)
{
	DRIVER_OFF;

#ifdef V20final
	uint8_t OCR1A_next;
	uint8_t bcm_ctr_prev = 0;
	static uint8_t bcm_ctr = 0;

	bcm_ctr_prev = bcm_ctr;
	bcm_ctr++;

	if (bcm_ctr == (2 * COLOR_BIT_DEPTH + 1)) {
		bcm_ctr = 0;
		OCR1A_next = 1;
		goto LEAVE_B;	// any comments on this ;-)
	}

	OCR1A_next = bit_weight[bcm_ctr_prev];

	LATCH_LOW;
	//
	// if colors are swapped, permutate the 3 spi_transfer(...) lines to
	// correct for the kind of RGB LED you use.
	//
	spi_transfer(sbcm_blue_live[bcm_ctr_prev]);	//  pull pre-calculated data from RAM
	spi_transfer(sbcm_green_live[bcm_ctr_prev]);
	spi_transfer(sbcm_red_live[bcm_ctr_prev]);
	LATCH_HIGH;

 LEAVE_B:
	OCR1A = OCR1A_next;	// when to run next time
	TCNT1 = 0;		// clear timer to compensate for code runtime above
	TIFR1 = _BV(OCF1A);	// clear interrupt flag to kill any erroneously pending interrupt in the queue
#endif

#ifdef V20beta
	uint8_t OCR1A_next;
	uint8_t bcm_ctr_prev = 0;
	static uint8_t bcm_ctr = 0;

	bcm_ctr_prev = bcm_ctr;
	bcm_ctr++;

	if (bcm_ctr == (2 * COLOR_BIT_DEPTH + 1)) {
		bcm_ctr = 0;
		OCR1A_next = 1;
		goto LEAVE_B;	// any comments on this ;-)
	}

	OCR1A_next = bit_weight[bcm_ctr_prev];

	LATCH_LOW;
	//
	// if colors are swapped, permutate the 3 spi_transfer(...) lines to
	// correct for the kind of RGB LED you use.
	//
	spi_transfer(sbcm_blue_live[bcm_ctr_prev]);	//  pull pre-calculated data from RAM
	spi_transfer(sbcm_green_live[bcm_ctr_prev]);
	spi_transfer(sbcm_red_live[bcm_ctr_prev]);
	LATCH_HIGH;

 LEAVE_B:
	OCR1A = OCR1A_next;	// when to run next time
	TCNT1 = 0;		// clear timer to compensate for code runtime above
	TIFR1 = _BV(OCF1A);	// clear interrupt flag to kill any erroneously pending interrupt in the queue
#endif

#ifdef V20alpha
	static uint8_t bcm_ctr = 0;
	static uint8_t color = 0;
	uint8_t bcm_data = 0;
	uint8_t bcm_ctr_prev = 0;
	uint8_t OCR1A_next;

	bcm_ctr_prev = bcm_ctr;
	bcm_ctr++;

	if (bcm_ctr == (2 * COLOR_BIT_DEPTH + 1)) {
		color++;
		bcm_ctr = 0;
		OCR1A_next = 1;
		if (color == 3) {
			color = 0;
		}
		goto LEAVE_A;	// any comments on this ;-)
	}

	OCR1A_next = bit_weight[bcm_ctr_prev];

	switch (color) {
	case 0:
		PORTD |= _BV(BLUE_GATE);
		PORTD |= _BV(GREEN_GATE);
		PORTD &= ~_BV(RED_GATE);	// gate low --> on
		bcm_data = sbcm_red_live[bcm_ctr_prev];	// <-- had 'bcm_ctr' there and couldn't find it for hours...
		break;
	case 1:
		PORTD |= _BV(BLUE_GATE);
		PORTD |= _BV(RED_GATE);
		PORTD &= ~_BV(GREEN_GATE);	// gate low --> on
		bcm_data = sbcm_green_live[bcm_ctr_prev];	//  pull pre-calculated data from RAM
		break;
	case 2:
		PORTD |= _BV(RED_GATE);
		PORTD |= _BV(GREEN_GATE);
		PORTD &= ~_BV(BLUE_GATE);	// gate low --> on
		bcm_data = sbcm_blue_live[bcm_ctr_prev];	//  pull pre-calculated data from RAM
		break;
	default:
		PORTD |= _BV(RED_GATE);
		PORTD |= _BV(GREEN_GATE);
		PORTD |= _BV(BLUE_GATE);
		break;
	}

	LATCH_LOW;
	spi_transfer(bcm_data);
	LATCH_HIGH;

 LEAVE_A:
	OCR1A = OCR1A_next;	// when to run next time
	TCNT1 = 0;		// clear timer to compensate for code runtime above
	TIFR1 = _BV(OCF1A);	// clear interrupt flag to kill any erroneously pending interrupt in the queue
#endif

	want_buffer_flip = 0;	// signal that a new BCM cycle is about to start
	DRIVER_ON;
}

void flip_buffers(void)
{
	// this is an attempt to implement 'MIBAM'
	//
	// http://www.picbasic.co.uk/forum/showthread.php?t=7393
	// http://www.picbasic.co.uk/forum/showthread.php?t=10564
	//
	// it still seeems to flicker at certain level transitions
	// the moving average jumps... ;-(
	//
	// looks like some more analyzer time...
	//

	// first rebuild the bcm array

	uint8_t read_ctr;
	uint8_t write_ctr;
	uint8_t tmp_write;
	uint8_t tmp_read;

	uint8_t *sbcm_red_write_to;
	uint8_t *sbcm_green_write_to;
	uint8_t *sbcm_blue_write_to;

	switch (which_buffer) {	// write to the buffer that is currently _not_ live
	case 0:
		sbcm_red_write_to = sbcm_red_b;
		sbcm_green_write_to = sbcm_green_b;
		sbcm_blue_write_to = sbcm_blue_b;
		break;
	case 1:
		sbcm_red_write_to = sbcm_red_a;
		sbcm_green_write_to = sbcm_green_a;
		sbcm_blue_write_to = sbcm_blue_a;
		break;
	default:
		break;
	}

	// the following is essentially a 90° matrix rotation
	//
	// the columns red[0].bit0, red[1].bit0, red[2].bit0 red[3].bit0 ...
	// are written to
	// sbcm_red[0].bit0, sbcm_red[0].bit1, sbcm_red[0].bit2, sbmc_red[0].bit3 ...

	for (write_ctr = 0; write_ctr <= (COLOR_BIT_DEPTH - 1); write_ctr++) {

		tmp_write = _BV(write_ctr);

		sbcm_red_write_to[write_ctr] = 0;
		sbcm_green_write_to[write_ctr] = 0;
		sbcm_blue_write_to[write_ctr] = 0;

		for (read_ctr = 0; read_ctr <= 7; read_ctr++) {

			tmp_read = _BV(read_ctr);

			if (brightness_red[read_ctr] & tmp_write) {
				sbcm_red_write_to[write_ctr] |= tmp_read;
			}
			if (brightness_green[read_ctr] & tmp_write) {
				sbcm_green_write_to[write_ctr] |= tmp_read;
			}
			if (brightness_blue[read_ctr] & tmp_write) {
				sbcm_blue_write_to[write_ctr] |= tmp_read;
			}
		}
	}

	// now create the mirror signal in the 2nd half of the arrays

	for (write_ctr = 0; write_ctr <= (COLOR_BIT_DEPTH - 1); write_ctr++) {
		sbcm_red_write_to[2 * COLOR_BIT_DEPTH - 1 - write_ctr] =
		    sbcm_red_write_to[write_ctr];
		sbcm_green_write_to[2 * COLOR_BIT_DEPTH - 1 - write_ctr] =
		    sbcm_green_write_to[write_ctr];
		sbcm_blue_write_to[2 * COLOR_BIT_DEPTH - 1 - write_ctr] =
		    sbcm_blue_write_to[write_ctr];
	}

	// now signal that we want to change the live buffer

	want_buffer_flip = 1;	// set the flag to 1

	while (want_buffer_flip == 1) {
		// wait until the flag is set to 0 by the ISR
	}

	cli();

	switch (which_buffer) {
	case 0:
		sbcm_red_live = sbcm_red_b;
		sbcm_green_live = sbcm_green_b;
		sbcm_blue_live = sbcm_blue_b;
		which_buffer = 1;
		break;
	case 1:
		sbcm_red_live = sbcm_red_a;
		sbcm_green_live = sbcm_green_a;
		sbcm_blue_live = sbcm_blue_a;
		which_buffer = 0;
	default:
		break;
	}

	TCNT1 = 0;		// clear timer to compensate for code runtime above
	TIFR1 = _BV(OCF1A);	// clear interrupt flag to kill any erroneously pending interrupt in the queue

	sei();
}

void setup_hardware_spi(void)
{
	uint8_t clr;
	// spi prescaler:
	//
	// SPCR: SPR1 SPR0
	// SPSR: SPI2X
	//
	// SPI2X SPR1 SPR0
	//   0     0     0    fosc/4
	//   0     0     1    fosc/16
	//   0     1     0    fosc/64
	//   0     1     1    fosc/128
	//   1     0     0    fosc/2
	//   1     0     1    fosc/8
	//   1     1     0    fosc/32
	//   1     1     1    fosc/64

	/* enable SPI as master */
	SPCR |= (_BV(SPE) | _BV(MSTR));
	/* clear registers */
	clr = SPSR;
	clr = SPDR;
	/* set prescaler to fosc/2 */
	SPCR &= ~(_BV(SPR1) | _BV(SPR0));
	SPSR |= _BV(SPI2X);
}

inline uint8_t spi_transfer(uint8_t data)
{
	SPDR = data;		// Start the transmission
	while (!(SPSR & _BV(SPIF)))	// Wait the end of the transmission
	{
	};
	return SPDR;		// return the received byte. (we don't need that here)
}

void level_debug(void)
{
	uint8_t read = 0;
	uint8_t ctr = 0;

	Serial.begin(9600);

	while (1) {
		if (Serial.available()) {
			switch (read = Serial.read()) {
			case '+':
				if (ctr < 63) {
					ctr++;
				}
				break;
			case '-':
				if (ctr > 0) {
					ctr--;
				}
				break;
			default:
				break;
			}
			Serial.println(ctr, BIN);
		}
		set_all_rgb(ctr, ctr, ctr, 1);
	}
}
