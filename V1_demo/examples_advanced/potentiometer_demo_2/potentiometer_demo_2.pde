// ! this example deliberately has reduced functionality !
// !  please use 'V1_demo.pde' as a reference   !

// connect a suitable potentiometer (50...500 kOhm) like so:
// one of the outer connectors (#1) to +5V
// the middle connector (#2, wiper) to ANALOG PIN #3 (PC3)
// the remaining connector (#3) to GND


//#define V122
//#define NEW_PCB_yellow
//#define NEW_PCB_green
#define OLD_PCB

#include <stdint.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include "potentiometer_demo_2.h"	// needed to make the 'enum' work with Arduino IDE (and other things)

uint8_t brightness_a_red[8]; 	/* memory for RED LEDs */
uint8_t brightness_a_green[8]; 	/* memory for GREEN LEDs */
uint8_t brightness_a_blue[8]; 	/* memory for BLUE LEDs */

uint8_t brightness_b_red[8]; 	/* memory for RED LEDs */
uint8_t brightness_b_green[8]; 	/* memory for GREEN LEDs */
uint8_t brightness_b_blue[8]; 	/* memory for BLUE LEDs */

uint8_t * brightness_red_read = brightness_a_red;
uint8_t * brightness_green_read = brightness_a_green;
uint8_t * brightness_blue_read = brightness_a_blue;

uint8_t * brightness_red_write = brightness_b_red;
uint8_t * brightness_green_write = brightness_b_green;
uint8_t * brightness_blue_write = brightness_b_blue;

#define __color_bit_depth 6
#define __max_brightness 63	// ( (2^__color_bit_depth) - 1 )

#define __fade_delay 5

#ifdef V122
uint8_t fix_led_numbering[8] = { 
  0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef NEW_PCB_yellow
uint8_t fix_led_numbering[8] = { 
  0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef NEW_PCB_green
uint8_t fix_led_numbering[8] = { 
  0, 1, 2, 3, 4, 5, 6, 7 };	// up-to-date boards have proper pin order. I was just too lazy to remove it from all the functions ;-)
#endif

#ifdef OLD_PCB
uint8_t fix_led_numbering[8] = { 
  3, 5, 4, 6, 7, 0, 1, 2 };	// this is necessary for older revisions (without DTR or >= 1.21 printed on the PCB)
#endif

int low_limit;
int high_limit;

void setup(void)
{
  DDRB |= 0xFF;		// set PORTB as output
  PORTB = 0xFF;		// all pins HIGH --> cathodes HIGH --> LEDs off

  DDRD |= (RED_Ax | GREEN_Ax | BLUE_Ax);	// set relevant pins as outputs
  PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);	// relevant pins LOW --> anodes LOW --> LEDs off

  setup_timer1_ctc();	// 7 color PWM mode

  set_all_rgb(0,255,0);	// when you see GREEN, turn the pot to the minimum setting
  flip_buffers();
  delay(2000);
  set_low_limit(&low_limit);
  set_all_rgb(255,0,0);	// when you see RED, turn it to the maximum setting
  flip_buffers();
  delay(2000);
  set_high_limit(&high_limit);
  set_all_rgb(0,0,0);	// after about 2 seconds, turn the pot up and down and observe the effect
  flip_buffers();
}

void loop(void)
{
  byte ctr;
  byte led;
  int adc_value = analogRead(3);
  static int adc_value_prev = 0;
  byte led_number = (byte)(constrain(map(adc_value,low_limit,high_limit,0,8),0,8));

  if(adc_value_prev != adc_value) {
    set_all_rgb(0,0,0);
    if(led_number > 0) {
      led_number--;
      for(ctr=0; ctr <= led_number; ctr++) {
        led = ctr; // normal direction
        // led=(8 - ctr) % 8; // reversed direction - disable the line above if you use this one

        // try the different version - only one line a time!
        
        //set_led_hsv(led,led_number*8,255,led_number*28+32);
        //set_led_hsv(led,220,255,255);
        set_led_hsv(led,led*32,255,255);        
      }
    } 
    flip_buffers();
  }
  adc_value_prev = adc_value;
}

void set_low_limit(int * low_limit_ptr) {
  *low_limit_ptr = analogRead(3);
}

void set_high_limit(int * high_limit_ptr) {
  *high_limit_ptr = analogRead(3);
}

/*
 * PWM_BLOCK_START: all functions in this block are related to PWM mode !
 */

/*
 *basic functions to set the LEDs
 */

void set_led_red(uint8_t led, uint8_t red)
{
  brightness_red_write[led] = red;
}

void set_led_green(uint8_t led, uint8_t green)
{
  brightness_green_write[led] = green;
}

void set_led_blue(uint8_t led, uint8_t blue)
{
  brightness_blue_write[led] = blue;
}

void set_led_rgb(uint8_t led, uint8_t red, uint8_t green, uint8_t blue)
{
  set_led_red(led, red);
  set_led_green(led, green);
  set_led_blue(led, blue);
}

void set_all_rgb(uint8_t red, uint8_t green, uint8_t blue)
{
  uint8_t ctr1;
  for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
    set_led_rgb(ctr1, red, green, blue);
  }
}

void set_all_hsv(uint16_t hue, uint8_t sat, uint8_t val)
{
  uint8_t ctr1;
  for (ctr1 = 0; ctr1 <= (8 - 1); ctr1++) {
    set_led_hsv(ctr1, hue, sat, val);
  }
}

void set_all_byte_hsv(uint8_t data_byte, uint16_t hue, uint8_t sat, uint8_t val)
{
  uint8_t led;
  for (led = 0; led <= (8 - 1); led++) {
    if (data_byte & _BV(led)) {
      set_led_hsv(led, hue, sat, val);
    } 
    else {
      set_led_rgb(led, 0, 0, 0);
    }
  }
}

void set_led_hsv(uint8_t led, uint16_t hue, uint8_t sat, uint8_t val)
{

  /* BETA */

  /* finally thrown out all of the float stuff and replaced with uint16_t
   	 *
   	 * hue: 0-->360 (hue, color)
   	 * sat: 0-->255 (saturation)
   	 * val: 0-->255 (value, brightness)
   	 *
   	 */

  hue = hue % 360;
  uint8_t sector = hue / 60;
  uint8_t rel_pos = hue - (sector * 60);
  uint16_t const mmd = 65025;	// 255 * 255 /* maximum modulation depth */
  uint16_t top = val * 255;
  uint16_t bottom = val * (255 - sat); 	/* (val*255) - (val*255)*(sat/255) */
  uint16_t slope = (uint16_t) (val) * (uint16_t) (sat) / 120; 	/* dy/dx = (top-bottom)/(2*60) -- val*sat: modulation_depth dy */
  uint16_t a = bottom + slope * rel_pos;
  uint16_t b =
    bottom + (uint16_t) (val) * (uint16_t) (sat) / 2 + slope * rel_pos;
  uint16_t c = top - slope * rel_pos;
  uint16_t d =
    top - (uint16_t) (val) * (uint16_t) (sat) / 2 - slope * rel_pos;

  uint16_t R, G, B;

  if (sector == 0) {
    R = c;
    G = a;
    B = bottom;
  } 
  else if (sector == 1) {
    R = d;
    G = b;
    B = bottom;
  } 
  else if (sector == 2) {
    R = bottom;
    G = c;
    B = a;
  } 
  else if (sector == 3) {
    R = bottom;
    G = d;
    B = b;
  } 
  else if (sector == 4) {
    R = a;
    G = bottom;
    B = c;
  } 
  else {
    R = b;
    G = bottom;
    B = d;
  }

  uint16_t scale_factor = mmd / __max_brightness;

  R = (uint8_t) (R / scale_factor);
  G = (uint8_t) (G / scale_factor);
  B = (uint8_t) (B / scale_factor);

  set_led_rgb(led, R, G, B);
}

/*
 * Functions dealing with hardware specific jobs / settings
 */

void flip_buffers(void)
{
  uint8_t * tmp;

  tmp = brightness_red_read;
  brightness_red_read = brightness_red_write;
  brightness_red_write = tmp;

  tmp = brightness_green_read;
  brightness_green_read = brightness_green_write;
  brightness_green_write = tmp;

  tmp = brightness_blue_read;
  brightness_blue_read = brightness_blue_write;
  brightness_blue_write = tmp;
}

void setup_timer1_ctc(void)
{
  // Arduino runs at 16 Mhz...
  // Timer1 (16bit) Settings:
  // prescaler (frequency divider) values:   CS12    CS11   CS10
  //                                           0       0      0    stopped
  //                                           0       0      1      /1  
  //                                           0       1      0      /8  
  //                                           0       1      1      /64
  //                                           1       0      0      /256 
  //                                           1       0      1      /1024
  //                                           1       1      0      external clock on T1 pin, falling edge
  //                                           1       1      1      external clock on T1 pin, rising edge
  //
  uint8_t _sreg = SREG; 	/* save SREG */
  cli(); 			/* disable all interrupts while messing with the register setup */

  /* set prescaler to 64 */
  TCCR1B |= ( _BV(CS10) | _BV(CS11));
  TCCR1B &= ~(_BV(CS12) );
  /* set WGM mode 4: CTC using OCR1A */
  TCCR1A &= ~(_BV(WGM10) | _BV(WGM11));
  TCCR1B |= _BV(WGM12);
  TCCR1B &= ~_BV(WGM13);
  /* normal operation - disconnect PWM pins */
  TCCR1A &= ~(_BV(COM1A1) | _BV(COM1A0) | _BV(COM1B1) | _BV(COM1B0));
  /* set top value for TCNT1 */
  OCR1A = 10;
  /* enable compare match interrupt */
  TIMSK1 |= _BV(OCIE1A);
  /* restore SREG with global interrupt flag */
  SREG = _sreg;
}

ISR(TIMER1_COMPA_vect)
{ 	/* Framebuffer interrupt routine */
  static uint8_t led = 0;

  static uint16_t bitmask = 0x0001;
  uint8_t OCR1A_next;

  PORTB = 0xFF;	// all cathodes HIGH --> OFF
  PORTD &= ~(RED_Ax | GREEN_Ax | BLUE_Ax);	// all relevant anodes LOW --> OFF
  PORTB &= ~_BV(fix_led_numbering[led]);	// only turn on the LED that we deal with right now (current sink, on when zero)

  if (brightness_red_read[led] & bitmask) {
    PORTD |= RED_Ax;
  }
  if (brightness_green_read[led] & bitmask) {
    PORTD |= GREEN_Ax;
  }
  if (brightness_blue_read[led] & bitmask) {
    PORTD |= BLUE_Ax;
  }

  OCR1A_next = bitmask;
  bitmask = bitmask << 1;

  if (bitmask == _BV(__color_bit_depth + 1)) {
    led++;
    bitmask = 0x0001;
    OCR1A_next = 1;
  }

  if (led == 8) {
    led = 0;
  }

  OCR1A = OCR1A_next;	// when to run next time
  TCNT1 = 0;	// clear timer to compensate for code runtime above
  TIFR1 = _BV(OCF1A);	// clear interrupt flag to kill any erroneously pending interrupt in the queue
}

/*
 * PWM_BLOCK_END: all functions in this block are related to PWM mode !
 */

