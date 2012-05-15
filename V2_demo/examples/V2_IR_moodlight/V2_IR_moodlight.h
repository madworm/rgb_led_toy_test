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
