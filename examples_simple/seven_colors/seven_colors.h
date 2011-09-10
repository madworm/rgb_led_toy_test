/*
 * Fix for Arduino IDE
 * Normally this could just be in the main source code file
 */

// PORT-FIX for ATmega328 on windows + Arduino IDE
/*
#define PB0 PORTB0
#define PB1 PORTB1
#define PB2 PORTB2
#define PB3 PORTB3
#define PB4 PORTB4
#define PB5 PORTB5
#define PB6 PORTB6
#define PB7 PORTB7

#define PC0 PORTC0
#define PC1 PORTC1
#define PC2 PORTC2
#define PC3 PORTC3
#define PC4 PORTC4
#define PC5 PORTC5
#define PC6 PORTC6
#define PC7 PORTC7

#define PD0 PORTD0
#define PD1 PORTD1
#define PD2 PORTD2
#define PD3 PORTD3
#define PD4 PORTD4
#define PD5 PORTD5
#define PD6 PORTD6
#define PD7 PORTD7
*/

/*
 * Nicer naming of the pins
 */

#define RED_Ax _BV(PD6)
#define GREEN_Ax _BV(PD5)
#define BLUE_Ax _BV(PD7)

#define __fade_delay 5
