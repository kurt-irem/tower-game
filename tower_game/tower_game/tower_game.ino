/*
 * Tower Stack Game - Arduino Controller (Button + Stepper Motor)
 * 
 * This sketch reads button input and controls a stepper motor
 * that tilts with the tower based on balance.
 * 
 * Hardware Setup:
 * - Button connected to pin 2
 * - Stepper Motor with DRV8825 driver:
 *   - STEP  -> Pin 8
 *   - DIR   -> Pin 9
 *   - ENABLE -> Pin 10 (optional, can be tied to GND to always enable)
 *   - GND   -> GND
 *   - Motor A1, A2, B1, B2 to stepper motor coils
 */

const int BUTTON_PIN = 2;      // Button pin
const int STEP_PIN = 8;        // Stepper STEP pin
const int DIR_PIN = 9;         // Stepper DIR pin
const int ENABLE_PIN = 10;     // Stepper ENABLE pin

// Motor control
int currentMotorPosition = 0;
int targetMotorPosition = 0;
const int MAX_MOTOR_STEPS = 1600;    // Maximum tilt in each direction
const int MOTOR_STEP_SIZE = 10;      // Steps to move at a time
unsigned long lastMotorUpdate = 0;
const unsigned long MOTOR_UPDATE_INTERVAL = 20; // Update every 20ms
const int STEP_PULSE_WIDTH = 20;     // Microseconds for step pulse
unsigned long lastStepTime = 0;

void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  // Initialize stepper motor pins
  pinMode(STEP_PIN, OUTPUT);
  pinMode(DIR_PIN, OUTPUT);
  pinMode(ENABLE_PIN, OUTPUT);
  
  // Enable motor initially (LOW = enabled on DRV8825)
  digitalWrite(ENABLE_PIN, LOW);
  
  // Set initial direction
  digitalWrite(DIR_PIN, LOW);
  
  // Wait for serial connection
  while (!Serial) {
    ; 
  }
  
  Serial.println("Tower Game Controller Ready with DRV8825");
}

void loop() {
  // Read button press
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("DROP");
    delay(200); // Debounce
  }
  
  // Update motor position if target has changed
  updateMotorPosition();
  
  // Check for incoming tilt data from Processing
  if (Serial.available() > 0) {
    String data = Serial.readStringUntil('\n');
    data.trim();
    
    // Expected format: "TILT:value" where value is -100 to 100
    if (data.startsWith("TILT:")) {
      int tiltValue = data.substring(5).toInt();
      updateTiltTarget(tiltValue);
    }
  }
  
  delay(30);
}

void updateTiltTarget(int tiltValue) {
  // Convert tilt value (-100 to 100) to motor steps (-MAX_MOTOR_STEPS to MAX_MOTOR_STEPS)
  // tiltValue should come from Processing as a normalized value
  targetMotorPosition = map(tiltValue, -100, 100, -MAX_MOTOR_STEPS, MAX_MOTOR_STEPS);
}

void updateMotorPosition() {
  unsigned long currentTime = millis();
  
  // Update motor gradually to smooth movement
  if (currentTime - lastMotorUpdate >= MOTOR_UPDATE_INTERVAL) {
    lastMotorUpdate = currentTime;
    
    if (currentMotorPosition < targetMotorPosition) {
      // Move right (clockwise) - set DIR HIGH
      digitalWrite(DIR_PIN, HIGH);
      int stepsToMove = min(MOTOR_STEP_SIZE, targetMotorPosition - currentMotorPosition);
      moveMotorSteps(stepsToMove);
      currentMotorPosition += stepsToMove;
    } 
    else if (currentMotorPosition > targetMotorPosition) {
      // Move left (counter-clockwise) - set DIR LOW
      digitalWrite(DIR_PIN, LOW);
      int stepsToMove = min(MOTOR_STEP_SIZE, currentMotorPosition - targetMotorPosition);
      moveMotorSteps(stepsToMove);
      currentMotorPosition -= stepsToMove;
    }
  }
}

void moveMotorSteps(int steps) {
  for (int i = 0; i < steps; i++) {
    // Send pulse to STEP pin
    digitalWrite(STEP_PIN, HIGH);
    delayMicroseconds(STEP_PULSE_WIDTH);
    digitalWrite(STEP_PIN, LOW);
    delayMicroseconds(STEP_PULSE_WIDTH);
  }
}
