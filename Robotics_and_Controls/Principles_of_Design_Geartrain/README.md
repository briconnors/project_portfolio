## Principles of Design: Geartrain
*Designed and iteratively optimized a geartrain to maximize lifting speed under torque and friction constraints.*

I solved for the ideal gear ratio (~1:3) given that I had to lift a 10 lb weight as fast as possible, using a stepper motor with a max holding torque of 42 oz-in. 

After initial testing, I modified my original 1:3 gear to a compounded arrangement for a 1:9 ratio because friction severely limited its performance. Also, I altered the provided Arduino code to dedicate less processing toward the timing system; it records the total time of the entire process, but only shows that value on the display at the end. 

Despite friction in the bearings and between 3D printed gears, the final mechanism I designed took around 12 seconds to lift the weight a meter.
