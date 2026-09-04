## Internship: Battery Fleet Controller
`Embedded Systems` `MQTT` `Fleet Controls` `C++` 

*Worked with a mechanical/electrical team at Loisaida Ecolibrium to design a grid-offset battery system, acting as a Con-Ed non-wired solution to assist the declining NYC power grid.*

<div align="center">
  <a href="https://docs.google.com/document/d/1v4bWwjNDgyZtrkNRwcYOvaFO80NGoXLbTvaOOI4C70U/edit?usp=sharing">Research Documentation</a>
  &nbsp; | &nbsp;
  <a href="docs/Raspberry_Pi_Controller.cpp">Controller Source Code</a>
</div>

## Overview
To reduce demand on the NYC electrical grid during peak periods, we developed the communication and control architecture for coordinating a fleet of Bluetti battery systems. Batteries charge during lower-demand periods and supply connected loads during grid demand peaks, reducing the load drawn from the utility without interrupting operation of the connected equipment.

My work focused on developing the remote supervisory controller layer, while other team members developed the local Python/BLE actuator responsible for direct communication with each battery of the fleet.

## My Contributions

I developed the controller to monitor the network of batteries, evaluate health, report faults, and synchronize scheduling across batteries to the grid demand across the fleet. My group members developed the local BLE Python actuator to decrypt the messages sent from each battery to the app according to Bluetti source code.

During early development, I characterized the communication and switching response of a Sonoff S31 smart plug used as a prototype actuator. I recorded command and response timing across repeated rapid-switching tests, highlighting unsuccessful responses, to evaluate communication latency and reliability before integrating the MQTT control architecture. 

I structured the C++ controller around an MQTT communication layer, receiving battery telemetry through standardized JSON payloads and storing the data for health and state evaluation. The controller evaluates SOC, voltage, current, local load, and the validity of telemetry. Then, the controller determines charge or discharge availability and generates a command. Commands are published back through MQTT to the actuator, with returned device states used to verify successful execution.

The architecture was designed for expansion from an individual battery to multiple units, allowing future scheduling logic to characterize available fleet capacity and coordinate battery response to grid demand.
