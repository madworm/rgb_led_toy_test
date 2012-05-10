
!! You need at least a 2.0beta board for this to work !!


If you need super-smooth color fading, please use the Arduino 'ShiftPWM' library.
Version 1.03 works with the Arduino IDE V0023 (tested).

Download location: http://code.google.com/p/shiftpwm/downloads/list


There are a few short modifications to make it work:
----------------------------------------------------

1.) Open the file 'CShiftPWM.cpp' in the library folder.


2.) Search for the function 'CShiftPWM::SetGroupOf3' and replace it with this:

--- snip ---

void CShiftPWM::SetGroupOf3(int group, unsigned char v0,unsigned char v1,unsigned char v2){
	if(IsValidPin(group*3+2) ){
		m_PWMValues[group]=v0;
		m_PWMValues[group+8]=v1;
		m_PWMValues[group+16]=v2;
	}
}

--- snip ---

This takes care of the different arrangement of LED drivers. The original library assumes:
RGBRGBRGB... and so on. The LED ring board uses RRRRRRRR - GGGGGGGG - BBBBBBBB.

If you need the other functions as well, modify them accordingly.

Don't forget to save the file before you compile code.


3.) Insert these 2 lines in the setup() function of the 'ShiftPWM_Example1' example:

--- snip ---

DDRB |= _BV(PB6);
PORTB &= ~_BV(PB6); 

--- snip ---

This enables the LED drivers on the V2.x.x ring boards.


4.) change / set these variables in the 'ShiftPWM_Example1' example:

const int ShiftPWM_latchPin = 10;
const bool ShiftPWM_invertOutputs = 0;
int numRegisters = 3;


5.) Compile and upload.


Have fun!

