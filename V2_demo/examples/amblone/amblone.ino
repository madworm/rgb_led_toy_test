//================== which board is it? ==================

//#define V2_1
#define V2_0_d
//#define V2_0_beta

//====================== includes =========================

#include <stdint.h>
#include <SPI.h>
#include "amblone.h"

//=================== ShiftPWM stuff ======================

//Data pin is MOSI (atmega168/328: pin 11. Mega: 51) 
//Clock pin is SCK (atmega168/328: pin 13. Mega: 52)
const int ShiftPWM_latchPin = 10;
const bool ShiftPWM_invertOutputs = 0;	// if invertOutputs is 1, outputs will be active low. Usefull for common anode RGB led's.

unsigned char maxBrightness = 255;
unsigned char pwmFrequency = 75;
int numRegisters = 3;

#include <ShiftPWM.h>		// modified version! - include ShiftPWM.h after setting the pins!

//========================BLONE stuff =====================
//  partially based on code  availabe at:                // 
//  http://amblone.com/download                          //
//=========================================================

int pulse = 0;
int State = 0;
int Payload[32];
int ByteCount = 0;
int Recv;
int ChannelMode;

//=========================================================

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

	//================= ShiftPWM stuff ================
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
		ShiftPWM.SetGroupOf3(tmp, 8, 8, 8);
	}

	//================ AMBLONE stuff ==================
	//
	Serial.begin(256000);	// opens serial port, sets data rate to 256000 bps
	State = S_WAIT_FOR_SF;
}

void loop(void)
{
	if (Serial.available() > 0) {
		if (PacketReceived()) {
			SetPWMs();
		}
	}
}

boolean PacketReceived()
{
	Recv = Serial.read();

	switch (State) {
	case S_WAIT_FOR_SF:
		// =============================== Wait for start flag state
		switch (Recv) {
		case C_SF1:
			// Start flag for 1-channel mode
			ChannelMode = 1;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		case C_SF2:
			// Start flag for 2-channel mode
			ChannelMode = 2;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		case 243:	//C_SF3:
			// Start flag for 3-channel mode
			ChannelMode = 3;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		case C_SF4:
			// Start flag for 4-channel mode
			ChannelMode = 4;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		default:
			// No action for all other characters
			return false;
		}
		break;
	case S_RECV_RGB:
		// =============================== RGB Data reception state
		switch (Recv) {
		case C_SF1:
			// Start flag for 1-channel mode
			ChannelMode = 1;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		case C_SF2:
			// Start flag for 2-channel mode
			ChannelMode = 2;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		case C_SF3:
			// Start flag for 3-channel mode
			ChannelMode = 3;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		case C_SF4:
			// Start flag for 4-channel mode
			ChannelMode = 4;
			State = S_RECV_RGB;
			ByteCount = 0;
			return false;
		case C_END:
			// End Flag
			// For each channel, we should have received 3 values. If so, we have received a valid packet
			if (ByteCount == ChannelMode * 3) {
				State = S_WAIT_FOR_SF;
				ByteCount = 0;
				return true;	// <------------------------ TRUE IS RETURNED
			} else {
				// Something's gone wrong: restart
				State = S_WAIT_FOR_SF;
				ByteCount = 0;
				return false;
			}
		case C_ESC:
			// Escape character
			State = S_RECV_RGB_ESC;
			return false;
		default:
			// The character received wasn't a flag, so store it as an RGB value        
			Payload[ByteCount] = Recv;
			ByteCount++;
			return false;
		}
	case S_RECV_RGB_ESC:
		// =============================== RGB Escaped data reception state
		// Store the value in the payload, no matter what it is
		Payload[ByteCount] = Recv;
		ByteCount++;
		State = S_RECV_RGB;
		return false;
	}

	return false;
}

void SetPWMs()
{
	// Channel 1
	uint8_t leds;
	for (leds = 0; leds <= 7; leds++) {
		ShiftPWM.SetGroupOf3(leds, Payload[0], Payload[1], Payload[2]);
	}
}
