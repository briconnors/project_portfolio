#include <SPI.h>
#include <AS5047P.h>

// breakout board with SPI [labels are on the bottom]
AS5047P as5047p(9);        // right
AS5047P as5047pb(10);     // left

/* NOTE! WIRE TRUE COLORS RED->RED, BLACK->BLACK FOR BOTH MOTORS
from the front view:
motor L (left) Positive angle=clockwise rotation as increasing encoder angle
1=HIGH, 2=LOW: motor spins clockwise
1=LOW, 2=HIGH: motor spins counterclockwise*/

#define AIN1 17
#define AIN2 16
#define PWMA 14

/* motor R (right) Positive physical rotation appears as decreasing encoder angle (ccw)
1=HIGH, 2=LOW: motor spins counterclockwise
1=LOW, 2=HIGH: motor spins clockwise*/

#define BIN1 18
#define BIN2 19
#define PWMB 15

// LEDs
#define GREEN_LED 2
#define YELLOW_LED 3
#define RED_LED 4

// buttons
#define ON_BUTTON 7
#define OFF_BUTTON 8
#define RESET_BUTTON 6
#define QUICK_BUTTON 5

// BUTTONS, related timing variables & flags
int buttonStatus = HIGH;
int buttonStop   = HIGH;
int buttonReset  = HIGH;
int buttonQuick  = HIGH;
bool resetFlag = false;
bool quickRun = false;
bool buttonTriggered = false;
bool initialized=false;

// LED flags
bool red = false;
bool yellow = false;
bool green = false;
bool lightsOn = false;

bool syncMode = false;

// MAIN MOTOR LOOP setup
float frequency = 1;
float amplitude = 3.1415926535 / 2;
int goal;

int dira; int dirb;                            // direction from encoder read
float u_pos; float u_posb;                     // position PID error
float u_phase;
float pwra = 100; float pwrb = 100;            // motor power      
float vff;      
double derivative; double derivativeb;         // dirty derivative variables
float deriv_prev; float deriv_prevb;

float angleRad; float angleRadb;          // radians (set by pullAngle)
float angleRadBound; float angleRadBoundb;     // radians bounded
float ref;
float angleDeg; float angleDegb;          // degrees 0..360
float angleDegPrev = 0; float angleDegPrevb = 0;
float angleDegPrevRaw=0; float angleDegPrevbRaw=0;
float unwrapped_angleA = 0; float unwrapped_angleB = 0;
float vel_setpoint; float vel_setpointb;
float prev_error;
float angleDegPrevPivot = 0.0f;

// ZERO-CROSSING
int32_t t=0; int32_t tb=0;                           //initializing wraparound counter
uint32_t deadband=4;                                 //deadband for registering a revolution
bool prior_zero= false; bool prior_zerob= false;     //flag for when 0 was just called

// DIRTY DIFFERENTIATOR (DERIVATIVE + LOWPASS)
float beta = 0.99f;          // [0,1] closer to 1 = more smoothing

// POSITION PID CONSTANTS (kpa=2, kia=.001 or 0 for better response, kda=0)
float kp_posA = 1.0;
float ki_posA = 0.2;
float kd_posA = 0.00;

float kp_posB = 2.;
float ki_posB = 0.00;
float kd_posB = 0.00;

// VELOCITY PID CONSTANTS (kp=10,kia=.05, kda=0.001)
float kp_velA = 3.0;
float ki_velA = 0.02;
float kd_velA = 0.005;

float kp_velB = 10.;
float ki_velB = 0.;
float kd_velB = 0.;

// timing and errors for custom position PID
float pos_setpoint;
// PID state (separate memory for each loop)
float pos_totalErrorA = 0.0f; float prev_posErrorA  = 0.0f;
float vel_totalErrorA = 0.0f; float prev_velErrorA  = 0.0f;
float pos_totalErrorB = 0.0f; float prev_posErrorB  = 0.0f;
float vel_totalErrorB = 0.0f; float prev_velErrorB  = 0.0f;

//timing variables
float dt_s;                    //time per loop
const uint32_t dt_us = 1000;   // 1ms
float sigma = 1000;
uint32_t previousTime=0; 
uint32_t deltatime = 0;
uint32_t startTime = 0;

void setup() {
  Serial.begin(4000000);
  //Serial.println("time_us,angle_deg,unwrap_deg,setpoint_deg,velocity,pwm,dir");
  Serial.println("time_us,actual_angle,velocity,setpoint,motor_pwm,derivative");
  analogWriteResolution(8);

  // motors
  pinMode(AIN1, OUTPUT);
  pinMode(AIN2, OUTPUT);
  pinMode(PWMA, OUTPUT);
  pinMode(BIN1, OUTPUT);
  pinMode(BIN2, OUTPUT);
  pinMode(PWMB, OUTPUT);

  // buttons (wired to GND when pressed)
  pinMode(ON_BUTTON, INPUT_PULLUP);
  pinMode(OFF_BUTTON, INPUT_PULLUP);
  pinMode(RESET_BUTTON, INPUT_PULLUP);
  pinMode(QUICK_BUTTON, INPUT_PULLUP);

  // LEDs
  pinMode(GREEN_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);
  digitalWrite(GREEN_LED, LOW);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(RED_LED, LOW);

  // encoder
  SPI.begin();
  as5047p.initSPI();
  as5047pb.initSPI();
}

void loop() {
  // read buttons
  int startValue = digitalRead(ON_BUTTON);     
  int stopValue  = digitalRead(OFF_BUTTON);
  int resetValue = digitalRead(RESET_BUTTON);
  int quickValue = digitalRead(QUICK_BUTTON);
  
  //troubleshooting
  /*pullAngle();
  unwrapped_angleA=zero_crossing_check(angleDeg, prior_zero, angleDegPrevRaw);
  angleDegPrevRaw = angleDeg;

  Serial.print(angleDeg);
  Serial.print(";");
  Serial.print(unwrapped_angleA);
  Serial.println();*/


  // START button (edge detect)
  if (buttonStatus != startValue) {
    buttonStatus = startValue;
    if (buttonStatus == LOW) {
      reset();                // clear previous state
      buttonTriggered = true;
      startTime = micros();
      previousTime = 0;
      Serial.println("#START pressed");
    }
  }

  // STOP button (edge detect)
  if (buttonStop != stopValue) {
    buttonStop = stopValue;
    if (buttonStop == LOW) {
      reset();                // immediate stop & clear state
      Serial.println("#STOP pressed");
      // don't return; allow the rest of loop to run for housekeeping
    }
  }

  // RESET button (edge detect)
  if (buttonReset != resetValue) {
    buttonReset = resetValue;
    if (buttonReset == LOW) {
      resetFlag = true;
      Serial.println("#RESET pressed");
    }
  }

  // QUICK button (edge detect)
  if (buttonQuick != quickValue) {
    buttonQuick = quickValue;
    if (buttonQuick == LOW) {
      buttonTriggered = true;
      lightsOn = true;
      quickRun = true;
      startTime = micros();             //start time since button pressed
      previousTime = 0;                 //reset global timer
      Serial.println("#QUICK pressed");
    }
  }

  // GREEN LED when position control is active
  if (!green && buttonTriggered) {
    digitalWrite(GREEN_LED, HIGH);
    green = true;
  }

  // reset-TO-ZERO (drive motors back to absolute 0)
  if (resetFlag) {
    const float targetDeg = 50.0;               // degrees target (consistent with PID which expects degrees)
    pullAngle();                                // refresh encoder readings
    dt_s = 0.001f;
    float delta_deg_a = targetDeg - angleDeg;   // distance from current position to goal
    float delta_deg_b = targetDeg + angleDegb;

    // check if both axes are within threshold (within 4 degrees)
    if (fabs(delta_deg_a) <= deadband && fabs(delta_deg_b) <= deadband) {
      setMotors(0, 0, 0, 0);
      resetFlag = false;
      Serial.println("Reset complete: within threshold");
    } else {
      // compute position PID 
      u_pos  = pos_PIDa(targetDeg, angleDeg);
      u_posb = pos_PIDb(targetDeg, -angleDegb);
      dira=shortest_path(targetDeg, angleDeg);

      setPower(u_pos);
      setPower(u_posb);
      setMotors((int)pwra, dira, (int)pwrb, dirb);

      // debug output so you can see what's happening
      Serial.print("ResetA deg: "); Serial.print(angleDeg);
      Serial.print(" u_pos: "); Serial.println(u_pos);

      Serial.print("ResetB deg: "); Serial.print(angleDegb);
      Serial.print(" u_posb: "); Serial.println(u_posb);
    }
  }

  // TIMING & main run logic
  if (buttonTriggered) {
    deltatime = micros() - startTime; //refresh time since button press

    if (!red) {
      digitalWrite(RED_LED, HIGH);
      red = true;
    }

    // 1 second = 1,000,000 microseconds
    if (deltatime > 1000000UL && !yellow) {
      digitalWrite(YELLOW_LED, HIGH);
      analogWriteResolution(8);
      yellow = true;
      lightsOn = true;
    }

    //if the lights are on or quick run button gets pressed start sequence
    if (lightsOn || quickRun) {
      if (deltatime >= 0 && deltatime < 30000000UL) {             // constrain to total of 30 seconds
        if ((deltatime - previousTime) >= dt_us) {                //iterate each timestep

          //WAITING: after 5 seconds waiting worth of wait and hold at a setpoint prints, then run main continuous motor code
          if(deltatime<=5000000UL){
            //stationary setpoint to change and refresh key variables
            pos_setpoint=10;
            pullAngle();                                    //get sensor data of current position and save before unwrapping
            dt_s = (deltatime - previousTime) * 1e-6f;      //compute actual increment
            
            //one time at start, initialize the variables so it doesn't bug out
            if (!initialized) {
              clearHistory();
              prev_error = shortest_delta(pos_setpoint, angleDeg);
              angleDegPrevPivot = angleDeg;
              initialized = true;
            }
            runPivotHoldMode(pos_setpoint);
            //print();
            //serial_read();
            //tuning(); 
            data_analysis_log();

            angleDegPrevRaw = angleDeg;
          }

          // RUNNING!!: after 5 seconds waiting, start moving
          else if(deltatime <= 10000000UL) { 
            pullAngle();                                    //get sensor data of current position and save before unwrapping
            dt_s = (deltatime - previousTime) * 1e-6f;      //compute actual increment
            pos_setpoint += 360.0f*4*dt_s;                            // degrees
            runContinuousMode(pos_setpoint);

            //troubleshooting
            //print();                                    //helper to show all important variables
            //serial_read();
            //tuning();
            data_analysis_log();

            angleDegPrevRaw=angleDeg; angleDegPrevbRaw=angleDegb;
            angleDegPrev  = unwrapped_angleA; angleDegPrevb = unwrapped_angleB;

            initialized = false; //allow the control to transition back to stationary setpoint smoothly (without control jumping)
          }

          // RUNNING, but back to holding at the original position (to test changes in motion)
          else {
            //stationary setpoint to change and refresh key variables
            pullAngle();                                    //get sensor data of current position and save before unwrapping
            dt_s = (deltatime - previousTime) * 1e-6f;      //compute actual increment
            pos_setpoint=10;
            //refresh all variables with error adjustment to avoid spike in derivative at start
            if (!initialized) {
              clearHistory();
              angleDegPrevPivot = angleDeg;
              prev_error = shortest_delta(pos_setpoint, angleDeg);
              initialized = true;
            }
            runPivotHoldMode(pos_setpoint);
            //print();
            //serial_read();
            //tuning(); 
            data_analysis_log();

            angleDegPrevRaw = angleDeg;
          }
           previousTime = deltatime;
        }
      }
    }
  }
}

void runContinuousMode(float pos_setpoint){
  //fixing wraparound issue
  unwrapped_angleA=zero_crossing_check(angleDeg, prior_zero, angleDegPrevRaw);
  unwrapped_angleB=zero_crossing_checkb(angleDegb, prior_zerob, angleDegPrevbRaw);
  unwrapped_angleB= -unwrapped_angleB;            //fix direction counterclockwise

  float error= pos_setpoint-unwrapped_angleA;
  if (error>= 0.0f){
    dira=1;
  }
  else{
    dira=0;
  }

  // position setpoint converted to required motor speed (use degrees for position PID)
  u_pos  = pos_PIDa(pos_setpoint, unwrapped_angleA);
  u_posb = pos_PIDb(pos_setpoint, unwrapped_angleB);
  vff= 360.0f * 4.0f;                                         //feedforward (derivative of the setpoint)
  
  //bool to be able to randomly resync at any time during the motion manually
  if (syncMode){
    float phase_error= unwrapped_angleA-unwrapped_angleB;
    u_phase  = phase_PID(phase_error);                    // to reuse my PID's since its (setpoint-position) error-0=e as the error input (sorta hacky to reuse sorry)
  }
  else{
    u_phase =0;                                              //avoiding adding more noise to controller in general use
  }

  // output from PIDs (in degrees/second) including angular position error, the experimental velocity feedforward, and only if called a phase control pairing both motors
  vel_setpoint  = u_pos+vff-u_phase; vel_setpointb = u_posb+vff+u_phase;            
  float pwm_ff= vel_setpoint/8.0f; //18.74f originallybut tuned; 

  // using sensor data to get current velocity
  derivative  = differentiator(unwrapped_angleA,angleDegPrev, deriv_prev);
  derivativeb = differentiator(unwrapped_angleB,angleDegPrevb, deriv_prevb);
  // velocity setpoint converted to motor power
  float u_vel  = vel_PIDa(vel_setpoint, derivative);
  float u_velb = vel_PIDb(vel_setpointb, derivativeb);
  //constrain and set the power based on the inner velocity loop **direction from vel pid
  float u_pwm= pwm_ff +0.2f* u_vel;
  float u_pwmb=pwm_ff +0.2f* u_velb;
  pwra=setPower(u_pwm); pwrb=setPower(u_pwmb);
  setMotors((int)pwra, dira, 0, 0); //(int)pwrb, dirb

}

void runPivotHoldMode(float pos_setpoint){
  //wrapping the error
  float error= shortest_delta(pos_setpoint, angleDeg);
  //this ones just for prints to make sense
  unwrapped_angleA=zero_crossing_check(angleDeg, prior_zero, angleDegPrevRaw);
  // position setpoint converted to required motor speed (use degrees for position PID)
  u_pos  = pos_PIDa(error, 0.0f);                    // to reuse my PID's since its (setpoint-position) error-0=e as the error input (sorta hacky to reuse sorry)
  u_posb = pos_PIDb(pos_setpoint, angleDegb);
  /*// output from PID (in degrees/second)
  vel_setpoint  = u_pos; vel_setpointb = u_posb;
  // using sensor data to get current velocity using a differentiator
  derivative  = differentiator(angleDeg,angleDegPrevPivot, deriv_prev);
  derivativeb = differentiator(unwrapped_angleB,angleDegPrevb, deriv_prevb);
  // velocity setpoint converted to motor power
  float u_vel  = vel_PIDa(vel_setpoint, derivative);
  float u_velb = vel_PIDb(vel_setpointb, derivativeb);*/

  //for movement within a bound set direction based on shortest error
  dira=shortest_path(pos_setpoint, angleDeg); 
  //constrain and set the power based on the inner velocity loop
  pwra=setPower(u_pos); pwrb=setPower(u_posb);

  /*prevent deadband stopping near setpoint
  if (fabs(error)>1.0f && fabs(u_pos)>0 && pwra <35){
    pwra=35;
  }*/

  setMotors((int)pwra, dira, 0, 0); //(int)pwrb, dirb
  prev_error= error;
}

//wrapping for the error around the zero crossing for the hold/pivot motion
float shortest_delta(float setpoint, float position){
  float error= setpoint-position;
  if (error> 180.0f){                                     //if more than half a rotation away, turn the other direction (across 0)
    error -= 360.0f;
  }
  else if (error <-180.0f) {                              
    error += 360.0f;
  }
  return error;
}

//DIRTY DIFFERENTIATOR (with low-pass filter)
float differentiator(float current, float &previous, float &deriv_prev) {
  float dx= (current-previous)/dt_s;
  deriv_prev= beta*deriv_prev + (1.0f-beta)*dx;         //beta filter d[n]=(beta * d[n+1]) + (1-beta)*dx
  previous=current;
  return deriv_prev;
}

//FOR CLOCKWISE FORWARD (LEFT) MOTOR
float zero_crossing_check(float angleDeg, bool &prior_zero, float angleDegPrevRaw) {
  //flags to increase/decrease when within deadband close to 0 on either side
  bool zero_cross= (angleDeg<(float)deadband || angleDeg>(360-(float)deadband)); //if angle near 0 on either side
  bool high= (angleDeg>(360.0f-deadband));              //high current angle position and zero cross
  bool low= (angleDeg<deadband);                        //low angle and zero cross

  static bool wasHigh = false;                          //signals if the prior zero corresponds to a cross

  if (zero_cross){                                      //if within the deadband area, note which side its on
    if (!prior_zero){
      wasHigh = high;
    }
    //once inside of the deadband, decide which side its crossing from to determine counter sign
    else if(wasHigh && low && (angleDeg-angleDegPrevRaw)<-300.0f) {         //if goal is zero cross(0-360), clockwise, and large negative change in reading
      t+=1; //zero crossing counter increases
      wasHigh = false;
      }
    else if (!wasHigh && high && (angleDeg-angleDegPrevRaw)>300.0f) {       //counterclockwise same (360-0)
      t-=1; //counter decreases
      wasHigh = true;
      }
  }
  prior_zero=zero_cross;                          //update flag for when within 0 deadband
  float unwrapped_angleA= angleDeg + 360.0f * (float)t; //add the counter onto the angle to unwrap
  return unwrapped_angleA;
}

//FOR COUNTERCLOCKWISE FORWARD (RIGHT) MOTOR
float zero_crossing_checkb( float angleDegb, bool &prior_zerob, float angleDegPrevbRaw) {
  
  //counters to increase/decrease when within deadband close to 0
  bool zero_crossb= (angleDegb<(float)deadband || angleDegb>(360-(float)deadband)); //if angle near 0 on either side
  bool highb= (angleDegb>(360.0f-deadband) && zero_crossb);         //high current angle position and zero cross
  bool lowb= (angleDegb<deadband && zero_crossb);            //low angle and zero cross

  if (zero_crossb && !prior_zerob){
    if (lowb && (angleDegb-angleDegPrevbRaw)<-180) {   //if goal is zero cross(0-360), clockwise, and large negative change in reading
      tb-=1; //zero crossing counter decreases
      }
    else if (highb && (angleDegb-angleDegPrevbRaw)>180) {          //counterclockwise same (360-0)
      tb+=1; //counter increases
      }
  }
prior_zerob=zero_crossb;                          //update flag for when within 0 deadband
float unwrapped_angleB= angleDegb + 360.0f * (float)tb;
return unwrapped_angleB;
}

// PROPORTION INTEGRAL DERIVATIVES (PID)---------------------------------------------------------------
// position functions expect degrees for setpoint 
float pos_PIDa(float setpoint, float input) {
  float error = setpoint - input;                       //proportional error
  pos_totalErrorA += error * dt_s;                             //integral error
  float instError = (error - prev_posErrorA) / dt_s;       //derivative error
  float output = (kp_posA * error) + (ki_posA * pos_totalErrorA) + (kd_posA * instError); //using input constants for motor A
  prev_posErrorA = error;
  return output;
}
//velocity functions expect degrees/sec as setpoint
float vel_PIDa(float setpoint, float input) {
  float error = setpoint - input;                       //proportional error
  float instError = (error - prev_velErrorA) / dt_s;       //derivative error
  //using input constants for motor A
  float output = (kp_velA * error) + (ki_velA * vel_totalErrorA) + (kd_velA * instError);
  float output_saturated = constrain(output, -250.0f, 250.0f);

  //antiwindup for integral
  bool saturated = (output>250.0f || output<-250.0f);
  if (ki_velA !=0.0f) {                                              // if outside of bounds of motor
    if (saturated){
      vel_totalErrorA += (output_saturated-output)/ki_velA;}             // subtract the control effort to bring it back to 0
    else{
      vel_totalErrorA += error * dt_s;}
  }
  output = (kp_velA * error) + (ki_velA * vel_totalErrorA) + (kd_velA * instError); //recompute with adjustment
  prev_velErrorA = error;
  return output;
}
float pos_PIDb(float setpoint, float input) {
  float error = setpoint - input;
  pos_totalErrorB += error * dt_s;
  float instError = (error - prev_posErrorB) / dt_s;

  //using input constants for motor B
  float output = (kp_posB * error) + (ki_posB * pos_totalErrorB) + (kd_posB * instError);
  prev_posErrorB = error;
  return output;
}
float vel_PIDb(float setpoint, float input) {
  float error = setpoint - input;
  float instError = (error - prev_velErrorB) / dt_s;
  //using input constants for motor B
  float output = (kp_velB * error) + (ki_velB * vel_totalErrorB) + (kd_velB * instError);
  float output_saturated = constrain(output, -250.0f, 250.0f);
  //antiwindup for integral
  bool saturated = (output>250.0f || output<-250.0f);
  //antiwindup for integral
  if (ki_velB !=0.0f) {                                              // if outside of bounds of motor
    if (saturated){
      vel_totalErrorB += (output_saturated-output)/ki_velB;}             // subtract the control effort to bring it back to 0
    else{
      vel_totalErrorB += error * dt_s;}
  }
  output = (kp_velB * error) + (ki_velB * vel_totalErrorB) + (kd_velB * instError); //recompute with adjustment
  prev_velErrorB = error;
  return output;
}
//PHASE PID (for resync calls)
float phase_PID(float phase_error) { //only P for now because position collapses response a degree (maybe I later)
  const float kp_phase = 0.8;
  return (kp_phase * phase_error);
}

int shortest_path(float setpoint, float position) {
  float delta=setpoint-position;
  //handle zero crossing so it doesn't get stuck
  if (delta > 180.0f){
    delta -= 360.0f;
  }
  else if (delta < -180.0f) {
    delta += 360.0f;
  }

  if (delta >= 0.0f){
    delta=1;
  }
  else{
    delta=0;
  }
  return delta;
  }

//FUNCTIONAL CODE (to make motors and encoders work together)-------------------------------
//UPDATE SENSOR DATA (and convert to degrees)
void pullAngle() {
  // SPI encoder chip read
  uint16_t a = as5047p.readAngleRaw();
  uint16_t b = as5047pb.readAngleRaw();

  angleDeg = a * 360.0 / 16384.0;
  angleDegb = b * 360.0 / 16384.0;
}
//CONSTRAIN CONTROLS (to avoid blowing motors)
int setPower(float u) {
  float pwr = fabs(u);
  pwr = constrain(pwr, 0, 250);
  return (int)pwr;
}
//MAIN MOTOR CODE
void setMotors(int pwma, int dira_in, int pwmb, int dirb_in) {
  if (dira_in) {
    digitalWrite(AIN1, HIGH);
    digitalWrite(AIN2, LOW);
  } else {
    digitalWrite(AIN1, LOW);
    digitalWrite(AIN2, HIGH);
  }
  analogWrite(PWMA, pwma);
[]
  if (dirb_in) {
    digitalWrite(BIN1, HIGH);
    digitalWrite(BIN2, LOW);
  } else {
    digitalWrite(BIN1, LOW);
    digitalWrite(BIN2, HIGH);
  }
  analogWrite(PWMB, pwmb);
}

//PRINTS AND DEBUGGING-----------------------------------------------------------------
void clearHistory(){
  angleDegPrevRaw  = angleDeg; angleDegPrevbRaw = angleDegb;
  t = 0; tb = 0;
  prior_zero = false; prior_zerob = false;
  unwrapped_angleA = angleDeg; unwrapped_angleB = -angleDegb;
  angleDegPrev  = unwrapped_angleA; angleDegPrevb = unwrapped_angleB;
  deriv_prev  = 0.0f; deriv_prevb = 0.0f;
  derivative  = 0.0; derivativeb = 0.0;
  prev_error = 0.0f;
  pos_totalErrorA = 0.0f;
  prev_posErrorA  = 0.0f;
}

void reset() {
  digitalWrite(RED_LED, LOW);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(GREEN_LED, LOW);
  analogWrite(PWMA, 0);
  analogWrite(PWMB, 0);

  red = false;
  yellow = false;
  green = false;
  lightsOn = false;
  buttonTriggered = false;
  quickRun = false;
  resetFlag = false;
  initialized = false;

  pos_totalErrorA = 0; prev_posErrorA = 0;
  vel_totalErrorA = 0; prev_velErrorA = 0;
  pos_totalErrorB = 0; prev_posErrorB = 0;
  vel_totalErrorB = 0; prev_velErrorB = 0;
  deriv_prev = 0; deriv_prevb = 0;
  previousTime=0;

  t = 0; tb = 0;
  prior_zero = false; prior_zerob = false;

  angleDegPrevRaw = 0; angleDegPrevbRaw = 0;
  angleDegPrev = 0; angleDegPrevb = 0;

  unwrapped_angleA = 0; unwrapped_angleB = 0;

  Serial.println("System reset()");
}

void print(){
  Serial.print("del:");
  Serial.print(deltatime);
  Serial.print(";");
  Serial.print("unwrap:");
  Serial.print(unwrapped_angleA);
  Serial.print(";");
  Serial.print("angle:");
  Serial.print(angleDeg);
  Serial.print(";");
  Serial.print("set:");
  Serial.print(pos_setpoint);
  Serial.print(";");
  Serial.print("der:");
  Serial.print(derivative);
  Serial.print(";");
  Serial.print("vel:");
  Serial.print(vel_setpoint);
  Serial.print(";");
  Serial.print("pwr:");
  Serial.print(pwra);
  Serial.print(";");
  Serial.print(dira);
  Serial.println();
}

void tuning(){
  Serial.print(unwrapped_angleA);
  Serial.print(' ');
  Serial.println(pos_setpoint);
}

void data_analysis_log(){
  Serial.print(deltatime); Serial.print(",");
  Serial.print(unwrapped_angleA); Serial.print(",");
  Serial.print(vel_setpoint); Serial.print(",");   // velocity (commanded)
  Serial.print(pos_setpoint); Serial.print(",");
  Serial.print(pwra); Serial.print(",");
  Serial.println(derivative);                      // derivative (measured velocity)
}


void serial_read(){
  Serial.print(deltatime);
  Serial.print(",");

  Serial.print(angleDeg);
  Serial.print(",");

  Serial.print(unwrapped_angleA);
  Serial.print(",");

  Serial.print(pos_setpoint);
  Serial.print(",");

  Serial.print(derivative);
  Serial.print(",");

  Serial.print(pwra);
  Serial.print(",");

  Serial.println(dira);
}
