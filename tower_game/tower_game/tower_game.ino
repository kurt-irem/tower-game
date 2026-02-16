/*
 * Tower Stack Game - Arduino Controller (Button + Servo Motor + Fans)
 * 
 * This sketch reads button input and controls a servo motor
 * that tilts with the tower based on balance.
 * 
 * Hardware Setup:
 * - Button connected to pin 2
 * - Joy-it PWM Servo Motor -> Pin 10
 * - Left Fan -> Pin 5 
 * - Right Fan -> Pin 6 
 */

#include <Servo.h>

const int BUTTON_PIN = 2;      // Button pin
const int SERVO_PIN = 10;      // Servo signal pin 
const int LEFT_FAN_PIN = 5;    // Left fan
const int RIGHT_FAN_PIN = 6;   // Right fan

// Servo control
Servo tiltServo;
int targetServoAngle = 90;     // Target angle (0-180, 90 = center)
int currentServoAngle = 90;    // Current angle
const int SERVO_CENTER = 90;   // Center position (no tilt)
const int SERVO_MIN = 70;      // Minimum angle (max left tilt)
const int SERVO_MAX = 110;     // Maximum angle (max right tilt)

// Fan control
unsigned long leftFanStartTime = 0;
unsigned long rightFanStartTime = 0;
const unsigned long FAN_DURATION = 3000;  // 3 seconds
boolean leftFanActive = false;
boolean rightFanActive = false;

void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  // Initialize fan pins
  pinMode(LEFT_FAN_PIN, OUTPUT);
  pinMode(RIGHT_FAN_PIN, OUTPUT);
  digitalWrite(LEFT_FAN_PIN, LOW);
  digitalWrite(RIGHT_FAN_PIN, LOW);
  
  // Initialize servo motor
  tiltServo.attach(SERVO_PIN);
  tiltServo.write(SERVO_CENTER);  // Start at center position
  currentServoAngle = SERVO_CENTER;
  targetServoAngle = SERVO_CENTER;
  
  // Wait for serial connection
  while (!Serial) {
    ; 
  }
  
  Serial.println("Tower Game Controller Ready with Servo Motor and Fans");
}

void loop() {
  // Read button press
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("DROP");
    delay(200); // Debounce
  }
  
  // Update servo position smoothly
  updateServoPosition();
  
  // Update fan states
  updateFans();
  
  // Check for incoming tilt data from Processing
  if (Serial.available() > 0) {
    String data = Serial.readStringUntil('\n');
    data.trim();
    
    // Expected format: "TILT:value" where value is -100 to 100
    if (data.startsWith("TILT:")) {
      int tiltValue = data.substring(5).toInt();
      Serial.print("Parsed tilt value: ");
      Serial.print(tiltValue);
      Serial.print(" -> Target angle: ");
      updateTiltTarget(tiltValue);
      Serial.println(targetServoAngle);
    }
    // Reset servo to center on game reset
    else if (data.equals("RESET")) {
      targetServoAngle = SERVO_CENTER;
      Serial.println("Servo reset to center");
    }
  }
}

void updateTiltTarget(int tiltValue) {
  // Convert tilt value (-100 to 100) to servo angle (SERVO_MIN to SERVO_MAX)
  // -100 = max left tilt, 0 = center, +100 = max right tilt
  targetServoAngle = map(tiltValue, -100, 100, SERVO_MIN, SERVO_MAX);
  targetServoAngle = constrain(targetServoAngle, SERVO_MIN, SERVO_MAX);
}

void updateServoPosition() {
  // Smoothly move servo to target position
  if (currentServoAngle < targetServoAngle) {
    currentServoAngle++;
    tiltServo.write(currentServoAngle);
    
    // Tilting right (angle increasing) -> activate left fan
    if (currentServoAngle > SERVO_CENTER + 3 && !leftFanActive) {
      activateLeftFan();
    }
    
    delay(10);
  } 
  else if (currentServoAngle > targetServoAngle) {
    currentServoAngle--;
    tiltServo.write(currentServoAngle);
    
    // Tilting left (angle decreasing) -> activate right fan
    if (currentServoAngle < SERVO_CENTER - 3 && !rightFanActive) {
      activateRightFan();
    }
    
    delay(10);
  }
}

void activateLeftFan() {
  digitalWrite(LEFT_FAN_PIN, HIGH);
  leftFanActive = true;
  leftFanStartTime = millis();
}

void activateRightFan() {
  digitalWrite(RIGHT_FAN_PIN, HIGH);
  rightFanActive = true;
  rightFanStartTime = millis();
}

void updateFans() {
  // Check if left fan should be turned off
  if (leftFanActive && (millis() - leftFanStartTime >= FAN_DURATION)) {
    digitalWrite(LEFT_FAN_PIN, LOW);
    leftFanActive = false;
  }
  
  // Check if right fan should be turned off
  if (rightFanActive && (millis() - rightFanStartTime >= FAN_DURATION)) {
    digitalWrite(RIGHT_FAN_PIN, LOW);
    rightFanActive = false;
  }
}
