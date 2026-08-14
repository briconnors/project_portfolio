## Computer-Aided Engineering: Multi-Layer Heat Transfer Model
*I developed a numerical multi-layer heat transfer model to design skewers for cooking a turducken in a 350°F oven, while minimizing surface burning and ensuring all internal layers reached safe temperatures.*

Using Excel, I modeled transient conduction through the turkey, duck, stuffing, and skewer interfaces using material specific thermal properties. The oven was treated as a constant temperature boundary condition, with convective heat transfer at the exposed surfaces. Design constraints required all internal materials to reach 165°F while remaining below 300°F to avoid burning.

I parameterized skewer geometry to minimize cook time. My team worked together to mesh and simulate cooking in ANSYS Workbench given the calculated thermal properties, then compared with the theoretical cook time. The numerical 1D half-model provided a conservative estimate of 7 hours cook time; assuming radially symmetric transfer through each layer, the 3D simulated cook time of 4.25 hours was within reason.
