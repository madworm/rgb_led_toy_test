/*
 * Fix for Arduino IDE
 * Normally this could just be in the main source code file
 */

#ifdef V2_1
#define LATCH_LOW  PORTB &= ~_BV(PB2)
#define LATCH_HIGH PORTB |= _BV(PB2)
#endif

#ifdef V2_0_d
#define DRIVER_ON  PORTB &= ~_BV(PB6)
#define DRIVER_OFF PORTB |= _BV(PB6)
#define LATCH_LOW  PORTB &= ~_BV(PB2)
#define LATCH_HIGH PORTB |= _BV(PB2)
#endif

#ifdef V2_0_beta
#define DRIVER_ON  PORTB &= ~_BV(PB6)
#define DRIVER_OFF PORTB |= _BV(PB6)
#define LATCH_LOW  PORTB &= ~_BV(PB2)
#define LATCH_HIGH PORTB |= _BV(PB2)
#endif

//---------------------------------------------------------------------------
//--------------------------- AMBLONE DEFINES -------------------------------
//---------------------------------------------------------------------------

// Flags for the USB communication protocol
#define C_SF1 0xF1		// Startflag for 1-channel mode (1 RGB channel)
#define C_SF2 0xF2		// Startflag for 2-channel mode (2 RGB channels)
#define C_SF3 0xF3		// Startflag for 3-channel mode (3 RGB channels)
#define C_SF4 0xF4		// Startflag for 4-channel mode (4 RGB channels)
#define C_END 0x33		// End flag
#define C_ESC 0x99		// Escape character

// States for receiving the information, see the flow chart for more info
#define S_WAIT_FOR_SF  0
#define S_RECV_RGB     1
#define S_RECV_RGB_ESC 2
