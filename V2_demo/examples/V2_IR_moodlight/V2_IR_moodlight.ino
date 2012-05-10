/**
* This runs with a TSOP38238 IR receiver + an IR remote control sending commands.
*
* For your type of remote you will have to adjust the settings in 'my_ir_codes.h'
* The codes in there are for this IR remote: https://www.adafruit.com/products/389
*
* You can get code to read the RAW IR data here: https://github.com/madworm/IR_remote
*
*/

#define V20final
//#define V20beta

#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <util/atomic.h>
#include "V2_IR_moodlight.h"	// needed to make the 'enum' work with Arduino IDE (and other things)
#include "my_ir_codes.h"
#include <SPI.h>
#include "hsv2rgb.h"

//#define DEBUG
#define TRANSLATE_REPEAT_CODE	// instead of outputting 'repeat code' output the previously recognized IR code

// double buffering
volatile uint16_t pulses_a[NUMPULSES];
volatile uint16_t pulses_b[NUMPULSES];
volatile uint16_t *pulses_write_to = pulses_a;
volatile uint16_t *pulses_read_from = pulses_b;

volatile uint32_t last_IR_activity = 0;

//Data pin is MOSI (atmega168/328: pin 11. Mega: 51) 
//Clock pin is SCK (atmega168/328: pin 13. Mega: 52)
const int ShiftPWM_latchPin = 10;
const bool ShiftPWM_invertOutputs = 0;	// if invertOutputs is 1, outputs will be active low. Usefull for common anode RGB led's.

unsigned char maxBrightness = 255;
unsigned char pwmFrequency = 75;
int numRegisters = 3;

#define STARTUP_HUE 20U
#define HUE_STEP 1U
#define STARTUP_SAT 255U
#define SAT_STEP 1U
#define STARTUP_VAL 16U
#define VAL_STEP 1U
#define LOOP_DELAY 50U

#include <ShiftPWM.h>		// modified version! - include ShiftPWM.h after setting the pins!

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

	DRIVER_ON;		// enable the LED drivers

	//
	// IR stuff
	//
	Serial.begin(9600);
	Serial.println(F("Ready to decode IR!"));
	zero_pulses(pulses_read_from);
	zero_pulses(pulses_write_to);
	DDRC &= ~_BV(PC5);	// PC5 as input (arduino pin A5 / SCL)
	PORTC |= _BV(PC5);	// pull-up on

	PCICR |= _BV(PCIE1);	// enable pin-change interrupt for pin-group 1
	PCMSK1 |= _BV(PCINT13);	// enable pin-change interrupt por pin PC5 (PCINT13)  

	//
	// ShiftPWM stuff
	//
	pinMode(ShiftPWM_latchPin, OUTPUT);
	SPI.setBitOrder(LSBFIRST);
	// SPI_CLOCK_DIV2 is only a tiny bit faster in sending out the last byte. 
	// SPI transfer and calculations overlap for the other bytes.
	SPI.setClockDivider(SPI_CLOCK_DIV2);
	SPI.begin();

	ShiftPWM.SetAmountOfRegisters(numRegisters);
	ShiftPWM.SetAll(0);
	ShiftPWM.Start(pwmFrequency, maxBrightness);

	set_all_hsv(STARTUP_HUE, STARTUP_SAT, STARTUP_VAL);
}

void loop(void)
{
	static uint16_t hue = STARTUP_HUE;
	static uint8_t sat = STARTUP_SAT;
	static uint8_t val = STARTUP_VAL;
	static IR_code_t IR_code = MISMATCH;
	static uint8_t hue_plus_running = 0;
	static uint8_t hue_minus_running = 0;
	static uint8_t val_plus_running = 0;
	static uint8_t val_minus_running = 0;
	static uint8_t sat_plus_running = 0;
	static uint8_t sat_minus_running = 0;

	if (IR_available()) {
		IR_code = eval_IR_code(pulses_read_from);
	}

	if ((IR_code == VOL_UP) || (hue_plus_running == 1)) {
		if ((IR_code == VOL_UP) && (hue_plus_running == 1)) {
			hue_plus_running = 0;
		} else {
			hue_plus_running = 1;
			hue_minus_running = 0;
			hue = (hue + HUE_STEP + 360) % 360;
			set_all_hsv(hue, sat, val);
		}
	}

	if ((IR_code == VOL_DOWN) || (hue_minus_running == 1)) {
		if ((IR_code == VOL_DOWN) && (hue_minus_running == 1)) {
			hue_minus_running = 0;
		} else {
			hue_minus_running = 1;
			hue_plus_running = 0;
			hue = (hue - HUE_STEP + 360) % 360;
			set_all_hsv(hue, sat, val);
		}
	}

	if ((IR_code == ARROW_UP) || (val_plus_running == 1)) {
		if ((IR_code == ARROW_UP) && (val_plus_running == 1)) {
			val_plus_running = 0;
		} else {
			val_plus_running = 1;
			val_minus_running = 0;
			if (val + VAL_STEP < 255) {
				val = val + VAL_STEP;
			} else {
				val = 255;
			}
			set_all_hsv(hue, sat, val);
		}
	}

	if ((IR_code == ARROW_DOWN) || (val_minus_running == 1)) {
		if ((IR_code == ARROW_DOWN) && (val_minus_running == 1)) {
			val_minus_running = 0;
		} else {
			val_minus_running = 1;
			val_plus_running = 0;

			if (val > VAL_STEP) {
				val = val - VAL_STEP;
			} else {
				val = 0;
			}
			set_all_hsv(hue, sat, val);
		}
	}

	if ((IR_code == ARROW_LEFT) || (sat_minus_running == 1)) {
		if ((IR_code == ARROW_LEFT) && (sat_minus_running == 1)) {
			sat_minus_running = 0;
		} else {
			sat_minus_running = 1;
			sat_plus_running = 0;
			if (sat > SAT_STEP) {
				sat = sat - SAT_STEP;
			} else {
				sat = 0;
			}
			set_all_hsv(hue, sat, val);
		}
	}

	if ((IR_code == ARROW_RIGHT) || (sat_plus_running == 1)) {
		if ((IR_code == ARROW_RIGHT) && (sat_plus_running == 1)) {
			sat_plus_running = 0;
		} else {
			sat_plus_running = 1;
			sat_minus_running = 0;
			if (sat + SAT_STEP < 255) {
				sat = sat + SAT_STEP;
			} else {
				sat = 255;
			}
			set_all_hsv(hue, sat, val);
		}
	}

	IR_code = MISMATCH;

	delay(LOOP_DELAY);

}

void set_all_hsv(uint16_t hue, uint16_t sat, uint16_t val)
{
	uint8_t red, green, blue;
	uint8_t led;
	hsv2rgb(hue, sat, val, &red, &green, &blue, maxBrightness);

	for (led = 0; led < 8; led++) {
		ShiftPWM.SetGroupOf3(led, red, green, blue);
	}
}

//
// IR stuff
//

ISR(PCINT1_vect)
{
	static uint8_t pulse_counter = 0;
	static uint32_t last_run = 0;
	uint32_t now = micros();
	uint32_t pulse_length = abs(now - last_run);
	if (pulse_length > MAXPULSE) {
		zero_pulses(pulses_write_to);	// clear the buffer after a timeout has occurred
		pulse_counter = 0;
	}
	if (pulse_length < MINPULSE) {
		return;		// got some bouncing ? ignore that.
	}
	if (pulse_counter > 0) {
		pulses_write_to[pulse_counter - 1] =
		    (uint16_t) (pulse_length / 10);
	} else {
		// exit asap
	}
	last_run = micros();
	pulse_counter++;
	if (pulse_counter > NUMPULSES) {
		pulse_counter = 0;
	}
	last_IR_activity = micros();
}

void zero_pulses(volatile uint16_t * array)
{
	uint8_t ctr;
	for (ctr = 0; ctr < NUMPULSES; ctr++) {
		array[ctr] = 0;
	}
}

void flip_IR_buffers(void)
{
	ATOMIC_BLOCK(ATOMIC_RESTORESTATE) {
		volatile uint16_t *tmp;
		tmp = pulses_read_from;
		pulses_read_from = pulses_write_to;
		pulses_write_to = tmp;
	}
}

uint8_t IR_available(void)
{
	ATOMIC_BLOCK(ATOMIC_RESTORESTATE) {
		if (last_IR_activity != 0
		    && ((micros() - last_IR_activity) > MAXPULSE)) {
			flip_IR_buffers();
			last_IR_activity = 0;
			return 1;
		}
	}
	return 0;
}

IR_code_t eval_IR_code(volatile uint16_t * pulses_measured)
{
	uint8_t ctr1;
	uint8_t ctr2;
#ifdef TRANSLATE_REPEAT_CODE
	static IR_code_t prev_IR_code = NOT_SURE_YET;
#endif
	IR_code_t IR_code;
	for (ctr2 = 0; ctr2 < NUMBER_OF_IR_CODES; ctr2++) {
#ifdef DEBUG
		Serial.print(F("\r\nChecking against array element #: "));
		Serial.println(ctr2);
#endif
		IR_code = NOT_SURE_YET;

		for (ctr1 = 0; ctr1 < NUMPULSES - 6; ctr1++) {
			int16_t measured = (int16_t) (pulses_measured[ctr1]);
			int16_t reference =
			    (int16_t) pgm_read_word(&IRsignals[ctr2][ctr1]);
			uint16_t delta = (uint16_t) abs(measured - reference);
			uint16_t delta_repeat =
			    (uint16_t) abs(measured - REPEAT_CODE_PAUSE);
#ifdef DEBUG
			Serial.print(F("measured: "));
			Serial.print(measured);
			Serial.print(F(" - reference: "));
			Serial.print(reference);
			Serial.print(F(" - delta: "));
			Serial.print(delta);
			Serial.print(F(" - delta_rpt_code: "));
			Serial.print(delta_repeat);
#endif
			if (delta > (reference * FUZZINESS / 100)) {
				if (delta_repeat <
				    REPEAT_CODE_PAUSE * FUZZINESS / 100) {
#ifdef DEBUG
					Serial.println(F
						       (" - repeat code (ok)"));
#endif
					zero_pulses(pulses_measured);
					IR_code = REPEAT_CODE;
					break;
				}
#ifdef DEBUG
				Serial.println(F(" - (x)"));
#endif
				IR_code = MISMATCH;
				break;
			} else {
#ifdef DEBUG
				Serial.println(F(" - (ok)"));
#endif
			}
		}
		if (IR_code == REPEAT_CODE) {
#ifdef TRANSLATE_REPEAT_CODE
			IR_code = prev_IR_code;
#endif
			break;
		}
		if (IR_code == NOT_SURE_YET) {
			IR_code = (IR_code_t) (ctr2);
			break;
		}
	}
#ifdef TRANSLATE_REPEAT_CODE
	prev_IR_code = IR_code;
#endif
	zero_pulses(pulses_measured);
	return IR_code;
}
