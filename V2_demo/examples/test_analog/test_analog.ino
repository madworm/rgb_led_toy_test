/**
 * Reads the analog voltages connected to the pins labeled
 * PC0, PC1, PC2, PC3, SDA (PC4), SCL (PC5)
 *
 * and prints the result to the serial port (TXO)
 *
 * Unconnected pins will give random values.
 *
 * Use a wire to connect each pin to either GND or 5V
 * or any other positive voltage smaller than 5V.
 *
 * When connected to GND, the result should be 0
 * When conencted to 5V, the result sould be 1023
 *
 */

uint8_t analog_pins[6] = {0, 1, 2, 3, 4, 5};

void setup(void) {
  Serial.begin(9600);
}

void loop(void) {
  uint8_t counter;
  for(counter = 0; counter < 6; counter++) {
    Serial.print(F("Analog channel "));
    Serial.print(counter);
    Serial.print(F(" : "));
    Serial.println(analogRead(analog_pins[counter]));
  }
  Serial.println("");
  delay(1000);
}
