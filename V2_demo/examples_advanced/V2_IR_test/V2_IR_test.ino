#define V20final
//#define V20beta

#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <util/atomic.h>
#include "V2_demo.h"		// needed to make the 'enum' work with Arduino IDE (and other things)
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

uint32_t last_IR_activity = 0;

//Data pin is MOSI (atmega168/328: pin 11. Mega: 51) 
//Clock pin is SCK (atmega168/328: pin 13. Mega: 52)
const int ShiftPWM_latchPin=10;
const bool ShiftPWM_invertOutputs = 0; // if invertOutputs is 1, outputs will be active low. Usefull for common anode RGB led's.

unsigned char maxBrightness = 255;
unsigned char pwmFrequency = 75;
int numRegisters = 3;

#include <ShiftPWM.h>   // modified version! - include ShiftPWM.h after setting the pins!

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
        ShiftPWM.Start(pwmFrequency,maxBrightness);  
        
        set_all_hsv(0,255,16);
}

void loop(void)
{
                static uint8_t state = 0;
                static uint16_t hue = 0;
                static uint8_t val = 16;
		static uint16_t pulse_counter = 0;
		if (IR_available()) {
#ifdef DEBUG
			Serial.print(F("\r\n\npulse #: "));
#else
			Serial.print(F("pulse #: "));
#endif
			Serial.print(pulse_counter);
			Serial.print(F(" - "));
			switch (eval_IR_code(pulses_read_from)) {
			case VOL_DOWN:
                                hue = (hue - 1 + 360) % 360;
                                set_all_hsv(hue,255,val);
      				Serial.print(F("HUE - : "));
                                Serial.print(hue);
				break;
			case PLAY_PAUSE:
				Serial.print(F("ON/OFF"));
                                switch (state) {
                                  case 0:
                                    state = 1;
                                    set_all_hsv(hue,255,val);
                                    break;
                                  case 1:
                                    state = 0;
                                    set_all_hsv(hue,255,0);
                                  break;
                                  default:
                                  break;
                                }
				break;
			case VOL_UP:
                                hue = (hue + 1 + 360) % 360;
                                set_all_hsv(hue,255,val);
       				Serial.print(F("HUE + : "));
                                Serial.print(hue);       
				break;
                        case ARROW_UP:
                                set_all_hsv(hue,255,++val);
       				Serial.print(F("VAL + : "));
                                Serial.print(val);       
                                break;
                        case ARROW_DOWN:
                                set_all_hsv(hue,255,--val);
       				Serial.print(F("VAL - : "));
                                Serial.print(val);         
                                break;                              
			default:
				break;
			}
                        Serial.println("");
			pulse_counter++;
		}
}

void set_all_hsv(uint16_t hue, uint16_t sat, uint16_t val) {
  uint8_t red, green, blue;
  uint8_t led;
  hsv2rgb(hue, sat, val, &red, &green, &blue, maxBrightness);
  
  DRIVER_OFF;
  for (led = 0; led < 8; led++) {
    ShiftPWM.SetGroupOf3(led, red, green, blue);
  }
  DRIVER_ON;
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
