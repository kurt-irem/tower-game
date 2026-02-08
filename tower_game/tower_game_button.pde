/*
 * Tower Stack Game - Processing (Button Only Version)
 * 
 * Blocks move horizontally across the screen from left or right.
 * Press the button at the right time to drop the block onto the platform.
 * 
 * Controls:
 * - SPACE or Arduino Button: DROP
 * - R: Restart
 */

import processing.serial.*;

// Serial communication
Serial arduinoPort;
boolean useArduino = false;
String arduinoData = "";

// Game variables
Block currentBlock;
ArrayList<Block> stackedBlocks;
Platform platform;

// Game state
int score = 0;
boolean gameOver = false;
float fallSpeed = 2.0;
float blockWidth = 80;
float blockHeight = 30;
float towerOffset = 0;
float maxTowerOffset = 100;
float blockDescentAmount = 20;
float blockSpeed = 2.0; // Horizontal movement speed

// Colors
color[] blockColors = {
  #FF6B6B, #4ECDC4, #45B7D1, #FFA07A, 
  #98D8C8, #F7DC6F, #BB8FCE, #85C1E2
};

void setup() {
  size(800, 600);
  
  // Try to connect to Arduino
  initializeArduino();
  
  // Initialize game
  platform = new Platform(width/2, height - 100, 120, 20);
  stackedBlocks = new ArrayList<Block>();
  spawnNewBlock();
}

void draw() {
  background(30, 30, 40);
  
  // Read Arduino input if available
  if (useArduino && arduinoPort.available() > 0) {
    arduinoData = arduinoPort.readStringUntil('\n');
    if (arduinoData != null) {
      arduinoData = trim(arduinoData);
      handleArduinoInput(arduinoData);
    }
  }
  
  // Send tilt data to Arduino if connected
  if (useArduino) {
    sendTiltToArduino();
  }
  
  if (!gameOver) {
    // Update current block
    currentBlock.update();
    
    // Check if block has landed
    if (currentBlock.isFalling == false && stackedBlocks.contains(currentBlock)) {
      // Block has landed, move tower down
      for (Block b : stackedBlocks) {
        b.y += blockDescentAmount;
        if (b.hasTarget) {
          b.targetY += blockDescentAmount;
        }
      }
      platform.y += blockDescentAmount;
      
      score++;
      blockSpeed += 0.2; // Increase difficulty
      fallSpeed += 0.05;
      
      // Spawn new block
      spawnNewBlock();
    }
    
    // Display current block only if not in stack yet
    if (!stackedBlocks.contains(currentBlock)) {
      currentBlock.display();
    }
    
    // Check if block moved out of screen (missed)
    if (currentBlock.isOutOfBounds()) {
      gameOver = true;
    }
  } else {
    // Game over screen
    displayGameOver();
  }
  
  // Display stacked blocks with tilt effect
  pushMatrix();
  translate(width/2, 0);
  float tiltAngle = map(towerOffset, -maxTowerOffset, maxTowerOffset, -0.15, 0.15);
  rotate(tiltAngle);
  translate(-width/2, 0);
  for (Block b : stackedBlocks) {
    b.display();
  }
  popMatrix();
  
  // Display platform
  platform.display();
  
  // Display score and info
  displayUI();
}

void initializeArduino() {
  try {
    if (Serial.list().length > 0) {
      // Try to find Arduino port (avoid Bluetooth)
      String portName = null;
      for (String port : Serial.list()) {
        if (port.contains("usbmodem") || port.contains("usbserial") || port.contains("COM")) {
          portName = port;
          break;
        }
      }
      // If no Arduino-like port found, try first port
      if (portName == null) {
        portName = Serial.list()[0];
      }
      arduinoPort = new Serial(this, portName, 9600);
      arduinoPort.bufferUntil('\n');
      useArduino = true;
    }
  } catch (Exception e) {
    useArduino = false;
  }
}

void handleArduinoInput(String input) {
  String normalized = trim(input);
  if (normalized.equals("DROP") || normalized.startsWith("DROP")) {
    dropBlock();
  }
}

void sendTiltToArduino() {
  // Convert towerOffset (-maxTowerOffset to maxTowerOffset) to -100 to 100
  int tiltValue = (int) map(towerOffset, -maxTowerOffset, maxTowerOffset, -100, 100);
  String tiltData = "TILT:" + tiltValue + "\n";
  arduinoPort.write(tiltData);
}

void keyPressed() {
  if (gameOver) {
    if (key == 'r' || key == 'R') {
      resetGame();
    }
    return;
  }
  
  if (key == ' ') {
    dropBlock();
  }
}

void spawnNewBlock() {
  // Block starts from left or right side (alternating)
  float x = (score % 2 == 0) ? -blockWidth/2 : width + blockWidth/2;
  color c = blockColors[score % blockColors.length];
  currentBlock = new Block(x, 150, blockWidth, blockHeight, c);
}

float getTopOfStack() {
  if (stackedBlocks.size() == 0) {
    return platform.y;
  }
  return stackedBlocks.get(stackedBlocks.size() - 1).y;
}

void dropBlock() {
  if (gameOver) return;
  
  // Check if block is within drop zone (near center)
  float dropZoneLeft = platform.x - platform.w/2 - 30;
  float dropZoneRight = platform.x + platform.w/2 + 30;
  
  if (currentBlock.x >= dropZoneLeft && currentBlock.x <= dropZoneRight) {
    // Good timing! Block lands
    float targetX = stackedBlocks.size() == 0 ? platform.x : 
                    stackedBlocks.get(stackedBlocks.size() - 1).x;
    float targetWidth = stackedBlocks.size() == 0 ? platform.w : 
                        stackedBlocks.get(stackedBlocks.size() - 1).w;
    
    float overlap = calculateOverlap(currentBlock.x, currentBlock.w, targetX, targetWidth);
    
    if (overlap > 20) {
      // Calculate misalignment
      float misalignment = currentBlock.x - targetX;
      towerOffset += misalignment;
      
      if (abs(towerOffset) > maxTowerOffset) {
        gameOver = true;
        return;
      }
      
      // Successful placement
      currentBlock.targetY = getTopOfStack() - blockHeight;
      currentBlock.isFalling = true;
      currentBlock.hasTarget = true;
      stackedBlocks.add(currentBlock);
      
      // Don't move tower or spawn new block here - happens after landing
    } else {
      gameOver = true;
    }
  } else {
    // Bad timing - missed the drop zone
    gameOver = true;
  }
}

float calculateOverlap(float x1, float w1, float x2, float w2) {
  float left1 = x1 - w1/2;
  float right1 = x1 + w1/2;
  float left2 = x2 - w2/2;
  float right2 = x2 + w2/2;
  
  float overlapLeft = max(left1, left2);
  float overlapRight = min(right1, right2);
  
  return max(0, overlapRight - overlapLeft);
}

void displayUI() {
  fill(255);
  textAlign(LEFT);
  textSize(24);
  text("Score: " + score, 20, 40);
  
  // Stability bar
  textSize(16);
  text("Stability:", 20, 70);
  
  fill(50);
  rect(120, 55, 200, 20);
  
  float stabilityPercent = abs(towerOffset) / maxTowerOffset;
  color barColor = lerpColor(#00FF00, #FF0000, stabilityPercent);
  fill(barColor);
  rect(120, 55, 200 * stabilityPercent, 20);
  
  fill(255);
  textSize(14);
  text("Controls: SPACE or Button to DROP", 20, height - 40);
  text("Drop in the timing zone!", 20, height - 20);
  
  fill(useArduino ? #00FF00 : #FF0000);
  text("Arduino: " + (useArduino ? "Connected" : "Disconnected"), width - 200, 30);
}

void displayGameOver() {
  fill(255, 0, 0, 150);
  rect(0, height/2 - 80, width, 160);
  
  fill(255);
  textAlign(CENTER);
  textSize(48);
  text("GAME OVER!", width/2, height/2 - 20);
  
  textSize(24);
  text("Final Score: " + score, width/2, height/2 + 20);
  
  textSize(18);
  text("Press R to Restart", width/2, height/2 + 60);
}

void resetGame() {
  stackedBlocks.clear();
  score = 0;
  gameOver = false;
  fallSpeed = 1.0;
  blockSpeed = 2.0;
  blockWidth = 80;
  towerOffset = 0;
  platform.y = height - 100;
  spawnNewBlock();
}

// Block class
class Block {
  float x, y;
  float w, h;
  color c;
  boolean isFalling;
  float targetY; // Target position when dropping
  boolean hasTarget; // Whether block is falling to a target
  int direction; // 1 = right, -1 = left
  
  Block(float x, float y, float w, float h, color c) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.c = c;
    this.isFalling = false;
    this.hasTarget = false;
    this.targetY = y;
    // Determine direction based on starting position
    this.direction = (x < width/2) ? 1 : -1;
  }
  
  void update() {
    if (!isFalling && !hasTarget) {
      // Move horizontally in the initial direction
      x += blockSpeed * direction;
    } else if (hasTarget) {
      // Block is falling to target position
      if (y < targetY) {
        y += fallSpeed;
        // Check if reached target
        if (y >= targetY) {
          y = targetY;
          hasTarget = false;
          isFalling = false;
        }
      }
    }
  }
  
  void display() {
    fill(c);
    stroke(255);
    strokeWeight(2);
    rectMode(CENTER);
    rect(x, y, w, h, 5);
  }
  
  boolean isOutOfBounds() {
    return x < -blockWidth || x > width + blockWidth;
  }
}

// Platform class
class Platform {
  float x, y;
  float w, h;
  
  Platform(float x, float y, float w, float h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }
  
  void display() {
    fill(100, 100, 120);
    stroke(255);
    strokeWeight(3);
    rectMode(CENTER);
    rect(x, y, w, h, 5);
    
    // Center line indicator
    stroke(255, 255, 0);
    line(x, y - h/2 - 10, x, y + h/2 + 10);
    
    // Drop zone indicator
    stroke(0, 255, 0, 100);
    strokeWeight(2);
    float dropZoneLeft = x - w/2 - 30;
    float dropZoneRight = x + w/2 + 30;
    line(dropZoneLeft, y - h/2 - 30, dropZoneLeft, y + h/2 + 30);
    line(dropZoneRight, y - h/2 - 30, dropZoneRight, y + h/2 + 30);
  }
}
