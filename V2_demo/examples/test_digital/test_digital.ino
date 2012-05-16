/**
 * Reads the digital state of the pins labeled
 * PC0, PC1, PC2, PC3, SDA (PC4), SCL (PC5)
 *
 * and prints the result to the serial port (TXO)
 *
 * Unconnected pins will be reported as "1".
 *
 * Use a wire to connect each pin to GND.
 * When connected to GND, the result should be "0"
 *
 */

uint8_t digital_pins[6] = {14, 15, 16, 17, 18, 19};

void setup(void) {
  Serial.begin(9600);
  uint8_t counter;
  for(counter = 0; counter < 6; counter++) {
    pinMode(digital_pins[counter],INPUT);
    digitalWrite(digital_pins[counter],HIGH); // internal pull-up resistor on - otherwise we get random readings
  }
}

void loop(void) {
  uint8_t counter;
  for(counter = 0; counter < 6; counter++) {
    Serial.print(F("Digital channel "));
    Serial.print(counter);
    Serial.print(F(" : "));
    Serial.println(digitalRead(digital_pins[counter]));
  }
  Serial.println("");
  delay(1000);
}
