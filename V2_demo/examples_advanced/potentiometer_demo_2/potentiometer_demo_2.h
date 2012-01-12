/*
 * Fix for Arduino IDE
 * Normally this could just be in the main source code file
 */

#ifdef V20alpha
#define RED_GATE   PD3
#define GREEN_GATE PD2
#define BLUE_GATE  PD4
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
