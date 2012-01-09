/*
 * 2012 - robert:aT:spitzenpfeil_d*t:org - RGB_LED_Ring Demo
 */

#define V20alpha

#ifdef V20alpha
#define DOTCORR
#endif

#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include "V2_demo.h"		// needed to make the 'enum' work with Arduino IDE (and other things)

uint8_t brightness_red[8];	/* memory for RED LEDs */
uint8_t brightness_green[8];	/* memory for GREEN LEDs */
uint8_t brightness_blue[8];	/* memory for BLUE LEDs */

#define __color_bit_depth 6
#define __max_brightness 63	// ( (2^__color_bit_depth) - 1 )

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
#ifdef V20alpha
	DDRD |= _BV(RED_GATE) | _BV(GREEN_GATE) | _BV(BLUE_GATE);	// P-MOSFET gates as outputs
        DDRB |= _BV(PB2) | _BV(PB3) | _BV(PB5) | _BV(PB6); // set LATCH, MOSI, SCK, OE as outputs
#endif
	randomSeed(555);
        setup_hardware_spi();
	setup_timer1_ctc();	/* set timer1 to normal mode (16bit counter) and prescaler. enable/disable via extra functions! */
	set_all_rgb(0,0,0);	/* set the display to BLACK. Only affects PWM mode */
}

void loop(void)
{
  	uint16_t ctr;

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

	set_led_rgb(0, 63, 0, 0);
	delay(1000);
	set_led_rgb(1, 63, 63, 0);
	delay(1000);
	set_led_rgb(2, 0, 63, 0);
	delay(1000);
	set_led_rgb(3, 0, 63, 63);
	delay(1000);
	set_led_rgb(4, 0, 0, 63);
	delay(1000);
	set_led_rgb(5, 63, 0, 63);
	delay(1000);
	set_led_rgb(6, 63, 63, 63);
	delay(1000);
	set_led_rgb(7, 63, 63, 63);
	delay(5000);

	for (ctr = 0; ctr < 20; ctr++) {
		set_all_rgb(63, 63, 63);
		delay(20);
		set_all_rgb(0, 0, 0);
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

	wobble3(wobble_pattern_1, 8, 63, 0, 0, 0, 63, 0, 10, 50);
	wobble3(wobble_pattern_1, 4, 63, 0, 0, 63, 0, 63, 10, 10);
	wobble3(wobble_pattern_1, 8, 63, 63, 0, 0, 0, 63, 10, 10);
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
                                set_byte_rgb(_BV(ctr1) | _BV(ctr1 + 4),red,green,blue);
				delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = (8 - 1) - 4 + 1; ctr1 >= 1; ctr1--) {
                                set_byte_rgb( ( _BV(ctr1) | _BV((ctr1 + 4)%8)) ,red,green,blue);				
				delay(delay_time);
			}
		}
		break;
	default:
		break;
	}
        set_all_rgb(0,0,0);
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
				set_byte_rgb(_BV(ctr1),red,green,blue);
				delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr2 = 0; ctr2 < times; ctr2++) {
			for (ctr1 = (8 - 1) + 1; ctr1 >= 1; ctr1--) {
				set_byte_rgb(_BV(ctr1%8),red,green,blue);
				delay(delay_time);
			}
		}
		break;
	default:
		break;
	}
        set_all_rgb(0,0,0);
}

void blink_all(uint8_t red, uint8_t green, uint8_t blue, uint8_t times,
	       uint16_t delay_time)
{
	uint8_t ctr;
	for (ctr = 0; ctr < times; ctr++) {
		set_all_rgb(red,green,blue);
		delay(delay_time);
                set_all_rgb(0,0,0);
		delay(delay_time);
	}
}

void set_byte_rgb(uint8_t data_byte, uint8_t red, uint8_t green, uint8_t blue)
{
	uint8_t ctr;
	for (ctr = 0; ctr <= 7; ctr++) {
		if (data_byte & _BV(ctr)) {
			set_led_rgb(ctr,red,green,blue);
		} else {
			set_led_rgb(ctr,0,0,0);
		}
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
				set_byte_rgb(wobble_pattern_ptr[ctr2],red,green,blue);
				delay(delay_time);
			}
		}
		break;
	case CCW:
		for (ctr1 = 0; ctr1 < times; ctr1++) {
			for (ctr2 = 0; ctr2 < pattern_length; ctr2++) {
				set_byte_rgb(rotate_byte
					 (wobble_pattern_ptr[ctr2], 4, CW),red,green,blue);
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
				set_byte_rgb(wobble_pattern_ptr[ctr2],red1,green1,blue1);
				delay(1);	// this should be dynamically adapted to 'delay_time'

				set_byte_rgb(rotate_byte(wobble_pattern_ptr[ctr2], 4, CW),red2,green2,blue2);
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

	for (ctr1 = 0; ctr1 <= __max_brightness; ctr1++) {
		for (led = 0; led <= (8 - 1); led++) {
			set_led_rgb(led, ctr1, ctr1, ctr1);
		}
		delay(__fade_delay);
	}

	for (ctr1 = __max_brightness; (ctr1 >= 0) & (ctr1 != 255); ctr1--) {
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
	int8_t dotcorr = (int8_t)( (int16_t)(DOTCORR_RED) * red / __max_brightness );
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
	int8_t dotcorr = (int8_t)( (int16_t)(DOTCORR_GREEN) * green / __max_brightness );
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
	int8_t dotcorr = (int8_t)( (int16_t)(DOTCORR_BLUE) * blue / __max_brightness );
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

	uint16_t scale_factor = mmd / __max_brightness;

	R = (uint8_t) (R / scale_factor);
	G = (uint8_t) (G / scale_factor);
	B = (uint8_t) (B / scale_factor);

	set_led_rgb(led, R, G, B);
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
	/* set prescaler to 64 */
	TCCR1B |= (_BV(CS11) | _BV(CS10));
	TCCR1B &= ~(_BV(CS12));
	/* set WGM mode 4: CTC using OCR1A */
	TCCR1A &= ~(_BV(WGM10) | _BV(WGM11));
	TCCR1B |= _BV(WGM12);
	TCCR1B &= ~_BV(WGM13);
	/* normal operation - disconnect PWM pins */
	TCCR1A &= ~(_BV(COM1A1) | _BV(COM1A0) | _BV(COM1B1) | _BV(COM1B0));
	/* set top value for TCNT1 */
	OCR1A = 10;
	/* start interrupt */
	TIMSK1 |= _BV(OCIE1A);
	/* restore SREG with global interrupt flag */
	SREG = _sreg;
}

ISR(TIMER1_COMPA_vect)
{
	DRIVER_OFF;
#ifdef V20alpha

	uint8_t led = 0;
	uint8_t bcm_data = 0;
	uint8_t OCR1A_next;

	static uint8_t color = 0;
	static uint16_t bitmask = 0x0001;

	switch (color) {
	case 0:
		PORTD |= _BV(BLUE_GATE);
		PORTD |= _BV(GREEN_GATE);
		PORTD &= ~_BV(RED_GATE);	// gate low --> on
		for (led = 0; led <= 7; led++) {
			if (brightness_red[led] & bitmask) {
				bcm_data |= _BV(led);	// bit high --> on
			}
		}
		break;
	case 1:
		PORTD |= _BV(BLUE_GATE);
		PORTD |= _BV(RED_GATE);
		PORTD &= ~_BV(GREEN_GATE);	// gate low --> on
		for (led = 0; led <= 7; led++) {
			if (brightness_green[led] & bitmask) {
				bcm_data |= _BV(led);	// bit high --> on
			}
		}
		break;
	case 2:
		PORTD |= _BV(RED_GATE);
		PORTD |= _BV(GREEN_GATE);
		PORTD &= ~_BV(BLUE_GATE);	// gate low --> on
		for (led = 0; led <= 7; led++) {
			if (brightness_blue[led] & bitmask) {
				bcm_data |= _BV(led);	// bit high --> on
			}
		}
		break;
	default:
		PORTD &= ~_BV(RED_GATE);
		PORTD &= ~_BV(GREEN_GATE);
		PORTD &= ~_BV(BLUE_GATE);
		break;
	}

	LATCH_LOW;
	spi_transfer(bcm_data);
	LATCH_HIGH;

	OCR1A_next = bitmask;
	bitmask = bitmask << 1;

	if (bitmask == _BV(__color_bit_depth + 1)) {
		color++;
		bitmask = 0x0001;
		OCR1A_next = 1;
	}

	if (color == 3) {
		color = 0;
	}

	OCR1A = OCR1A_next;	// when to run next time
	TCNT1 = 0;		// clear timer to compensate for code runtime above
	TIFR1 = _BV(OCF1A);	// clear interrupt flag to kill any erroneously pending interrupt in the queue

#endif
        DRIVER_ON;
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

uint8_t spi_transfer(uint8_t data)
{
	SPDR = data;		// Start the transmission
	while (!(SPSR & _BV(SPIF)))	// Wait the end of the transmission
	{
	};
	return SPDR;		// return the received byte. (we don't need that here)
}

/*
 * PWM_BLOCK_END: all functions in this block are related to PWM mode !
 */
