//#define V2_1
#define V2_0_d
//#define V2_0_beta

#include <stdint.h>
#include <SPI.h>
#include "boblight_lamp_1_light.h"

#define NUM_OF_CHANNELS 3

//Data pin is MOSI (atmega168/328: pin 11. Mega: 51) 
//Clock pin is SCK (atmega168/328: pin 13. Mega: 52)
const int ShiftPWM_latchPin = 10;
const bool ShiftPWM_invertOutputs = 0;	// if invertOutputs is 1, outputs will be active low. Usefull for common anode RGB led's.

unsigned char maxBrightness = 255;
unsigned char pwmFrequency = 75;
int numRegisters = 3;

#include <ShiftPWM.h>		// modified version! - include ShiftPWM.h after setting the pins!

uint8_t values[NUM_OF_CHANNELS];	// boblight input buffer

void setup(void)
{
#ifdef V2_1
	DDRB |= _BV(PB2) | _BV(PB3) | _BV(PB5);	// set LATCH, MOSI, SCK as outputs
	analogWrite(6, 255);	// small LEDs off
	analogWrite(3, 0);	// LED driver chips on
	TCCR2B &= ~_BV(CS22);	// change TIMER2 prescaler to DIV1 for higher PWM frequency (16kHz instead of 250Hz --> less beating)
	TCCR2B |= _BV(CS20);
#endif

#ifdef V2_0_d
	DDRB |= _BV(PB2) | _BV(PB3) | _BV(PB5) | _BV(PB6);	// set LATCH, MOSI, SCK, OE as outputs
	analogWrite(6, 255);	// small LEDs off off
	DRIVER_ON;		// LED driver chips on
#endif

#ifdef V2_0_beta
	DDRB |= _BV(PB2) | _BV(PB3) | _BV(PB5) | _BV(PB6);	// set LATCH, MOSI, SCK, OE as outputs
	DRIVER_ON;		// LED driver chips on
#endif

	Serial.begin(19200);

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

	uint8_t tmp;
	for (tmp = 0; tmp <= 7; tmp++) {
		ShiftPWM.SetGroupOf3(tmp, 0, 0, 0);
	}
}

void loop(void)
{
	uint8_t counter;

	WaitForPrefix();

	for (counter = 0; counter < NUM_OF_CHANNELS; counter++) {
		while (!Serial.available()) ;
		values[counter] = Serial.read();
	}

	for (counter = 0; counter < 8; counter++) {
		ShiftPWM.SetGroupOf3(counter, values[0],
				     values[1],
				     values[2]);
	}

}

//boblightd needs to send 0x55 0xAA before sending the channel bytes
void WaitForPrefix(void)
{
	uint8_t first = 0, second = 0;
	while (second != 0x55 || first != 0xAA) {
		while (!Serial.available()) ;
		second = first;
		first = Serial.read();
	}
}
