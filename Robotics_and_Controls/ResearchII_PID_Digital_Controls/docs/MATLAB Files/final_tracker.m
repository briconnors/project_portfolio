clc; clear all; close all;

%set video, and start & end frame boundaries manually (240=1 sec)
video="IMG_6282.mp4"
starting=1183; %on at 1312, then 1 sec before is -240
ending=6000;

%crop the start and end column pixels of the video if offset from center
crop_start=210;
crop_end=1850;

%set boundary boxes to cover wires/unnecessary edges (in pixels)
right_height=480;
right_width=140;
left_height=400;
left_width=140;

%Hough adjustments based on video lighting 
lighting=0.5;               %how sensitive is binarize to shadows
number_of_peaks=50;         %larger number gives more lines (and noise)
gaps=10;                    %allowed break (in pixels) for it to still be a line
minimum_length=80;          %shortest line allowed to filter noise
threshold_distance = 300;   %[pixels] base is allowed away from basepoint

angles = [];
time=[];

% import video & calibration frame
v=VideoReader(video)

%skips starting frames if there's a frame jump input
for i=1:(starting-1)
    if hasFrame(v)
        readFrame(v);
    end
end

frameNum = starting;
firstframe = readFrame(v);
cropframe = firstframe(:,crop_start:crop_end,:); %dictates what columns of pixels are included
cropframe = cropframe(:, end/2+1:end, :);        % shows only right half of frame 

% getting length of wing in pixels from user input points
figure(1);  
imshow(cropframe);
title('click base 1st, then wingtip 2nd');
[x0, y0] = ginput(1);  
basepoint = [x0, y0];
[x1, y1] = ginput(1);
endpoint = [x1, y1];
L = sqrt((x1 - x0)^2 + (y1 - y0)^2);

%analyze video within set frame bounds
while hasFrame(v) && frameNum <= ending
    frame = readFrame(v);
    crop = frame(:,crop_start:crop_end,:);
    crop = crop(:, end/2+1:end, :);     % choose right half, left is (:, 1:end/2, :)
    crop(end-right_height:end, 1:right_width, :) = 255;   % white box (bottom,left)
    
    %convert image to useable form
    gray = rgb2gray(crop);
    BW = imbinarize(gray, lighting);

    % Hough transform to find straight lines found in frame
    edges = edge(BW, 'Canny');
    [H, theta, rho] = hough(edges);
    P = houghpeaks(H, number_of_peaks);
    lines = houghlines(edges, theta, rho, P, 'FillGap',gaps, 'MinLength',minimum_length);

    % constraining/picking best hough
    figure(1); clf; imshow(crop); hold on;

    fprintf('--- frame %d ---\n', frameNum);
    fprintf('number of lines detected: %d\n', length(lines));

    min_dist = inf;
    chosen_line = [];
    best_tip = [];
    best_base = [];

    %for every hough identified, take those points and draw a line between
    for k = 1:length(lines)
        p1 = lines(k).point1;
        p2 = lines(k).point2;
        plot([p1(1), p2(1)], [p1(2), p2(2)], 'LineWidth', 2, 'Color', 'green');

        % define hough base near basepoint defined by user, tip farther
        if norm(p1 - basepoint) < norm(p2 - basepoint)
            base = p1;
            tip = p2;
        else
            base = p2;
            tip = p1;
        end
        
        %create circular boundary around the basepoint where hough is
        %allowed to originate from
        if norm(base - basepoint) > threshold_distance %if too far away skip it and go to next
            continue;
        end
        
       %if it's close enough to the defined origin get that angle
        dx = tip(1) - base(1);
        dy = -(tip(2) - base(2));
        line_angle = (atan2(dy, dx));
        line_angle_deg=rad2deg(line_angle); %add +90 conversion to same vertical ref like logan's code otherwise wrt horizontal


        % check for angle jumps 
        if ~isempty(angles)
            last_angle = angles(end);
            angle_diff = abs(line_angle_deg - last_angle);
            if abs(angle_diff) > 50
                fprintf('    skipped due to angle jump.\n');
                continue;
            end
        end

        dist=norm(base-basepoint);
        
        %choose the Hough closest in size to the real length (filters out
        %noise and smaller lines)
        if dist < min_dist
            min_dist = dist;
            chosen_line = lines(k);
            best_tip = tip;
            best_base = base;

            best_x_extended = [best_base(1), best_tip(1)];
            best_y_extended = [best_base(2), best_tip(2)];
            best_angle_deg = line_angle_deg;
        end
    end
    
    %draws the best line in blue and stores it
    if ~isempty(chosen_line)
    plot(best_x_extended, best_y_extended, 'c-', 'LineWidth', 2);
    fprintf('chosen angle: %.2f\n', best_angle_deg);
    %makes the graph continuous even if no Hough & angle are found 
    else
        fprintf('no valid line, repeating last angle.\n');
        if ~isempty(angles)
            best_angle_deg = angles(end);     % repeat last valid angle
        else
            best_angle_deg = NaN;             % first frame fallback
        end
    end
    angles = [angles; best_angle_deg];  % always add an angle to avoid jumps

% forcing the screen to show houghs and values that should update once per frame
    drawnow;
    %pause(0.01);
    time = [time; ((frameNum-starting) / 240)*1000]; %convert frames to ms (adjusted to encoder boundaries)
    frameNum = frameNum + 1;
end


% repeat everything for left side but flipped
angles_left = [];
time_left = [];

v=VideoReader(video)

%skip beginning frames to match encoder
for i=1:(starting-1)
    if hasFrame(v)
        readFrame(v);
    end
end
frameNum=starting;

firstframe = readFrame(v);
cropframe_left = firstframe(:, crop_start:crop_end, :);
cropframe_left = cropframe_left(:, 1:end/2, :); % left half of frame
cropframe_left = fliplr(cropframe_left);        % flip for same processing

% getting length of wing in pixels
figure(2);  
imshow(cropframe_left);
title('click base 1st, then wingtip 2nd (LEFT SIDE)');
[x0, y0] = ginput(1);  
basepoint_left = [x0, y0];
[x1, y1] = ginput(1);
endpoint_left = [x1, y1];
L_left = sqrt((x1 - x0)^2 + (y1 - y0)^2);

while hasFrame(v) && frameNum <= ending
    frame = readFrame(v);
    crop= frame(:,crop_start:crop_end,:);
    crop = crop(:, 1:end/2, :);        
    crop = fliplr(crop);               % mirror to reuse same logic
    crop(end-left_height:end, 1:left_width, :) = 255;  

    %convert image to useable form
    gray = rgb2gray(crop);
    BW = imbinarize(gray, lighting);

    % Hough transform
    edges = edge(BW, 'Canny');
    [H, theta, rho] = hough(edges);
    P = houghpeaks(H, number_of_peaks);
    lines = houghlines(edges, theta, rho, P, 'FillGap',gaps, 'MinLength',minimum_length);

    % constraining/picking best hough
    figure(2); clf; imshow(crop); hold on;

    fprintf('--- frame %d (LEFT) ---\n', frameNum);
    fprintf('number of lines detected: %d\n', length(lines));

    min_dist = inf;
    chosen_line = [];
    best_tip = [];
    best_base = [];
    
    threshold_distance = 200; %[pixels] allowed away from basepoint

    for k = 1:length(lines)
        p1 = lines(k).point1;
        p2 = lines(k).point2;
        plot([p1(1), p2(1)], [p1(2), p2(2)], 'LineWidth', 2, 'Color', 'green');

        % define hough base near basepoint, tip farther
        if norm(p1 - basepoint_left) < norm(p2 - basepoint_left)
            base = p1;
            tip = p2;
        else
            base = p2;
            tip = p1;
        end
        
        %create circular boundary around the basepoint where hough is
        %allowed to originate from
        if norm(base - basepoint_left) > threshold_distance
            continue;
        end

        dx = tip(1) - base(1);
        dy = -(tip(2) - base(2));
        line_angle = (atan2(dy, dx));
        line_angle_deg=rad2deg(line_angle);

        % check for angle jumps 
        if ~isempty(angles_left)
            last_angle = angles_left(end);
            angle_diff = abs(line_angle_deg - last_angle);
            if abs(angle_diff) > 50
                fprintf('    skipped due to angle jump.\n');
                continue;
            end
        end

        dist=norm(base-basepoint_left);

        if dist < min_dist
            min_dist = dist;
            chosen_line = lines(k);
            best_tip = tip;
            best_base = base;

            best_x_extended = [best_base(1), best_tip(1)];
            best_y_extended = [best_base(2), best_tip(2)];
            best_angle_deg = line_angle_deg;
        end
    end

    %stores the data from the best Hough found, and has a fallback for
    %frames that don't find any lines to keep it continuous
    if ~isempty(chosen_line)
        plot(best_x_extended, best_y_extended, 'c-', 'LineWidth', 2);
        fprintf('chosen angle: %.2f\n', best_angle_deg);
        angles_left = [angles_left; best_angle_deg];
    else
        fprintf('no valid line, repeating last angle.\n');
        if ~isempty(angles_left)
            best_angle_deg = angles_left(end);  % repeat last valid
        else
            best_angle_deg = NaN;              % fallback for first frame
        end
        angles_left = [angles_left; best_angle_deg];
    end


    % forcing the screen to show houghs and values that should update once per frame
    drawnow;
    %pause(0.01);
    time_left = [time_left; ((frameNum-starting) / 240)*1000]; 
    frameNum = frameNum + 1;
end



analyze_encoders2;
