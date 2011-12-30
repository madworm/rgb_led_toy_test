// ! this example deliberately has reduced functionality !
// !  please use 'rgb_led_toy_test.pde' as a reference   !

#include <util/delay.h>
#include <avr/interrupt.h>
#include "seven_colors.h"

byte brightness_red[8];		/* memory for RED LEDs */
byte brightness_green[8];	/* memory for GREEN LEDs */
byte brightness_blue[8];	/* memory for BLUE LEDs */

void setup(void)
{
	DDRB |= 0xFF;		// set PORTB as output
	PORTB = 0xFF;		// all pins HIGH --> cathodes HIGH --> LEDs off

	DDRD |= (RED_Ax | GREEN_Ax | BLUE_Ax);	// set relevant pins as outputs
	PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);	// relevant pins LOW --> anodes LOW --> LEDs off

	setup_timer1_ctc();	// 7 color PWM mode
	set_all_rgb(0, 0, 0);
}

void loop(void)
{
	set_led_rgb(0, 255, 0, 0);
	delay(1000);
	set_led_rgb(1, 255, 255, 0);
	delay(1000);
	set_led_rgb(2, 0, 255, 0);
	delay(1000);
	set_led_rgb(3, 0, 255, 255);
	delay(1000);
	set_led_rgb(4, 0, 0, 255);
	delay(1000);
	set_led_rgb(5, 255, 0, 255);
	delay(1000);
	set_led_rgb(6, 255, 255, 255);
	delay(1000);
	set_led_rgb(7, 255, 255, 255);
	delay(5000);

	byte ctr;

	for (ctr = 0; ctr < 20; ctr++) {
		set_all_rgb(255, 255, 255);
		delay(20);
		set_all_rgb(0, 0, 0);
		delay(20);
	}
}

/*
 * PWM_BLOCK_START: all functions in this block are related to PWM mode !
 */

/*
 *basic functions to set the LEDs
 */

void set_led_red(byte led, byte red)
{
	brightness_red[led] = red;
}

void set_led_green(byte led, byte green)
{
	brightness_green[led] = green;
}

void set_led_blue(byte led, byte blue)
{
	brightness_blue[led] = blue;
}

void set_led_rgb(byte led, byte red, byte green, byte blue)
{
	set_led_red(led, red);
	set_led_green(led, green);
	set_led_blue(led, blue);
}

void set_all_rgb(byte red, byte green, byte blue)
{
	byte ctr1;
	for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
		set_led_rgb(ctr1, red, green, blue);
	}
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
	byte _sreg = SREG;	/* save SREG */
	cli();			/* disable all interrupts while messing with the register setup */
	/* set prescaler to 1024 */
	TCCR1B &= ~(_BV(CS12) | _BV(CS10));
	TCCR1B |= _BV(CS11);	
	/* set WGM mode 4: CTC using OCR1A */
	TCCR1A &= ~(_BV(WGM10) | _BV(WGM11));
	TCCR1B |= _BV(WGM12);
	TCCR1B &= ~_BV(WGM13);
	/* normal operation - disconnect PWM pins */
	TCCR1A &= ~(_BV(COM1A1) | _BV(COM1A0) | _BV(COM1B1) | _BV(COM1B0));
	/* set top value for TCNT1 */
	OCR1A = 0x0035;
	/* start the compare match interrupt */
	TIMSK1 |= _BV(OCIE1A);
	/* restore SREG with global interrupt flag */
	SREG = _sreg;
}

ISR(TIMER1_COMPA_vect)
{				/* Framebuffer interrupt routine */
	static uint8_t led = 0;

	PORTB = 0xFF;		// all cathodes HIGH --> OFF
	PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);	// all relevant anodes LOW --> OFF
	PORTB &= ~_BV(led);	// only turn on the LED that we deal with right now (current sink, on when zero)

	if (brightness_red[led] > 0) {
		PORTD |= RED_Ax;
	}
	if (brightness_green[led] > 0) {
		PORTD |= GREEN_Ax;
	}
	if (brightness_blue[led] > 0) {
		PORTD |= BLUE_Ax;
	}

	led++;
	if (led == 8) {
		led = 0;
	}
}
