/*
 * Tower Stack Game - Processing
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
int lastTiltSendTime = 0;
int tiltSendInterval = 50; // Send tilt data every 50ms instead of every frame

// Game variables
Block currentBlock;
ArrayList<Block> stackedBlocks;
Platform platform;

// Game state
int score = 0;
boolean gameOver = false;
float fallSpeed = 5.0;
float blockWidth = 80;
float blockHeight = 30;
float towerOffset = 0;
float maxTowerOffset = 100;
float blockDescentAmount = 20;
float blockSpeed = 5.5; // Horizontal movement speed

// Colors 
color[] blockColors = {
  #667EEA, #764BA2, #F093FB, #4FACFE,
  #43E97B, #FA709A, #FEE140, #30CFD0
};
color bgColor1 = #0B0B1A;
color bgColor2 = #1A1A3E;
color bgColor3 = #0F1B2E;
color accentColor = #667EEA;
color textColor = #FFFFFF;
color successColor = #43E97B;
color dangerColor = #FA709A;

// Background particles
ArrayList<Star> stars;

void setup() {
  size(900, 700);
  
  // Initialize background stars
  stars = new ArrayList<Star>();
  for (int i = 0; i < 50; i++) {
    stars.add(new Star());
  }
  
  // Try to connect to Arduino
  initializeArduino();
  
  // Initialize game
  platform = new Platform(width/2, height - 100, 120, 20);
  stackedBlocks = new ArrayList<Block>();
  spawnNewBlock();
}

void draw() {
  // Gradient background
  drawGradientBackground();
  
  // Read Arduino input if available
  if (useArduino) {
    try {
      while (arduinoPort.available() > 0) {
        arduinoData = arduinoPort.readStringUntil('\n');
        if (arduinoData != null) {
          arduinoData = trim(arduinoData);
          handleArduinoInput(arduinoData);
        }
      }
    } catch (Exception e) {
      // Serial connection failed
      useArduino = false;
      println("Arduino connection lost: " + e.getMessage());
    }
  }
  
  // Send tilt data to Arduino if connected (rate limited)
  if (useArduino && millis() - lastTiltSendTime > tiltSendInterval) {
    sendTiltToArduino();
    lastTiltSendTime = millis();
  }
  
  if (!gameOver) {
    // Update current block
    currentBlock.update();
    
    // Check if block has landed
    if (currentBlock.isFalling == false && stackedBlocks.contains(currentBlock)) {
      // Block has landed - now apply the tilt!
      towerOffset += currentBlock.misalignment;
      
      // Move tower down
      for (Block b : stackedBlocks) {
        b.y += blockDescentAmount;
        if (b.hasTarget) {
          b.targetY += blockDescentAmount;
        }
      }
      platform.y += blockDescentAmount;
      
      score++;
      blockSpeed += 0.2; // Increase difficulty
      fallSpeed += 0.1;
      
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
  }
  
  // Display stacked blocks
  for (Block b : stackedBlocks) {
    b.display();
  }
  
  // Display platform
  platform.display();
  
  // Display score and info
  displayUI();

  // Game over screen
  if (gameOver) {
    displayGameOver();
  }
}

void initializeArduino() {
  try {
    if (Serial.list().length > 0) {
      // Try to find Arduino port
      String portName = null;
      for (String port : Serial.list()) {
        if (port.contains("usbmodem") || port.contains("usbserial") || port.contains("COM")) {
          portName = port;
          break;
        }
      }
      // If no Arduino-like port found, don't try any port
      if (portName != null) {
        arduinoPort = new Serial(this, portName, 9600);
        arduinoPort.bufferUntil('\n');
        // Wait a moment and test if port is actually working
        delay(100);
        arduinoPort.clear(); // Clear any startup noise
        useArduino = true;
        println("Arduino connected on: " + portName);
      } else {
        println("No Arduino port found");
        useArduino = false;
      }
    } else {
      println("No serial ports available");
      useArduino = false;
    }
  } catch (Exception e) {
    println("Arduino connection failed: " + e.getMessage());
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
  try {
    // Convert towerOffset (-maxTowerOffset to maxTowerOffset) to -100 to 100
    int tiltValue = (int) map(towerOffset, -maxTowerOffset, maxTowerOffset, -100, 100);
    String tiltData = "TILT:" + tiltValue + "\n";
    arduinoPort.write(tiltData);
    
    // Debug: Print to console
    println("Sending to Arduino: " + tiltData.trim() + " (towerOffset: " + towerOffset + ")");
  } catch (Exception e) {
    // Serial write failed
    useArduino = false;
    println("Failed to send to Arduino: " + e.getMessage());
  }
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
  if (currentBlock.isFalling || currentBlock.hasTarget) return;
  
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
      // Calculate misalignment but don't apply to tower yet
      float misalignment = currentBlock.x - targetX;
      currentBlock.misalignment = misalignment;
      
      // Check if this would cause game over
      if (abs(towerOffset + misalignment) > maxTowerOffset) {
        gameOver = true;
        return;
      }
      
      // Successful placement
      currentBlock.targetY = getTopOfStack() - blockHeight;
      currentBlock.isFalling = true;
      currentBlock.hasTarget = true;
      stackedBlocks.add(currentBlock);
      
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
  // Ensure correct rect mode for UI elements
  rectMode(CORNER);
  
  // Top-left layout: score card with tilt underneath
  float topY = 20;
  float leftX = 20;
  float scoreSize = 90;
  float gap = 16;
  float tiltWidth = 340;
  float tiltHeight = 95;
  
  // Tilt card on top
  float tiltX = leftX;
  float tiltY = topY;
  drawCard(tiltX, tiltY, tiltWidth, tiltHeight);
  fill(textColor);
  textAlign(LEFT);
  textSize(14);
  text("TILT BALANCE", tiltX + 20, tiltY + 28);
  
  // Tilt bar background
  float barX = tiltX + 20;
  float barY = tiltY + 48;
  float barWidth = tiltWidth - 40;
  float barHeight = 24;
  
  // Score square underneath tilt
  float scoreX = leftX;
  float scoreY = tiltY + tiltHeight + gap;
  drawCard(scoreX, scoreY, scoreSize, scoreSize);
  fill(textColor);
  textAlign(CENTER);
  textSize(14);
  text("SCORE", scoreX + scoreSize/2, scoreY + 28);
  textSize(32);
  text(score, scoreX + scoreSize/2, scoreY + 68);
  
  // Background track
  fill(30, 30, 50);
  noStroke();
  rect(barX, barY, barWidth, barHeight, 12);
  
  // Center safe zone (green area)
  fill(successColor, 50);
  float safeZoneWidth = barWidth * 0.4;
  rect(barX + barWidth/2 - safeZoneWidth/2, barY, safeZoneWidth, barHeight, 12);
  
  // Calculate tilt position (-maxTowerOffset to +maxTowerOffset maps to 0 to barWidth)
  float tiltPercent = map(towerOffset, -maxTowerOffset, maxTowerOffset, 0, 1);
  float indicatorX = barX + barWidth * tiltPercent;
  
  // Danger zones markers
  stroke(dangerColor, 100);
  strokeWeight(2);
  line(barX + barWidth * 0.15, barY, barX + barWidth * 0.15, barY + barHeight);
  line(barX + barWidth * 0.85, barY, barX + barWidth * 0.85, barY + barHeight);
  
  // Center line
  stroke(255, 255, 255, 150);
  strokeWeight(3);
  line(barX + barWidth/2, barY - 5, barX + barWidth/2, barY + barHeight + 5);
  
  // Moving indicator
  float stabilityPercent = abs(towerOffset) / maxTowerOffset;
  color indicatorColor = lerpColor(successColor, dangerColor, stabilityPercent);
  
  // Indicator glow
  noStroke();
  fill(indicatorColor, 60);
  ellipse(indicatorX, barY + barHeight/2, 35, 35);
  
  // Indicator circle
  fill(indicatorColor);
  stroke(255);
  strokeWeight(3);
  ellipse(indicatorX, barY + barHeight/2, 25, 25);
  
  // Stability percentage
  textAlign(CENTER);
  fill(indicatorColor);
  textSize(13);
  text(int((1 - stabilityPercent) * 100) + "%", barX + barWidth/2, barY - 8);
  
  // Controls hint
  fill(textColor, 150);
  textAlign(CENTER);
  textSize(14);
  text("Press SPACE or Button to DROP the block", width/2, height - 30);
  
  // Arduino status badge
  float badgeX = width - 160;
  float badgeY = 30;
  if (useArduino) {
    fill(successColor, 30);
    stroke(successColor);
  } else {
    fill(dangerColor, 30);
    stroke(dangerColor);
  }
  strokeWeight(2);
  rect(badgeX, badgeY, 140, 30, 15);
  
  fill(useArduino ? successColor : dangerColor);
  noStroke();
  circle(badgeX + 20, badgeY + 15, 8);
  
  fill(textColor);
  textAlign(LEFT);
  textSize(14);
  text(useArduino ? "Connected" : "Disconnected", badgeX + 30, badgeY + 20);
}

void displayGameOver() {
  // Ensure correct rect mode
  rectMode(CORNER);
  
  // Dark overlay
  fill(0, 0, 0, 180);
  rect(0, 0, width, height);
  
  // Game over card
  drawCard(width/2 - 250, height/2 - 150, 500, 300);
  
  // Title
  fill(dangerColor);
  textAlign(CENTER);
  textSize(56);
  text("GAME OVER", width/2, height/2 - 60);
  
  // Score display
  fill(textColor, 150);
  textSize(18);
  text("YOUR SCORE", width/2, height/2);
  
  fill(accentColor);
  textSize(64);
  text(score, width/2, height/2 + 60);
  
  // Restart hint with pulsing effect
  float pulse = sin(millis() * 0.005) * 0.3 + 0.7;
  fill(textColor, 255 * pulse);
  textSize(20);
  text("Press R to Restart", width/2, height/2 + 120);
}

void resetGame() {
  stackedBlocks.clear();
  score = 0;
  gameOver = false;
  fallSpeed = 5.0;
  blockSpeed = 5.0;
  blockWidth = 80;
  towerOffset = 0;
  platform.y = height - 100;
  
  // Reset servo to center position
  if (useArduino) {
    try {
      arduinoPort.write("RESET\n");
    } catch (Exception e) {
      // Ignore if sending fails
    }
  }
  
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
  float misalignment; // Misalignment to apply when block lands
  
  Block(float x, float y, float w, float h, color c) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.c = c;
    this.isFalling = false;
    this.hasTarget = false;
    this.targetY = y;
    this.misalignment = 0;
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
    // Save and set rect mode
    rectMode(CENTER);
    
    // Shadow
    fill(0, 0, 0, 50);
    noStroke();
    rect(x + 3, y + 3, w, h, 8);
    
    // Block with gradient effect
    fill(c);
    stroke(255, 255, 255, 100);
    strokeWeight(2);
    rect(x, y, w, h, 8);
    
    // Highlight
    fill(255, 255, 255, 30);
    noStroke();
    rect(x, y - h/4, w * 0.8, h/3, 5);
  }
  
  boolean isOutOfBounds() {
    return x < -blockWidth || x > width + blockWidth;
  }
}

// Helper function for gradient background
void drawGradientBackground() {
  // Dark night sky gradient
  for (int i = 0; i <= height; i++) {
    float inter = map(i, 0, height, 0, 1);
    color c;
    if (inter < 0.5) {
      c = lerpColor(bgColor1, bgColor2, inter * 2);
    } else {
      c = lerpColor(bgColor2, bgColor3, (inter - 0.5) * 2);
    }
    stroke(c);
    line(0, i, width, i);
  }
  
  // Draw and update stars
  for (Star star : stars) {
    star.update();
    star.display();
  }
}

// Helper function for UI cards with shadow
void drawCard(float x, float y, float w, float h) {
  // Ensure CORNER mode for cards
  rectMode(CORNER);
  
  // Shadow
  noStroke();
  fill(0, 0, 0, 120);
  rect(x + 4, y + 4, w, h, 15);
  
  // Card background - brighter for better visibility
  fill(45, 50, 70, 230);
  stroke(255, 255, 255, 60);
  strokeWeight(1);
  rect(x, y, w, h, 15);
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
    // Set rect mode for platform
    rectMode(CENTER);
    
    // Platform shadow
    fill(0, 0, 0, 80);
    noStroke();
    rect(x + 2, y + 4, w, h, 8);
    
    // Platform base
    fill(60, 60, 80);
    stroke(accentColor);
    strokeWeight(3);
    rect(x, y, w, h, 8);
    
    // Platform highlight
    fill(255, 255, 255, 20);
    noStroke();
    rect(x, y - h/3, w * 0.9, h/4, 5);
    
    // Center line indicator with glow
    stroke(accentColor, 200);
    strokeWeight(3);
    line(x, y - h/2 - 15, x, y + h/2 + 15);
    stroke(accentColor, 80);
    strokeWeight(6);
    line(x, y - h/2 - 15, x, y + h/2 + 15);
    
    // Drop zone indicator with animated glow
    float pulse = sin(millis() * 0.003) * 0.3 + 0.7;
    stroke(successColor, 150 * pulse);
    strokeWeight(3);
    float dropZoneLeft = x - w/2 - 30;
    float dropZoneRight = x + w/2 + 30;
    line(dropZoneLeft, y - h/2 - 35, dropZoneLeft, y + h/2 + 35);
    line(dropZoneRight, y - h/2 - 35, dropZoneRight, y + h/2 + 35);
    
    // Drop zone glow
    stroke(successColor, 50 * pulse);
    strokeWeight(8);
    line(dropZoneLeft, y - h/2 - 35, dropZoneLeft, y + h/2 + 35);
    line(dropZoneRight, y - h/2 - 35, dropZoneRight, y + h/2 + 35);
  }
}

// Star class for background animation
class Star {
  float x, y;
  float size;
  float alpha;
  float speed;
  
  Star() {
    x = random(width);
    y = random(height);
    size = random(1, 3);
    alpha = random(100, 255);
    speed = random(0.5, 2);
  }
  
  void update() {
    alpha += speed;
    if (alpha > 255) {
      alpha = 255;
      speed = -speed;
    } else if (alpha < 100) {
      alpha = 100;
      speed = -speed;
    }
  }
  
  void display() {
    noStroke();
    fill(255, 255, 255, alpha);
    ellipse(x, y, size, size);
  }
}
