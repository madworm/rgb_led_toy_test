/*
 * Fix for Arduino IDE
 * Normally this could just be in the main source code file
 */

enum COLOR_t {
	BLACK,
	RED,
	GREEN,
	BLUE,
	YELLOW,
	TURQUOISE,
	PURPLE,
	WHITE
};

enum DIRECTION_t {
	CW,
	CCW
};

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
#define LED0 PB0
#define LED1 PB1
#define LED2 PB2
#define LED3 PB3
#define LED4 PB4
#define LED5 PB5
#define LED6 PB6
#define LED7 PB7

#ifdef V122
#define RED_A PD6
#define GREEN_A PD5
#define BLUE_A PD7
#define RED_A2 PD3
#define GREEN_A2 PD2
#define BLUE_A2 PD4
#endif

#ifdef NEW_PCB_yellow		// new LEDs from JELEDHK (ebay). Cheaper, but reversed chips in the PLCC6-5050 package --> LEDs rotated by 180°
#define RED_A PD6
#define GREEN_A PD5
#define BLUE_A PD7
#endif

#ifdef NEW_PCB_green
#define RED_A PD5
#define GREEN_A PD6
#define BLUE_A PD7
#endif

#ifdef OLD_PCB
#define RED_A PD5
#define GREEN_A PD6
#define BLUE_A PD7
#endif

#ifdef V122
#define RED_Ax ( _BV(RED_A) | _BV(RED_A2) )
#define GREEN_Ax ( _BV(GREEN_A) | _BV(GREEN_A2) )
#define BLUE_Ax ( _BV(BLUE_A) | _BV(BLUE_A2) )
#else
#define RED_Ax _BV(RED_A)
#define GREEN_Ax _BV(GREEN_A)
#define BLUE_Ax _BV(BLUE_A)
#endif
