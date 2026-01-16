/*
 * Tower Stack Game - Processing
 * 
 * A block falls from above and the player must align it with the platform
 * using keyboard (A/D or Arrow keys) or Arduino joystick.
 * Stack blocks on top of each other to build the highest tower!
 * 
 * Controls:
 * - Left: A or LEFT ARROW or Joystick Left
 * - Right: D or RIGHT ARROW or Joystick Right
 * - Drop: SPACE or Joystick Button
 * - Restart: R
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
int blockWidth = 80;
int blockHeight = 30;

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
  
  if (!gameOver) {
    // Update and display current falling block
    currentBlock.update();
    currentBlock.display();
    
    // Check if block reached platform/top of stack
    float targetY = getTopOfStack();
    if (currentBlock.y >= targetY - blockHeight) {
      dropBlock();
    }
  } else {
    // Game over screen
    displayGameOver();
  }
  
  // Display stacked blocks
  for (Block b : stackedBlocks) {
    b.display();
  }
  
  // Display platform
  platform.display();
  
  // Display score and info
  displayUI();
}

void initializeArduino() {
  // Try to connect to Arduino
  try {
    if (Serial.list().length > 0) {
      String portName = Serial.list()[0]; // Change index if needed
      arduinoPort = new Serial(this, portName, 9600);
      useArduino = true;
      println("Arduino connected on: " + portName);
    }
  } catch (Exception e) {
    println("Arduino not found. Using keyboard only.");
    useArduino = false;
  }
}

void handleArduinoInput(String input) {
  if (input.equals("LEFT")) {
    currentBlock.moveLeft();
  } else if (input.equals("RIGHT")) {
    currentBlock.moveRight();
  } else if (input.equals("DROP")) {
    dropBlock();
  }
}

void keyPressed() {
  if (gameOver) {
    if (key == 'r' || key == 'R') {
      resetGame();
    }
    return;
  }
  
  // Movement controls
  if (key == 'a' || key == 'A' || keyCode == LEFT) {
    currentBlock.moveLeft();
  } else if (key == 'd' || key == 'D' || keyCode == RIGHT) {
    currentBlock.moveRight();
  } else if (key == ' ') {
    dropBlock();
  }
}

void spawnNewBlock() {
  float x = random(blockWidth/2, width - blockWidth/2);
  color c = blockColors[score % blockColors.length];
  currentBlock = new Block(x, 0, blockWidth, blockHeight, c);
}

float getTopOfStack() {
  if (stackedBlocks.size() == 0) {
    return platform.y;
  }
  return stackedBlocks.get(stackedBlocks.size() - 1).y;
}

void dropBlock() {
  if (gameOver) return;
  
  // Check alignment with platform or top block
  float targetX = stackedBlocks.size() == 0 ? platform.x : 
                  stackedBlocks.get(stackedBlocks.size() - 1).x;
  float targetWidth = stackedBlocks.size() == 0 ? platform.w : 
                      stackedBlocks.get(stackedBlocks.size() - 1).w;
  
  float overlap = calculateOverlap(currentBlock.x, currentBlock.w, targetX, targetWidth);
  
  // Check if there's enough overlap
  if (overlap > 20) { // Minimum overlap threshold
    // Successful placement
    currentBlock.y = getTopOfStack() - blockHeight;
    currentBlock.w = overlap;
    currentBlock.x = (max(currentBlock.x - currentBlock.w/2, targetX - targetWidth/2) + 
                      min(currentBlock.x + currentBlock.w/2, targetX + targetWidth/2)) / 2;
    currentBlock.isFalling = false;
    stackedBlocks.add(currentBlock);
    
    score++;
    fallSpeed += 0.1; // Increase difficulty
    blockWidth = overlap; // Next block matches the overlap width
    
    // Spawn new block
    spawnNewBlock();
  } else {
    // Failed - Game Over
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
  // Score
  fill(255);
  textAlign(LEFT);
  textSize(24);
  text("Score: " + score, 20, 40);
  
  // Controls info
  textSize(14);
  text("Controls: A/D or Arrows or Joystick", 20, height - 40);
  text("Drop: SPACE", 20, height - 20);
  
  // Arduino status
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
  fallSpeed = 2.0;
  blockWidth = 80;
  spawnNewBlock();
}

// Block class
class Block {
  float x, y;
  float w, h;
  color c;
  boolean isFalling;
  
  Block(float x, float y, float w, float h, color c) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.c = c;
    this.isFalling = true;
  }
  
  void update() {
    if (isFalling) {
      y += fallSpeed;
    }
  }
  
  void display() {
    fill(c);
    stroke(255);
    strokeWeight(2);
    rectMode(CENTER);
    rect(x, y, w, h, 5);
  }
  
  void moveLeft() {
    if (isFalling) {
      x = max(w/2, x - 10);
    }
  }
  
  void moveRight() {
    if (isFalling) {
      x = min(width - w/2, x + 10);
    }
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
  }
}
