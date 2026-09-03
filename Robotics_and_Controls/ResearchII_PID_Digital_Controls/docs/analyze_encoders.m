close all;

%file imports to check or change
date='9_8';
LED=240; %frame where light turns on

right_flap=[date 'flap_output_right.txt'];
left_flap=[date 'flap_output_left.txt'];

%colors for plotting pretty graphs
pink= [0.75, 0.0, 0.45];
blue = [0.0, 0.45, 0.85];
red = [0.85, 0.1, 0.1];
orange = [0.9, 0.45, 0.1];
green= [0.2, 0.6, 0.2];

%final plot of both L and R wings together from TRACKER
figure(1);
plot(time/1000, angles, 'Color',blue, 'DisplayName', 'Right Tracker'); 
hold on;
plot(time_left/1000, angles_left, 'Color', pink, 'DisplayName', 'Left Tracker'); 
line([time(LED)/1000 time(LED)/1000], ylim, 'Color', 'k','LineStyle','-', 'LineWidth', 1, 'DisplayName', 'LED');
plot(real_time_offset/1000, real_angle, 'Color',blue, 'DisplayName','Right Encoder');
plot(real_time_offset_left/1000, real_angle_left, 'Color',pink, 'DisplayName','Left Encoder');
xlabel('Time (seconds)');
ylabel('Angle (degrees)');
title('MATLAB Tracker and Python Conversion Flap Angle Comparison');
xticks(0:1:max(time))
exportgraphics(gca,'myplot.png','Resolution',600) % 600 dpi = poster quality
legend;
grid on;

%troubleshooting
disp(['Video duration (s): ', num2str(v.Duration)]);
disp(['Last timestamp in time: ', num2str(time(end)), ' ms']);
disp(['# of video frames processed: ', num2str(length(time))]);
disp(['Actual FPS from file: ', num2str(v.FrameRate)]);
disp("tracker time range:");
disp(["length(time)=",length(time)]);
disp(["length(angles)=",length(angles)]);

%pull data from Jupyter file for conversion between encoder raw ticks and linkage flap output
data=readmatrix(right_flap, 'FileType','text');
real_time=data(:,1);
real_time_offset=real_time-min(real_time)-1000; %adjust for misaligned beginning
real_angle=data(:,2);
encoder=data(:,3);

data_left=readmatrix(left_flap, 'FileType', 'text');
real_time_left=data_left(:,1);
real_time_offset_left=real_time_left-min(real_time)-1000;
real_angle_left=data_left(:,2);
encoder_left=data_left(:,3);

disp("tracker time boundaries");
disp([min(time), max(time)]);
disp("encoder (absolute) time boundaries");
disp([min(real_time), max(real_time)]);

% ALL raw encoders and flap data together to make sure of L & R
figure(3);
%plot(encodertime_offset, encoderA, displayName="encoder", Color="blue");
hold on
plot(time_left, angles_left, displayName="tracker left", Color="red");
plot(time, angles, displayName="tracker right", Color="magenta");
plot(real_time_offset, encoder, displayName="right encoder", Color="blue");
plot(real_time_offset_left, encoder_left, displayName="left encoder", Color="green");
xlabel('Time (ms)');
ylabel('Angle (deg)');
title('Raw encoder vs Tracker')
legend;

%plot of LEFT wing output versus encoder data
figure(5);
plot(time, angles, 'r-', 'DisplayName', 'Tracker');
hold on;
plot(real_time_offset, real_angle, 'b-', 'DisplayName','Encoder Data');
line([time(LED) time(LED)], ylim, 'Color', 'k','LineStyle','-', 'DisplayName', 'LED'); %for frame 475
%plot(real_time_offset, encoder, displayName="right encoder", Color="magenta");
xlabel('Time (ms)');
ylabel('Angle (degrees)');
title('RIGHT Wing Tracker vs Encoder Output');
legend;
grid on;

%plot of RIGHT wing output versus encoder data
figure(6);
plot(time_left, angles_left, 'r-', 'DisplayName', 'Tracker');
hold on;
plot(real_time_offset_left, real_angle_left, 'b-', 'DisplayName','Encoder Data');
line([time(LED) time(LED)], ylim, 'Color', 'k','LineStyle','-', 'DisplayName', 'LED'); %for frame 475
%plot(real_time_offset_left, encoder_left, displayName="left encoder", Color="magenta");
xlabel('Time (ms)');
ylabel('Angle (degrees)');
title('LEFT Wing Tracker vs Encoder Output');
legend;
grid on;

%sin approx
figure(7);
plot(real_time_offset, encoder, displayName="right encoder", Color="magenta");
hold on;
plot(time, angles, displayName="tracker left", Color="red");
line([time(LED) time(LED)], ylim, 'Color', 'k','LineStyle','-', 'DisplayName', 'LED'); %for frame 475
sinA=25*sin(deg2rad(encoder));
plot(real_time_offset, sinA, displayName="sin approx", Color="blue");
xlabel('Time (ms)');
ylabel('Angle (degrees)');
title('SIN approx Right wing Tracker vs Encoder Raw');
legend show;
grid on;