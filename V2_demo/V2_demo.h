/*
 * Fix for Arduino IDE
 * Normally this could just be in the main source code file
 */

#ifdef V2_1
  #define LATCH_LOW  PORTB &= ~_BV(PB2)
  #define LATCH_HIGH PORTB |= _BV(PB2)
#endif

#ifdef V20final
  #define DRIVER_ON  PORTB &= ~_BV(PB6)
  #define DRIVER_OFF PORTB |= _BV(PB6)  
  #define LATCH_LOW  PORTB &= ~_BV(PB2)
  #define LATCH_HIGH PORTB |= _BV(PB2)
#endif

#ifdef V20beta
  #define DRIVER_ON  PORTB &= ~_BV(PB6)
  #define DRIVER_OFF PORTB |= _BV(PB6)  
  #define LATCH_LOW  PORTB &= ~_BV(PB2)
  #define LATCH_HIGH PORTB |= _BV(PB2)
#endif

#ifdef V20alpha
  #define RED_GATE   PD3
  #define GREEN_GATE PD2
  #define BLUE_GATE  PD4
  #define DRIVER_ON  PORTB &= ~_BV(PB6)
  #define DRIVER_OFF PORTB |= _BV(PB6)
  #define LATCH_LOW  PORTB &= ~_BV(PB2)
  #define LATCH_HIGH PORTB |= _BV(PB2)
#endif

enum DIRECTION_t {
	CW,
	CCW
};

/*
 * wobble patterns
 *
 * defined for CW mode.
 * CCW data is calculated automatically by rotating 4 steps to the right
 * the code expects arrays of uint8_t
 * the number of lines is variable and must be specified in the function call
 */

uint8_t wobble_pattern_1[8] = {
	0b01000000,
	0b10100000,
	0b00010001,
	0b00001010,
	0b00000100,
	0b00001010,
	0b00010001,
	0b10100000
};

uint8_t wobble_pattern_2[8] = {
	0b01000100,
	0b10101010,
	0b00010001,
	0b10101010
};

uint8_t wobble_pattern_3[8] = {
	0b11000111,
	0b11000110,
	0b01000100,
	0b01101100,
	0b01111100,
	0b01101100,
	0b01000100,
	0b11000110
};
