/*
 * Tower Stack Game - Arduino Controller
 * 
 * This sketch reads joystick input and sends commands to Processing
 * via Serial communication.
 * 
 * Hardware Setup:
 * - Joystick X-axis connected to A0
 * - Joystick button (optional) connected to pin 2
 */

const int JOYSTICK_X = A0;  // Joystick X-axis pin
const int JOYSTICK_Y = A1;  // Joystick Y-axis pin
const int BUTTON_PIN = 2;    // Optional: Joystick button

int xValue = 0;
int yValue = 0;
int centerThreshold = 50;    // Deadzone around center

void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  // Wait for serial connection
  while (!Serial) {
    ; 
  }
}

void loop() {
  // Read joystick axes (0-1023)
  xValue = analogRead(JOYSTICK_X);
  yValue = analogRead(JOYSTICK_Y);
  
  // Determine direction based on joystick position
  // Center is around 512
  if (xValue < (512 - centerThreshold)) {
    // Left movement
    Serial.println("LEFT");
  } 
  else if (xValue > (512 + centerThreshold)) {
    // Right movement
    Serial.println("RIGHT");
  }
  
  // Check for down movement
  if (yValue > (512 + centerThreshold)) {
    // Down movement - drop block faster
    Serial.println("DOWN");
  }
  
  // Optional: Read button press for drop/action
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("DROP");
    delay(200); // Debounce
  }
  
  delay(50); // Small delay to avoid flooding serial
}
