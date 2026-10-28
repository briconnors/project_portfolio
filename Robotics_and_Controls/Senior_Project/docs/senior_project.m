% parameterized COM, force, and moment balance for prototype constraints(primarily prevent tipping/bending)
% assuming symmetry across the front view, its modeled as 1/2 from side view

% TO DO's:
% - add x com
% - parameterize leg position for moving COM
% - add changing arm position
% - recompute total COM over posture ranges
% - add chair-side FBD and solve design parameters
% - check front/rear and side tipping
% - do bending/stress verification calcs for rough material sizing
% - add front yz fbd

% nice to do's: 
% - copy over all the data from pdf instead of interpolating by percentile
% - add more datasets for young disabled ppl across all ages

% for arrays, min:step:max

% pretty plots formatting
clc; clear; close all;
set(groot,'defaultAxesFontName','Times New Roman')
set(groot,'defaultTextFontName','Times New Roman')
set(groot,'defaultAxesFontSize',12)
set(groot,'defaultLineLineWidth',1.5)
set(groot,'defaultFigureColor','w')
set(groot,'defaultAxesColor','w')

%% PARAMETERIZED GEOMETRY ----------------------------------------------------
l_back_castors  = 0:0.25:20; % inches, adjust larger maybe
l_front_castors = 2:0.25:60; % inches, adjust larger maybe
l_top_guide     = 5;
l_bottom_guide  = 5;
l_guide_space   = 5;
l_seat_back_height = 1.5:0.25:3; % inches

%% CONSTANT/BOUNDED INPUTS -------------------------------------------------
l_cushion = 2:0.25:4; % inches

% body proportions: (from ref. [1] ncsu anthropometric data, both female/male)
% percentiles, 1 = female, 1st; 2= female,99th; 3 = male, 1st; 4 = male,99th

bottom_knee_length          = [20.54 25.99 21.68 27.04]; % inches from back of butt to front of leg (pg 2)
bottom_popliteal_length     = [16.57 21.47 17.37 22.21]; % inches from back of butt to back of leg(pg 3)
elbow_rest_height_sitting   = [6.22 11.12 6.60 11.48]; % inches from bottom of butt to bottom of bent elbow (pg 4)
elbow_center_grip_length    = [11.39 14.64 12.7 15.88]; % inches from back of arm to center of hand of bent elbow (pg 6)
elbow_wrist_length          = [9.03 11.78 10.15 12.93]; % inches from back of arm to base of wrist of bent elbow (pg 7)
forearm_breadth             = [15.52 22.03 17.76 25.70]; % inches across shoulders or forearm to forearm (pg 11)
seated_functional_leg_length = [35.34 44.42 38.15 47.38]; % inches for an outstretched seated leg (pg 15)
hand_breadth                = [2.79 3.49 3.18 3.95]; % inches across palm (pg 16)
hand_length                 = [6.26 8.07 6.80 8.62]; % inches from wrist to fingertips (pg 18)
hip_breadth                 = [11.65 15.75 11.67 15.48]; % inches across hips(pg 19)
knee_height_sitting         = [17.90 22.75 19.55 24.54]; % inches from bottom of feet to knee top (pg 20)
shoulder_height_sitting     = [19.38 24.54 20.68 26.16]; % inches from bottom of butt to top of shoulder (pg 26)
shoulder_elbow_length       = [11.66 14.84 12.94 16.19]; % inches from bottom of elbow to top of shoulder(pg 27)
sitting_height              = [30.50 36.74 32.59 39.03]; % inches from bottom of butt to top of head (pg 29)
vertical_grip_reach_down    = [21.08 27.09 23.26 29.33]; % inches from center of hand to shoulder top, standing for pushing person (pg 37)

% body mass fractions (%): each index refers to population group from ref. [3]
% 1 = female, old (66-74); 2 = female, elderly (75-86); 3 = fale, old(65-75); 4 = fale, elderly (75-85) (approx, ranges vary a bit with obesity)

% average profiles
avg_head      = [6.89 6.67 6.39 6.25];
avg_neck      = [1.40 1.12 1.58 1.55];
avg_trunk     = [45.11 44.33 47.34 46.47];
avg_upper_arm = [2.32 2.41 2.57 2.52];
avg_forearm   = [1.46 1.47 1.70 1.60];
avg_thigh     = [12.74 12.16 10.62 11.09];
avg_shank     = [4.86 4.84 4.20 4.44];

% obese profiles
obese_head      = [5.30 5.27 5.23 5.19];
obese_neck      = [1.43 1.27 1.66 1.56];
obese_trunk     = [46.56 49.58 48.15 50.65];
obese_upper_arm = [2.48 2.50 2.56 2.59];
obese_forearm   = [1.28 1.26 1.56 1.47];
obese_thigh     = [12.68 11.22 11.06 10.36];
obese_shank     = [4.14 3.61 4.09 3.82];

%% CENTER OF MASS ---------------------------------------------------
% convert percentages to fractions
avg_head = avg_head/100;
avg_neck = avg_neck/100;
avg_trunk = avg_trunk/100;
avg_upper_arm = avg_upper_arm/100;
avg_forearm = avg_forearm/100;
avg_thigh = avg_thigh/100;
avg_shank = avg_shank/100;

obese_head = obese_head/100;
obese_neck = obese_neck/100;
obese_trunk = obese_trunk/100;
obese_upper_arm = obese_upper_arm/100;
obese_forearm = obese_forearm/100;
obese_thigh = obese_thigh/100;
obese_shank = obese_shank/100;

% mass fraction interpolation
t = linspace(0,1,20)';

head = avg_head + t*(obese_head-avg_head);
neck = avg_neck + t*(obese_neck-avg_neck);
trunk = avg_trunk + t*(obese_trunk-avg_trunk);
upper_arm = avg_upper_arm + t*(obese_upper_arm-avg_upper_arm);
forearm = avg_forearm + t*(obese_forearm-avg_forearm);
thigh = avg_thigh + t*(obese_thigh-avg_thigh);
shank = avg_shank + t*(obese_shank-avg_shank);

% de leva ref [2] length fractions[female, male] (longitudinal positions / segment length)
com_head      = [0.5894, 0.5976];
com_trunk     = [0.4151, 0.4486];
com_upper_arm = [0.5754, 0.5772];
com_forearm   = [0.4559, 0.4574];
com_hand      = [0.7474, 0.7900];
com_thigh     = [0.3612, 0.4095];
com_shank     = [0.4416, 0.4459];
com_foot      = [0.4014, 0.4415];

% body and parts mass [kg] 
% 1 = old F, 2 = elderly F, 3 = old M, 4 = elderly M

avg_mass   = [65.80 61.17 80.29 78.39]; % kg
obese_mass = [87.78 83.60 102.00 102.10];

body_mass = avg_mass + t*(obese_mass-avg_mass);
m_head = body_mass .* head;
m_neck = body_mass .* neck;
m_trunk = body_mass .* trunk;
m_upper_arm = body_mass .* upper_arm;
m_forearm   = body_mass .* forearm;
m_thigh = body_mass .* thigh;
m_shank     = body_mass .* shank;

mean_head = mean(m_head);
mean_neck = mean(m_neck);
mean_trunk = mean(m_trunk);
mean_forearm = mean(m_forearm);
mean_thigh = mean(m_thigh);
mean_shank = mean(m_shank);
total_mean_mass = mean_head + mean_neck + mean_trunk + 2*mean_forearm + 2*mean_thigh + 2*mean_shank;

fprintf('head mass %.3f\n', mean_head);
fprintf('neck mass %.3f\n', mean_neck);
fprintf('trunk mass %.3f\n', mean_trunk);
fprintf('forearm mass %.3f\n', 2*mean_forearm);
fprintf('thigh mass %.3f\n', 2*mean_thigh);
fprintf('shank mass %.3f\n', 2*mean_shank);
fprintf('total mass %.3f\n', total_mean_mass);

% accounting check for total mass
total_fraction = head + neck + trunk + 2*(upper_arm + forearm + thigh + shank);
fprintf('mass fraction range: %.3f to %.3f\n', min(total_fraction(:)), max(total_fraction(:)));
missing_fraction = 1 - total_fraction;
m_missing = body_mass .* missing_fraction;

% COM location (r_com + c(length_component))
% assuming origin at bottom of back/butt area, +x toward knees, +y upward
% map female/male COM data to the 4 mass-profile columns
sex_index = [1 1 2 2];
c_head = com_head(sex_index);
c_trunk = com_trunk(sex_index);
c_upper_arm = com_upper_arm(sex_index);
c_forearm = com_forearm(sex_index);
c_thigh = com_thigh(sex_index);
c_shank = com_shank(sex_index);
c_hand = com_hand(sex_index);
c_foot = com_foot(sex_index);

% assuming left/right symmetry and upright sitting,
% head, neck, trunk -> half their full mass
% limbs -> one arm and one leg
m_head_half  = m_head/2;
m_neck_half  = m_neck/2;
m_trunk_half = m_trunk/2;
% these already represent one limb
m_upper_arm_half = m_upper_arm;
m_forearm_half  = m_forearm;
m_thigh_half = m_thigh;
m_shank_half = m_shank;

m_body_half = body_mass/2;

%% 2D HALF-BODY GEOMETRY -------------------------------------------
g = linspace(0,1,20)';

% interpolate female and male dimensions separately
interp_dim = @(v) v([1 1 3 3]) + g*(v([2 2 4 4])-v([1 1 3 3]));

% output 1 = old F, 2= elderly F, 3 = old M, 4 = elderly M
% body dimensions [in]
L_bottom_knee     = interp_dim(bottom_knee_length);
L_bottom_popliteal = interp_dim(bottom_popliteal_length);
H_elbow            = interp_dim(elbow_rest_height_sitting);
L_elbow_grip       = interp_dim(elbow_center_grip_length);
L_forearm          = interp_dim(elbow_wrist_length);
L_functional_leg   = interp_dim(seated_functional_leg_length);
L_hand             = interp_dim(hand_length);
H_knee             = interp_dim(knee_height_sitting);
H_shoulder         = interp_dim(shoulder_height_sitting);
L_upper_arm        = interp_dim(shoulder_elbow_length);
H_sitting          = interp_dim(sitting_height);
H_grip_down        = interp_dim(vertical_grip_reach_down);

% JOINT LOCATIONS (seated posture)
% origin: back of butt at seat level, +x forward, +y upward

% hip: reference point at origin, sized to match the datasets
x_hip = zeros(size(L_bottom_knee));
y_hip = zeros(size(L_bottom_knee));

% knee: extended forward from hip, level with seat (approx.)
x_knee = L_bottom_knee;
y_knee = zeros(size(x_knee));

% shoulder: directly above hip (upright torso)
x_shoulder = zeros(size(H_shoulder));
y_shoulder = H_shoulder;

% elbow: arm hanging vertically downward from shoulder
x_elbow = x_shoulder;
y_elbow = y_shoulder - L_upper_arm;

% wrist: forearm continuing vertically downward
x_wrist = x_elbow;
y_wrist = y_elbow - L_forearm;

% ankle/shank: seated position with feet flat on floor
L_shank = H_knee;
x_ankle = x_knee;
y_ankle = y_knee - L_shank;

% c_* arrays are 1x4:
% [old F, elderly F, old M, elderly M] multiplying 20x1 geometry by 1x4 COM data gives 20x4 results

% hip -> knee (thigh)
x_thigh = x_hip + (x_knee - x_hip).*c_thigh;
y_thigh = y_hip + (y_knee - y_hip).*c_thigh;

% shoulder -> elbow (upper arm)
x_upper_arm = x_shoulder + (x_elbow - x_shoulder).*c_upper_arm;
y_upper_arm = y_shoulder + (y_elbow - y_shoulder).*c_upper_arm;

% elbow -> wrist (forearm)
x_forearm = x_elbow + (x_wrist - x_elbow).*c_forearm;
y_forearm = y_elbow + (y_wrist - y_elbow).*c_forearm;

% first-pass: trunk approximately vertical above butt/hip
x_trunk = zeros(20,4);
y_trunk = H_shoulder .* c_trunk;

% estimate head segment height using difference between
% sitting height and shoulder height
L_head_region = H_sitting - H_shoulder;
x_head = zeros(20,4);
y_head = H_shoulder + L_head_region .* c_head;

% no separate longitudinal COM data currently available
% first-pass location between trunk and head
x_neck = zeros(20,4);
y_neck = H_shoulder;

% knee -> ankle (shank)
x_shank = x_knee + (x_ankle - x_knee).*c_shank;
y_shank = y_knee + (y_ankle - y_knee).*c_shank;

m_modeled_half = ...
      m_head_half ...
    + m_neck_half ...
    + m_trunk_half ...
    + m_upper_arm_half ...
    + m_forearm_half ...
    + m_thigh_half ...
    + m_shank_half;

% validation for array sizes and mass accounting
assert(isequal(size(x_shank),size(body_mass)),'Geometry and mass array sizes do not match');
assert(all(missing_fraction(:) >= 0), 'Segment mass fractions exceed total body mass');

x_body_com = ( ...
      m_head_half.* x_head ...
    + m_neck_half.* x_neck ...
    + m_trunk_half.* x_trunk ...
    + m_upper_arm_half.* x_upper_arm ...
    + m_forearm_half.* x_forearm ...
    + m_thigh_half.* x_thigh ...
    + m_shank_half.* x_shank ...
    ) ./ m_modeled_half;

% total half-body y COM
y_body_com = ( ...
      m_head_half.* y_head ...
    + m_neck_half.* y_neck ...
    + m_trunk_half.* y_trunk ...
    + m_upper_arm_half.* y_upper_arm ...
    + m_forearm_half.* y_forearm ...
    + m_thigh_half.* y_thigh ...
    + m_shank_half.* y_shank ...
    ) ./ m_modeled_half;

% GROUPED COM 
% upper body
m_upper_body = m_head_half + m_neck_half + m_trunk_half + m_upper_arm_half + m_forearm_half;
x_upper_body_com = (m_head_half.*x_head + m_neck_half.*x_neck + m_trunk_half.*x_trunk + m_upper_arm_half.*x_upper_arm + ...
    m_forearm_half.*x_forearm) ./ m_upper_body;
y_upper_body_com = (m_head_half.*y_head + m_neck_half.*y_neck + m_trunk_half.*y_trunk + m_upper_arm_half.*y_upper_arm + ...
    m_forearm_half.*y_forearm) ./ m_upper_body;
% legs
m_legs = m_thigh_half + m_shank_half;
x_legs_com = (m_thigh_half.*x_thigh + m_shank_half.*x_shank) ./ m_legs;
y_legs_com = (m_thigh_half.*y_thigh + m_shank_half.*y_shank) ./ m_legs;

%% PLOTS ----------------------------------------

%BODY GEOMETRY CHECK:
figure; hold on
cases = [1 10 20];
names = {'Small','Medium','Large'};
p = 1; % 1=older F, 2=elderly F, 3=older M, 4=elderly M
C = [0.00 0.45 0.74;
     0.85 0.33 0.10;
     0.49 0.18 0.56];
h = gobjects(1,3);

for j = 1:3
    i = cases(j); c = C(j,:);

    h(j) = plot([x_hip(i,p) x_shoulder(i,p)], [y_hip(i,p) y_shoulder(i,p)], 'o-', 'Color',c);
    plot([x_shoulder(i,p) 0], [y_shoulder(i,p) H_sitting(i,p)], 'o-', 'Color',c,'HandleVisibility','off');
    plot([x_shoulder(i,p) x_elbow(i,p) x_wrist(i,p)], [y_shoulder(i,p) y_elbow(i,p) y_wrist(i,p)], 'o-', 'Color',c,'HandleVisibility','off');
    plot([x_hip(i,p) x_knee(i,p) x_ankle(i,p)],[y_hip(i,p) y_knee(i,p) y_ankle(i,p)],'o-', 'Color',c,'HandleVisibility','off');
    names{j} = sprintf('%s', names{j});
end

i = 10;
text(x_hip(i,p)+1,y_hip(i,p)+0.8,'Hip/Bottom')
text(x_knee(i,p)+4,y_knee(i,p)-1,'Knee')
text(x_ankle(i,p)+4,y_ankle(i,p)-0.8,'Ankle')
text(x_shoulder(i,p)+1,y_shoulder(i,p)+0.3,'Shoulder')
text(x_elbow(i,p)+1,y_elbow(i,p)+0.3,'Elbow')
text(x_wrist(i,p)+1,y_wrist(i,p)-0.8,'Wrist')
text(1,H_sitting(i,p),'Top of Head')

xlabel('x (from seat back) [in]')
ylabel('y (from seat cushion) [in]')
title('Parameterized Body Geometry Check')
legend(h,names,'Location','best')
grid on; axis equal; hold off


%COM SUBPLOTS (body portions for leg movement simulation check)
figure

subplot(1,2,1)
plot(x_upper_body_com(:),y_upper_body_com(:),'s')
xlabel('x COM [in]')
ylabel('y COM [in]')
title('Upper Body COM')
grid on; axis equal

subplot(1,2,2)
plot(x_legs_com(:),y_legs_com(:),'^')
xlabel('x COM [in]')
ylabel('y COM [in]')
title('Leg COM')
grid on; axis equal


% COM location by population group
figure
hold on
plot(x_body_com,y_body_com,'o-')

xlabel('x COM (from seat back) [in]')
ylabel('y COM (from seat cushion) [in]')
title('Total Body COM Across Parameterized Cases')
legend('Older Female','Elderly Female','Older Male','Elderly Male','Location','best')
grid on; axis equal

annotation('textbox',[0.28 0.01 0.5 0.04], ...
    'String','Note: Older \approx 66–75 years and Elderly \approx 76–86 years (exact range varies slightly by sex and body category).', ...
    'FitBoxToText','on','EdgeColor','none','HorizontalAlignment','center')

% highlight extreme COM points
x_all = x_body_com(:);
y_all = y_body_com(:);

[x_min,idx_xmin] = min(x_all);
[x_max,idx_xmax] = max(x_all);
[y_min,idx_ymin] = min(y_all);
[y_max,idx_ymax] = max(y_all);

% plot extreme points
plot(x_min, y_all(idx_xmin), 'k^-', 'MarkerSize',8, 'HandleVisibility', 'off')
plot(x_max, y_all(idx_xmax), 'ko-', 'MarkerSize',8, 'HandleVisibility', 'off')
plot(x_all(idx_ymin), y_min, 'ks-', 'MarkerSize',8, 'HandleVisibility', 'off')
plot(x_all(idx_ymax), y_max, 'kd-', 'MarkerSize',8, 'HandleVisibility', 'off')

% label extreme points with manual offsets
text(x_min-0.03, y_all(idx_xmin)+0.08, sprintf('x_{min} = %.2f in',x_min), 'HorizontalAlignment','right','VerticalAlignment','bottom');
text(x_max+0.03, y_all(idx_xmax)-0.02, sprintf('x_{max} = %.2f in',x_max), 'HorizontalAlignment','left', 'VerticalAlignment','middle');
text(x_all(idx_ymin)+0.04, y_min+0.02, sprintf('y_{min} = %.2f in',y_min), 'HorizontalAlignment','left', 'VerticalAlignment','bottom');
text(x_all(idx_ymax)+0.03, y_max-0.03, sprintf('y_{max} = %.2f in',y_max), 'HorizontalAlignment','left', 'VerticalAlignment','top');
hold off

% print com min/max/avg
fprintf('\n2D HALF-BODY SIDE COM\n');
fprintf('Minimum x COM = %.2f in\n',min(x_body_com(:)));
fprintf('Maximum x COM = %.2f in\n',max(x_body_com(:)));
fprintf('Mean x COM = %.2f in\n',mean(x_body_com(:)));
fprintf('Minimum y COM = %.2f in\n',min(y_body_com(:)));
fprintf('Maximum y COM = %.2f in\n',max(y_body_com(:)));
fprintf('Mean y COM = %.2f in\n',mean(y_body_com(:)));

fprintf('\nGROUPED COM RANGES\n');
fprintf('Upper body x = %.2f to %.2f in\n', min(x_upper_body_com(:)), max(x_upper_body_com(:)));
fprintf('Upper body y = %.2f to %.2f in\n', min(y_upper_body_com(:)), max(y_upper_body_com(:)));
fprintf('Leg x = %.2f to %.2f in\n', min(x_legs_com(:)), max(x_legs_com(:)));
fprintf('Leg y = %.2f to %.2f in\n', min(y_legs_com(:)), max(y_legs_com(:)));


%COM(s) + BODY GEOMETRY COMBINED (sitting with legs downward)
cases = [1 10 20]; names = {'Small','Medium','Large'};
groups = {'Older Female','Elderly Female','Older Male','Elderly Male'};
figure; tiledlayout(2,2)
for p = 1:4
    nexttile; hold on
    for j = 1:3
        i = cases(j); c = C(j,:);
        h(j) = plot([x_hip(i,p) x_shoulder(i,p) 0],[y_hip(i,p) y_shoulder(i,p) H_sitting(i,p)],'o-','Color',c);
        plot([x_shoulder(i,p) x_elbow(i,p) x_wrist(i,p)],[y_shoulder(i,p) y_elbow(i,p) y_wrist(i,p)],'o-','Color',c,'HandleVisibility','off');
        plot([x_hip(i,p) x_knee(i,p) x_ankle(i,p)],[y_hip(i,p) y_knee(i,p) y_ankle(i,p)],'o-','Color',c,'HandleVisibility','off');
        plot(x_body_com(i,p),y_body_com(i,p),'x','Color',c,'MarkerSize',11,'LineWidth',2,'HandleVisibility','off');
        labels{j} = sprintf('%s (%.1f kg)',names{j},body_mass(i,p));
    end
    title(groups{p}); legend(h,labels,'Location','best');
    xlabel('x [in]'); ylabel('y [in]'); grid on; axis equal; hold off
end
sgtitle('Body Geometry and Modeled COM by Population')


% KNEE SWING COM PATHS
figure; hold on
p = 1;
th = linspace(0,90,60);

for j = 1:3
    i = cases(j); c = C(j,:);

    % shank COM during rotation
    xs = x_knee(i,p) + c_shank(p)*L_shank(i,p)*sind(th);
    ys = y_knee(i,p) - c_shank(p)*L_shank(i,p)*cosd(th);

    % leg COM
    xl = (m_thigh_half(i,p)*x_thigh(i,p) + m_shank_half(i,p)*xs)/m_legs(i,p);
    yl = (m_thigh_half(i,p)*y_thigh(i,p) + m_shank_half(i,p)*ys)/m_legs(i,p);

    % total modeled body COM
    xb = (m_upper_body(i,p)*x_upper_body_com(i,p) + m_legs(i,p)*xl)/m_modeled_half(i,p);
    yb = (m_upper_body(i,p)*y_upper_body_com(i,p) + m_legs(i,p)*yl)/m_modeled_half(i,p);

    % COM visualization
    plot(x_upper_body_com(i,p),y_upper_body_com(i,p),'s','Color',c,'MarkerFaceColor',c,'HandleVisibility','off');
    plot(xl,yl,'--','Color',c,'HandleVisibility','off');
    plot(xb,yb,'-','Color',c,'LineWidth',2,'DisplayName',names{j});
    plot(xl(1),yl(1),'x',xl(end),yl(end),'x','Color',c,'HandleVisibility','off');
    plot(xb(1),yb(1),'x',xb(end),yb(end),'x','Color',c,'HandleVisibility','off');
end

legend('show'); grid on; axis equal
xlabel('x COM [in]'); ylabel('y COM [in]');
title(['Knee Swing COM: ' groups{p}])
hold off


%% ISOLATED SEAT FBD ------------------------------------------------
g_accel = 9.81;

% full-body grouped masses
m_upper_body_full = 2*m_upper_body;
m_legs_full = 2*m_legs;
x_upper_body_com_full = x_upper_body_com;
x_legs_com_full = x_legs_com;

F_upper_body = m_upper_body_full.*g_accel;
F_legs = m_legs_full.*g_accel;

m_device = 0; % kg
F_device = m_device*g_accel;  % N
x_device_com = 0; % in from seat back

% force balance for y direction of the seat:
F_missing = m_missing.*g_accel; % account for missing percentage of total body mass from proportions
F_lift = F_upper_body + F_legs + F_missing + F_device;

%inches to meters
x_upper_m = x_upper_body_com_full*0.0254;
x_legs_m = x_legs_com_full*0.0254;
x_device_m = x_device_com*0.0254;
l_guide_m = l_guide_space*0.0254;

% moment about the bottom guide:
R_top_guide = (F_upper_body.*x_upper_m + F_legs.*x_legs_m + F_device.*x_device_m)./l_guide_m;
% force balance for x direction of the seat:
R_bottom_guide = R_top_guide;
% total body force check
F_body_total = body_mass.*g_accel;

N_to_lbf = 0.224809;

% force ranges [min, max] in N
upper_range = [min(F_upper_body(:)),max(F_upper_body(:))];
leg_range = [min(F_legs(:)),max(F_legs(:))];
lift_range = [min(F_lift(:)),max(F_lift(:))];
top_range = [min(R_top_guide(:)),max(R_top_guide(:))];
bottom_range = [min(R_bottom_guide(:)),max(R_bottom_guide(:))];
body_range = [min(F_body_total(:)),max(F_body_total(:))];

% corresponding ranges in lbf
upper_lbf = upper_range*N_to_lbf;
leg_lbf = leg_range*N_to_lbf;
lift_lbf = lift_range*N_to_lbf;
top_lbf = top_range*N_to_lbf;
bottom_lbf = bottom_range*N_to_lbf;
body_lbf = body_range*N_to_lbf;

fprintf('\nISOLATED SEAT FBD RESULTS\n');
fprintf('Upper body force = %.1f to %.1f N (%.1f to %.1f lbf)\n',upper_range,upper_lbf);
fprintf('Leg force = %.1f to %.1f N (%.1f to %.1f lbf)\n',leg_range,leg_lbf);
fprintf('Lift force = %.1f to %.1f N (%.1f to %.1f lbf)\n',lift_range,lift_lbf);
fprintf('Top guide reaction = %.1f to %.1f N (%.1f to %.1f lbf)\n',top_range,top_lbf);
fprintf('Bottom guide reaction = %.1f to %.1f N (%.1f to %.1f lbf)\n',bottom_range,bottom_lbf);
fprintf('Total body force check = %.1f to %.1f N (%.1f to %.1f lbf)\n',body_range,body_lbf);

%% ISOLATED SUPPORT FBD ---------------------------------------------
%R_back_castors = 
%R_front_castors = 


%% SOURCES -----------------------------------------------------------
% geometric bodly lengths data across population groups (1st-99th percentile)
% [1] https://multisite.eos.ncsu.edu/www-ergocenter-ncsu-edu/wp-content/uploads/sites/18/2016/06/Anthropometric-Detailed-Data-Tables.pdf

% COM by body part ratio (women and men)
% [2] de Leva P. Adjustments to Zatsiorsky-Seluyanov's segment inertia parameters. J Biomech. 1996 Sep;29(9):1223-30. doi: 10.1016/0021-9290(95)00178-6. PMID: 8872282.

% body part mass ratio (women/men, older/elderly, average/obese)
% [3] https://pmc.ncbi.nlm.nih.gov/articles/PMC2820296/