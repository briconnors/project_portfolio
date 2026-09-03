#include <SPI.h>
#include <SD.h>
#include <Adafruit_ADXL375.h>
#include <Adafruit_Sensor.h>

// accelerometer spi pins
#define ADXL_SCLK 18
#define ADXL_MISO 19
#define ADXL_MOSI 23

// sd card spi pins
// sd DI = MOSI
// sd DO = MISO
#define SD_SCLK 14
#define SD_MISO 12
#define SD_MOSI 13

// each spi device needs its own cs pin
#define SD_CS 5
#define ADXL_CS 17

// buttons
#define BTN_START 21
#define BTN_RESET 22

// leds
#define LED_RED 16
#define LED_GREEN 4

// fifo buffer setup
#define ADXL_REG_DATAX0 0x32
#define ADXL_REG_FIFO_CTL 0x38
#define ADXL_REG_FIFO_STATUS 0x39

#define ADXL_READ 0x80
#define ADXL_MULTI 0x40

#define ADXL_SCALE_MPS2 (0.049f*9.80665f)

// trial settings
#define SAMPLE_RATE_HZ 3200
#define RECORD_TIME_S 1
#define MAX_SAMPLES (SAMPLE_RATE_HZ*RECORD_TIME_S)

struct Sample{
  uint32_t t_us;
  float ax;
  float ay;
  float az;
};

Sample dataBuffer[MAX_SAMPLES];
int sampleCount=0;
uint32_t actualRecordTime_us=0;

SPIClass adxlSPI(VSPI);
SPIClass sdSPI(HSPI);

Adafruit_ADXL375 accel=Adafruit_ADXL375(ADXL_CS,&adxlSPI,12345);

bool startPressed(){
  return digitalRead(BTN_START)==LOW;
}

bool resetPressed(){
  return digitalRead(BTN_RESET)==LOW;
}

void waitForButtonRelease(int pin){
  while(digitalRead(pin)==LOW){
    checkResetButton();
    delay(10);
  }
  delay(50);
}

void readyLights(){
  // save battery: no constant ready light
  digitalWrite(LED_RED,LOW);
  digitalWrite(LED_GREEN,LOW);
}

void countdownLights(){
  // red pulse only
  digitalWrite(LED_RED,HIGH);
  digitalWrite(LED_GREEN,LOW);
  delay(150);
  digitalWrite(LED_RED,LOW);
}

void recordingLights(){
  // quick red flash = recording started
  digitalWrite(LED_GREEN,LOW);
  digitalWrite(LED_RED,HIGH);
  delay(100);
  digitalWrite(LED_RED,LOW);

  // green on during the actual 1 second recording
  digitalWrite(LED_GREEN,HIGH);
}

void savingLights(){
  // save battery: green only while saving
  digitalWrite(LED_RED,LOW);
  digitalWrite(LED_GREEN,HIGH);
}

void doneLights(){
  digitalWrite(LED_RED,LOW);
  digitalWrite(LED_GREEN,HIGH);
  delay(300);
  digitalWrite(LED_GREEN,LOW);
}

void errorLights(){
  digitalWrite(LED_GREEN,LOW);
  digitalWrite(LED_RED,HIGH);
}

void checkResetButton(){
  if(resetPressed()){
    delay(50);
    if(resetPressed()){
      Serial.println("reset button pressed");
      errorLights();
      delay(150);
      ESP.restart();
    }
  }
}

String nextFileName(){
  char filename[24];

  for(int i=1;i<1000;i++){
    sprintf(filename,"/trial%03d.csv",i);

    if(!SD.exists(filename)){
      return String(filename);
    }
  }

  return "/trial999.csv";
}

void deselectSPI(){
  digitalWrite(SD_CS,HIGH);
  digitalWrite(ADXL_CS,HIGH);
  delay(10);
}

void countdown(){
  Serial.println("trial starts in 5 seconds");

  digitalWrite(LED_RED,LOW);
  digitalWrite(LED_GREEN,LOW);

  for(int i=5;i>0;i--){
    Serial.print(i);
    Serial.println("...");

    countdownLights();

    for(int j=0;j<8;j++){
      checkResetButton();
      delay(100);
    }
  }

  Serial.println("drop/record now");
  recordingLights();
}

void adxlWriteReg(uint8_t reg,uint8_t val){
  digitalWrite(ADXL_CS,LOW);
  adxlSPI.transfer(reg);
  adxlSPI.transfer(val);
  digitalWrite(ADXL_CS,HIGH);
}

uint8_t adxlReadReg(uint8_t reg){
  digitalWrite(ADXL_CS,LOW);
  adxlSPI.transfer(reg|ADXL_READ);
  uint8_t val=adxlSPI.transfer(0x00);
  digitalWrite(ADXL_CS,HIGH);
  return val;
}

void adxlReadRawXYZ(int16_t &x,int16_t &y,int16_t &z){
  uint8_t b[6];

  digitalWrite(ADXL_CS,LOW);
  adxlSPI.transfer(ADXL_REG_DATAX0|ADXL_READ|ADXL_MULTI);

  for(int i=0;i<6;i++){
    b[i]=adxlSPI.transfer(0x00);
  }

  digitalWrite(ADXL_CS,HIGH);

  x=(int16_t)((b[1]<<8)|b[0]);
  y=(int16_t)((b[3]<<8)|b[2]);
  z=(int16_t)((b[5]<<8)|b[4]);
}

void setupAdxlFifo(){
  adxlWriteReg(ADXL_REG_FIFO_CTL,0b10011111);
  delay(10);
}

uint8_t fifoEntries(){
  return adxlReadReg(ADXL_REG_FIFO_STATUS)&0x3F;
}

void clearAdxlFifo(){
  adxlWriteReg(ADXL_REG_FIFO_CTL,0x00);
  delay(5);

  adxlWriteReg(ADXL_REG_FIFO_CTL,0b10011111);
  delay(5);
}

void recordTrial(){
  sampleCount=0;
  actualRecordTime_us=0;

  clearAdxlFifo();

  uint32_t dt_us=1000000UL/SAMPLE_RATE_HZ;
  uint32_t startTime=micros();
  uint32_t lastSampleTime=startTime;

  Serial.println("recording now");
  recordingLights();

  while(sampleCount<MAX_SAMPLES){
    checkResetButton();

    uint8_t entries=fifoEntries();

    while(entries>0 && sampleCount<MAX_SAMPLES){
      int16_t rawX,rawY,rawZ;
      adxlReadRawXYZ(rawX,rawY,rawZ);

      dataBuffer[sampleCount].t_us=lastSampleTime-startTime;
      dataBuffer[sampleCount].ax=rawX*ADXL_SCALE_MPS2;
      dataBuffer[sampleCount].ay=rawY*ADXL_SCALE_MPS2;
      dataBuffer[sampleCount].az=rawZ*ADXL_SCALE_MPS2;

      sampleCount++;
      lastSampleTime+=dt_us;
      entries--;
    }
  }

  actualRecordTime_us=micros()-startTime;

  Serial.println("recording finished");

  Serial.print("actual record time s = ");
  Serial.println(actualRecordTime_us/1000000.0,6);

  Serial.print("samples collected = ");
  Serial.println(sampleCount);

  Serial.print("effective saved sample rate hz = ");
  Serial.println(sampleCount/(actualRecordTime_us/1000000.0),2);
}

void saveTrial(){
  String filename=nextFileName();

  Serial.print("saving to ");
  Serial.println(filename);

  savingLights();

  File file=SD.open(filename,FILE_WRITE);

  if(!file){
    Serial.println("error: file could not open");
    errorLights();
    return;
  }

  file.println("t_us,ax_mps2,ay_mps2,az_mps2");

  for(int i=0;i<sampleCount;i++){
    file.print(dataBuffer[i].t_us);
    file.print(",");
    file.print(dataBuffer[i].ax,6);
    file.print(",");
    file.print(dataBuffer[i].ay,6);
    file.print(",");
    file.println(dataBuffer[i].az,6);
  }

  file.close();

  Serial.print("saved ");
  Serial.print(sampleCount);
  Serial.print(" samples to ");
  Serial.println(filename);

  doneLights();
}

void runTrial(){
  countdown();
  recordTrial();
  saveTrial();

  Serial.println("done");
  Serial.println("press green button or type r to run another trial");
  readyLights();
}

void setup(){
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("drop rig logger starting");

  pinMode(SD_CS,OUTPUT);
  pinMode(ADXL_CS,OUTPUT);
  digitalWrite(SD_CS,HIGH);
  digitalWrite(ADXL_CS,HIGH);

  pinMode(BTN_START,INPUT_PULLUP);
  pinMode(BTN_RESET,INPUT_PULLUP);

  pinMode(LED_RED,OUTPUT);
  pinMode(LED_GREEN,OUTPUT);
  digitalWrite(LED_RED,LOW);
  digitalWrite(LED_GREEN,LOW);

  adxlSPI.begin(ADXL_SCLK,ADXL_MISO,ADXL_MOSI,ADXL_CS);
  sdSPI.begin(SD_SCLK,SD_MISO,SD_MOSI,SD_CS);

  deselectSPI();

  Serial.println("checking sd card");

  digitalWrite(ADXL_CS,HIGH);
  digitalWrite(SD_CS,HIGH);
  delay(50);

  if(!SD.begin(SD_CS,sdSPI,400000)){
    Serial.println("error: sd card failed");
    Serial.println("check sd vcc, gnd, sclk, di, do, and cs");
    Serial.println("sd pin reminder: DI->GPIO13, DO->GPIO12, SCK->GPIO14, CS->GPIO5");

    while(true){
      checkResetButton();
      digitalWrite(LED_RED,HIGH);
      delay(300);
      digitalWrite(LED_RED,LOW);
      delay(300);
    }
  }

  Serial.println("sd card okay");

  Serial.println("checking adxl375");

  digitalWrite(SD_CS,HIGH);
  digitalWrite(ADXL_CS,HIGH);
  delay(50);

  if(!accel.begin()){
    Serial.println("error: adxl375 not found");
    Serial.println("check adxl vcc, gnd, sclk, miso/sdo, mosi/sda, and cs");

    while(true){
      checkResetButton();
      digitalWrite(LED_RED,HIGH);
      delay(150);
      digitalWrite(LED_RED,LOW);
      delay(150);
    }
  }

  Serial.println("adxl375 okay");

  accel.setDataRate(ADXL343_DATARATE_3200_HZ);
  setupAdxlFifo();

  Serial.println("adxl fifo stream mode on");
  Serial.println("setup done");
  Serial.println("red led = ready");
  Serial.println("green led = recording/drop");
  Serial.println("red + green = saving");
  Serial.println("press green/start button to start trial");
  Serial.println("press red/reset button to software reset");
  Serial.println("or type r in serial monitor to run trial");
  Serial.println("or type x in serial monitor to reset");

  readyLights();
}

void loop(){
  checkResetButton();

  if(startPressed()){
    waitForButtonRelease(BTN_START);
    runTrial();
  }

  if(Serial.available()){
    char c=Serial.read();

    if(c=='r' || c=='R'){
      runTrial();
    }

    if(c=='x' || c=='X'){
      Serial.println("serial reset");
      delay(100);
      ESP.restart();
    }
  }

  delay(20);
}