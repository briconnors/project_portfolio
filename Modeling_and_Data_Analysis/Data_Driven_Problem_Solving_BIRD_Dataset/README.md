## Data-Driven Problem-Solving:   BIRD Dataset
*I utilized the BIRD experimental FWMAV encoder data to characterize motor tracking quality across dynamic behavior and identify sources of error.*

To evaluate tracking performance beyond idealized step responses, I analyzed two operating controls in series: a wrapped-angle setpoint case used for calibration, and a continuous time-dependent ramp input representing sustained flapping motion at 4 rev/s. As demonstrated by the output, natural delay was introduced by feedback, so a velocity feedforward of 18.7 was identified from a voltage step test and applied to improve system behavior.

After exploring correlations within the dataset between features, I engineered a binary classification to characterize good versus bad motor tracking behavior. Failure was defined by an error threshold of 3 degrees between commanded and measured angular position, producing a highly imbalanced dataset due to the successful tracking of the cascaded position-velocity PID. 

KNN and Logistic models revealed a sharp increase in failure probability beyond 120 motor power, indicating that actuator limitations may be the primary contribution to tracking failure.
