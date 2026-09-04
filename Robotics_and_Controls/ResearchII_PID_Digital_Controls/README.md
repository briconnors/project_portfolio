## Research II:   PID Digital Controls
`Embedded Systems` `Prototyping` `Data Analysis` `Digital Controls` `Experimentation` `C++` `MATLAB` `Python`

*Diagnosed the phase lag in a flapping-wing micro air vehicle and redesigned its sensing and control architecture using high-resolution absolute encoders and cascaded position–velocity control.*

<div align="center">
  <a href="https://docs.google.com/document/d/1ILJsn2BqDa4JZpfOpJrrtF3mizGmHAdJmF_pN2wB2kI/edit?usp=sharing">Research Documentation</a>
  &nbsp; | &nbsp;
  <a href="docs/BIRD_Controller.cpp">Controller Source Code</a>
  &nbsp; | &nbsp;
  <a href="docs/Linkage_Conversion.ipynb">Linkage Conversion Code</a>
</div>

___

### System Overview

The original CU-BIRD flapping wing micro air vehicle has two independent hobbyist plastic-geared motors to allow advanced maneuvers without exceeding strict mass constraints. However, the final model exhibited significant phase lag between wings making flight impossible. After reading the master's thesis, I became interested in investigating the 12-point quadrature encoders and relative velocity PID controller. 


<div align="center">
  <img src="docs/MIT_IEEE_Poster.png" width="750">
  <br>
  <em>Figure 1: Research poster presented at 2025 MIT IEEE Conference.</em>
</div>

___

### Phase-Lag Diagnosis

To isolate the source of the observed phase lag, I developed a video-based tracker of the physical wing motion to compare against the quadrature encoder signal data. 

The script extracted the linkage orientation from 240 fps test footage, and recorded with a ring light/blank poster to minimize shadows. Each frame was cropped and masked to limit irrelevant line interference from the wires and stand. Additional processing included converting to grayscale, and binarizing to isolate the mechanism. Canny edge detection reduced the processed image, preparing the data for a Hough transform to identify straight edged line segments corresponding to the linkage. Through repeated testing, parameters were adjusted to optimize the video data quality.

<br>

<div align="center">
  <img src="docs/MATLAB_Troubleshooting1.png" width="48%">
  <img src="docs/MATLAB_Troubleshooting2.png" width="48%">
  <br>
  <em>Figure 2: MATLAB data processing and troubleshooting during development.</em>
</div>

<br>

To minimize false identification especially along the coupler linkage and shadow, geometric constraints were added to distinguish between the wing and surroundings. Canidate lines (green) were required to originate within a defined radius of a manually selected/calibrated region from the base to the tip at the beginning of the experiment. Short segments were rejected, and angle changes between frames greater than 50 degrees were discarded. The remaining canidate line closest to the stable pivot was selected as the tracked final Hough line (blue) and the angle was extracted with respect to horizontal.

Then, the incremental encoders' serial reads were mapped to the flapping output through linkage geometry in Python and compared to the video data as an absolute reference frame. 

<br>

<div align="center">
  <img src="docs/Python_Results.png" width="48%">
  <br>
  <em>Figure 3: Python linkage conversion. The linkages (crank, coupler, output and fixed frame) are numbered 1-4 respectively.</em>
</div>

<br>

The results emphasized the impact of the low-resolution data introducing the phase lag. Since the original control was a leader-follower system between the wings, with a PID done on relative velocity, regardless of tuning they remained out of sync. Additionally calculations proved that the resolution was much too low to be sufficient for 5 Hz flapping frequency.

<br>

<div align="center">
  <img src="docs/Results_Overlayed.png" width="48%">
  <br>
  <em>Figure 4: Final combined MATLAB extracted visual data with Python encoder data for both wings.</em>
</div>

___

### Controller Redesign

In the original leader–follower architecture, synchronization depended on relative velocity feedback between the two independently driven wings; consequently, insufficient sensing resolution limited the controller's ability to detect and correct phase error. PID retuning alone therefore could not reliably maintain synchronization. Therefore, I restructured the control architecture and designed another circuit using AS5047P absolute encoders with much finer resolution (14-bit). Using a Teensy 4.0 motor controller, I implemented an alternative C++ script.

(RESUME HERE!!!!!!)
___

### Outcomes

Although theoretical modeling in MATLAB control designer predicted stable convergence with only proportional gain on position control, experiments resulted in sustained oscillations due to unmodeled second order effects. Therefore, I added a velocity loop with a low-pass filtering and feedforward to create a cascaded control that reduced steady state error of both motors within +/- 1  degree of the setpoint.
