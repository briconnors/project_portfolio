## Dynamics:   Domino Kinematics
*Analyzed how coupled impacts and inertia produce wave-like dynamic behavior, and validated theoretical kinematics through comparison with experimental video tracker data.*

My team wanted to find the wave propagation speed and map the behavior of a line of dominos falling, so I created the Python script to represent the dynamic equations of motion.  Using Spyder, I modeled a theoretical set of data for the dominos' angular acceleration, velocity, and position based on the torque and moment of inertia using Euler's backward method for differentiation. 

Then, we recorded a set of four dominos falling and I extracted the experimental position data from Tracker, so I could integrate using a forward difference approximation. We used a rubber mat to maximize static friction to prevent slipping at the base, such that the dominos could be approximated as rolling about a pivot. Kinematics were extracted from the position data using Euler's forward method for integration.

Finally, I overlayed the actual data with theoretical predictions to visually compare results. However, the limited amount of tracker data points prevented filtering, and the numerical step-wise approximations amplified noise.
