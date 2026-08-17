
% using the experimental flow rate Q [L/min], gauge pressure P [psi], and 
% tank volume [L] vs fill time (bernouli's to get tank system output/input head)
% also using a geometry based theoretical model with effective K_L for open ball valve setting

clear; clc; close all;

%% data import:
% standard color + marker system
c_12V_pump = [0 0.4470 0.7410];        % blue
c_12V_sys = [0.8500 0.3250 0.0980];    % orange
c_6V_pump = [0.75 0.10 0.75];          % magenta
c_geom_og = [0.4660 0.6740 0.1880];    % light green
c_geom_keff = [0.20 0.50 0.15];        % green
c_geom_keff_6V = [0.00 0.20 0.50];     % dark blue

mk_12V_pump = '^';     % triangle
mk_12V_sys = 's';      % square
mk_6V_pump = 'v';      % upside-down triangle
mk_geom_og = 'o';      % circle
mk_geom_keff = 'p';    % star

% keep old variable names working
c_pump = c_12V_pump;
c_sys_exp = c_12V_sys;
c_sys_th = c_geom_og;
c_sys_cal = c_geom_keff;

% pulling incremental flow rate and pressure data from current/servo controlled data
filename = "M3_data_3.xlsx";
data_all = readtable(filename, "Sheet","ALL_GOOD_DATA2");
data_lowV = readtable(filename, "Sheet","6.8V_DATA","Range","A2:O47");
sheetnames(filename)
height(data_all)
size(data_all)
data_all.Properties.VariableNames'
height(data_lowV)
size(data_lowV)
data_lowV.Properties.VariableNames'

% pulling flow rate and pressure data from flowmeter study
%second_dataset = readtable("M3_flowmeter_study.xlsx");
%second_dataset.Properties.VariableNames'

% split datasets
data_current = data_all(55:101,:);   % current-controlled pump data, fixed servo
data_servo = data_all(1:54,:);    % regular servo-limited data

datasets(1).name = "12V Voltage Restricted";
datasets(1).data = data_current;
datasets(1).type = "current";

datasets(2).name = "12V Servo Restricted";
datasets(2).data = data_servo;
datasets(2).type = "servo_old";

datasets(3).name = "6.8V Servo Restricted";
datasets(3).data = data_lowV;
datasets(3).type = "lowV_new";

% stable parameters:
epsilon = 0;            % [m] plastic surface roughness approx
rho = 998.3;            % [kg/m^3] density of water @ 67 F
mu = 0.0010143;         % [kg/m*s]
g = 9.81;               % [m/s^2]

% instrumental uncertainty assumptions for appendix plots
% edit these if your lab equipment used a different resolution
dP_inst_psi = 0.5;          % [psi] pressure gauge uncertainty estimate
dt_inst_s = 0.5;            % [s] timing uncertainty estimate for each fill interval
dV_tank_inst_L = 0.02;      % [L] tank volume reading uncertainty estimate
dV_interval_inst_L = 0.02;  % [L] interval volume uncertainty estimate

% K_L baseline values:
k_elbow = 1.5;      % 90 deg, threaded
k_union = 0.08;     % threaded union (straight)
k_bend = 1.5;       % 180 return bend, threaded
k_tee_l = 0.9;      % line flow, threaded 
k_tee_b = 2.0;      % branch flow, threaded
k_exit = 1;         % sudden expansion

% processing both datasets together without recopying the script
for dataset_num = 1:length(datasets)

    data = datasets(dataset_num).data;
    dataset_type = datasets(dataset_num).type;

    disp(datasets(dataset_num).name)

    %disp(data(:,{'Time20','Time40','Time60','Time80','Time100'}))

    % setting variables to the rows of excel
    flowmeter_data = data.Flowmeter_mA_;
    
    if dataset_type == "current"
        pump_current_data = data.PumpCurrent_A_;
        pump_voltage_data = data.PumpVoltage_V_;
        servo_mA_data = nan(height(data),1);
    
    elseif dataset_type == "servo_old"
        pump_current_data = nan(height(data),1);
        pump_voltage_data = data.PumpVoltage_V_;
        servo_mA_data = data.PumpCurrent_A_; 
        % old sheet reused PumpCurrent_A_ as servo mA
    
    elseif dataset_type == "lowV_new"
        pump_current_data = data.PumpCurrent_A_;
        pump_voltage_data = data.PumpVoltage_V_;
        servo_mA_data = data.servoPosition_mA_;
    end

    t_0_20 = data.Time20; % [s]
    t_20_40 = data.Time40;
    t_40_60 = data.Time60;
    t_60_80 = data.Time80;
    t_80_100 = data.Time100;
    T_data = [t_0_20;t_20_40;t_40_60;t_60_80;t_80_100];


    P_0_20 = data.Pressure20_psi_; % [psi]
    P_20_40 = data.Pressure40_psi_;
    P_40_60 = data.Pressure60_psi_;
    P_60_80 = data.Pressure80_psi_;
    P_80_100 = data.Pressure100_psi_;
    P_data = [P_0_20;P_20_40;P_40_60;P_60_80;P_80_100];
    P_avg_trial = mean([P_0_20,P_20_40,P_40_60,P_60_80,P_80_100],2,'omitnan');

    V_tank = 2.74; %[L] Volume of the 100 marker on the upper tank
    dV = 0.20*V_tank; % volume increments 
    Q_0_20   = dV./t_0_20*60; % [L/min]
    Q_20_40  = dV./t_20_40*60;
    Q_40_60  = dV./t_40_60*60;
    Q_60_80  = dV./t_60_80*60;
    Q_80_100 = dV./t_80_100*60;
    Q_data = [Q_0_20;Q_20_40;Q_40_60;Q_60_80;Q_80_100];
    fprintf('f%.2',Q_data,T_data)
    
    % plotting averages
    t_total = t_0_20 + t_20_40 + t_40_60 + t_60_80 + t_80_100;
    Q_avg_trial = V_tank./t_total*60;   % [L/min]
    Q_avg_trial = Q_avg_trial(:);       % force it to be column vector

    % instrumental uncertainty for raw/average flow and pressure points
    Q_inst_err = Q_data.*sqrt((dV_interval_inst_L/dV).^2 + (dt_inst_s./T_data).^2);
    t_total_inst_err = sqrt(5)*dt_inst_s;
    Q_avg_inst_err = Q_avg_trial.*sqrt((dV_tank_inst_L/V_tank).^2 + (t_total_inst_err./t_total).^2);
    P_inst_err = dP_inst_psi*ones(size(P_data));
    P_avg_inst_err = (dP_inst_psi/sqrt(5))*ones(size(P_avg_trial));

    % generate percentage matrix for tank filling comparison plot
    fill_percent_data = [20*ones(size(Q_0_20));
                         40*ones(size(Q_20_40));
                         60*ones(size(Q_40_60));
                         80*ones(size(Q_60_80));
                         100*ones(size(Q_80_100))];

    % upper tank free-surface height for each fill interval
    % assumes 17 in is the 100% fill height measured from the gauge datum
    % edit z_4_0 if the 0% fill mark is above/below the gauge datum
    z_4_0 = 0/39.37;      % [m] top tank free-surface height at 0% fill
    z_4_100 = 17/39.37;   % [m] top tank free-surface height at 100% fill
    fill_frac_vec = [0.20;0.40;0.60;0.80;1.00];
    z_4_by_fill = z_4_0 + fill_frac_vec*(z_4_100-z_4_0);

    % outer loop for each flow rate point:
    n_trials = height(data);
    n = length(Q_data);

    h_pump = zeros(n,1);
    h_sys = zeros(n,1);
    h_sys_exp = zeros(n,1);
    h_sys_geom = zeros(n,1);

    % initial plots
    P_plot = [P_0_20, P_20_40, P_40_60, P_60_80, P_80_100];
    P_avg_trial = P_avg_trial(:);
    
    if dataset_type == "current"
        x_data = pump_current_data;
        x_label = 'Pump Current [A]';
        plot_title = '3-12V Voltage-Restricted Data: Raw Pressure vs Pump Current';
    
    elseif dataset_type == "servo_old"
        x_data = (servo_mA_data-6.7)/(19.9-6.7)*100;
        x_label = 'Servo Position [%]';
        plot_title = '12 V Servo-Restricted Data: Raw Pressure vs Servo Position';
    
    elseif dataset_type == "lowV_new"
        x_data = (servo_mA_data-6.7)/(19.9-6.7)*100;
        x_label = 'Servo Position [%]';
        plot_title = '6.8 V Servo-Restricted Data: Raw Pressure vs Servo Position';
    end
    
    x_data = x_data(:);
    
    pressure_row = {'Pressure 20','Pressure 40','Pressure 60','Pressure 80','Pressure 100'};

    Re_names={'ReAB','ReBC','ReCD','ReDE','ReEF','ReFG','ReGH','ReHK','ReGI','ReIJ','ReJK','ReKL','ReOP','RePQ','ReQR','ReRS'};
    Re_all=nan(n,length(Re_names));

    for i = 1:n                      % loop thru all data points

        Q_tank = Q_data(i);          % [L/min] pull from data
        P_gauge = P_data(i);

        trial_idx = mod(i-1,n_trials)+1;
        fill_idx = ceil(i/n_trials); % 1=20%, 2=40%, ..., 5=100%
        Q_flowmeter_mA = flowmeter_data(trial_idx);
        Q_flowmeter = (Q_flowmeter_mA-8.3)/(29.4-8.3)*6.475667; % [L/min]
        Q_parallel = Q_tank-Q_flowmeter; % pulse flow sensor split flow top section

        servo_mA = servo_mA_data(trial_idx);
        servo_percent = (servo_mA-6.7)/(19.9-6.7);

        %% PUMP SIDE:
        % GAUGE to BOTTOM TANK FREE SURFACE (points 1 -> 2)
        D_AB = 12.35e-3; % [m] diameter of larger pipe inlet
        D_BC = 10e-3;    % [m] outlet smaller main pipe diam

        L_BC = (6+1.75)/39.37;  % large tube length estimate
        L_AB = 20.5/39.37-L_BC; % [m] length of pipe

        z_2 = 4/39.37;  % [m] estimate
        z_1 = 0;        % [m] gauge reference

        Q = Q_tank*1e-3/60; % L/min -> m^3/s
        P_1 = P_gauge*6894.76; % psi -> Pa

        % accounting for head loss major and minor contributions:
        k_contract = 1.35;  % loss coefficient for contraction
        k_entrance = 0.5;   % rough estimate for large reservoir to pump inlet

        h_L_entrance = minor_loss(k_entrance,Q,D_AB,g);
        h_L_bend = minor_loss(k_bend,Q,D_AB,g);
        h_L_contract = minor_loss(k_contract,Q,D_BC,g);

        % A -> B (pump to area change)
        [ReAB,fAB,h_L_majAB] = major_loss(rho,mu,epsilon,Q,D_AB,L_AB,g);

        % B -> C (area change to pressure gauge)
        [ReBC,fBC,h_L_majBC] = major_loss(rho,mu,epsilon,Q,D_BC,L_BC,g);

        % pump head calculation:
        h_L12 = h_L_majAB+h_L_majBC+h_L_entrance+h_L_bend+h_L_contract;
        h_pump(i) = P_1/(rho*g)+8*Q^2/(pi^2*D_BC^4*g)+(z_1-z_2)+h_L12;

        %% SYSTEM SIDE:
        % GAUGE to TOP TANK FREE SURFACE (points 2 -> 4)
        D_main = 10e-3;    % [m] pipe diameter
        D_rotameter = 0.25/39.37; % estimate from datasheet
        % D_ball_valve1 = 0.5/39.37; % measured entrance diameter
        % D_ball_valve2 = 4e-3; %from diagram

        % lengths of each pipe the flow goes through [inches -> m]
        L_CD = ((18.5-4.75)+(1.051*2)+((12-8.75)/2))/39.37;
        L_rotameter = 8.75/39.37;
        L_DE = 8.75/39.37;
        L_EF = 1.650/39.37;
        L_FG = 1.650/39.37;
        L_GH = (7.63/2)/39.37;
        L_HK = L_GH;
        L_flowmeter = 89e-3;
        L_GI = 1.789/39.37+((7.630/2)/39.37-L_flowmeter);
        L_JK = L_GI;
        % L_ball_valve1 = 1.2e-3; %from diagram
        % L_ball_valve2 = 1.1e-3-2*L_ball_valve1;%from diagarm
        L_KL = (1.051*2)/39.37;
        L_OP = (3.743 + (17.5/2))/39.37;
        L_PQ = ((17.5/2)+3.489+(5.694/2))/39.37;
        L_QR = ((5.694/2)+2.296+7.25)/39.37;
        L_RS = 6.75/39.37;
        z_4 = z_4_by_fill(fill_idx); % top tank free surface height for this fill interval

        % C -> D (pump to area change/height change through 90 deg elbow)
        [ReCD,fCD,h_L_majCD] = major_loss(rho,mu,epsilon,Q,D_main,L_CD,g);
        h_L_elbow1 = minor_loss(k_elbow,Q,D_main,g);

        % D -> E (flow meter area change/height change)
        [ReDE,fDE,h_L_majDE] = major_loss(rho,mu,epsilon,Q,D_rotameter,L_rotameter,g);
        k_contract_rot = 1.35;  % contraction from 10 mm -> 1/4 in estimate
        k_expand_rot = (1-(D_rotameter^2/D_main^2))^2;
        dP_rot = 25*100;           % [Pa] 25 mbar
        h_L_rot = dP_rot/(rho*g);  % [m] rotameter head estimate
        h_L_contract_rot = minor_loss(k_contract_rot,Q,D_rotameter,g);
        h_L_expand_rot = minor_loss(k_expand_rot,Q,D_rotameter,g);

        % E -> F (height change)
        [ReEF,fEF,h_L_majEF] = major_loss(rho,mu,epsilon,Q,D_main,L_EF,g);

        % F -> G (height change and 180 bend)
        [ReFG,fFG,h_L_majFG] = major_loss(rho,mu,epsilon,Q,D_main,L_FG,g);
        h_L_bend2 = minor_loss(k_bend,Q,D_main,g);

        % SPLIT FLOW:
        % G -> H (split flow, above rotameter)
        Q_split = Q_parallel*1e-3/60; % L/min -> m^3/s
        [ReGH,fGH,h_L_majGH] = major_loss(rho,mu,epsilon,Q_split,D_main,L_GH,g);
        h_L_tee_branch = minor_loss(k_tee_b,Q_split,D_main,g);

        % H -> K (from split flow rejoining main)
        [ReHK,fHK,h_L_majHK] = major_loss(rho,mu,epsilon,Q_split,D_main,L_HK,g);
        h_L_tee_branch2 = minor_loss(k_tee_b,Q_split,D_main,g);

        h_L_split = h_L_majGH+h_L_majHK+h_L_tee_branch+h_L_tee_branch2;

        % G -> I (split flow, up to flowmeter)
        Q_flow = Q_flowmeter*1e-3/60; % L/min -> m^3/s
        [ReGI,fGI,h_L_majGI] = major_loss(rho,mu,epsilon,Q_flow,D_main,L_GI,g);
        h_L_tee_line = minor_loss(k_tee_l,Q_flow,D_main,g);
        h_L_elbow2 = minor_loss(k_elbow,Q_flow,D_main,g);

        % I -> J (through flowmeter, area change)
        [ReIJ,fIJ,h_L_majIJ] = major_loss(rho,mu,epsilon,Q_flow,D_main,L_flowmeter,g);
        h_L_elbow3 = minor_loss(k_elbow,Q_flow,D_main,g);

        % J -> K (from flowmeter outlet area change to parallel flow rejoin)
        [ReJK,fJK,h_L_majJK] = major_loss(rho,mu,epsilon,Q_flow,D_main,L_JK,g);
        h_L_tee_line2 = minor_loss(k_tee_l,Q_flow,D_main,g);
        
        h_L_flowmeter = h_L_majGI+h_L_majIJ+h_L_majJK ...
              + h_L_tee_line+h_L_tee_line2 ...
              + h_L_elbow2+h_L_elbow3;

        % averaging split section
        h_L_parallel = (h_L_split+h_L_flowmeter)/2;

        % K -> L (recombined flow, up to before area change at ball valve servo)
        [ReKL,fKL,h_L_majKL] = major_loss(rho,mu,epsilon,Q,D_main,L_KL,g);
        h_L_elbow4 = minor_loss(k_elbow,Q,D_main,g);
        
        % L -> M (area decrease at entrance, plus maybe theoretical shift off
        % kL value?)
        % I tried open area change but need the dimensions from the
        % diagram
        % beta = D_ball_valve2/D_ball_valve1;
        % k_contract_ball = 0.5*(1-beta^2)^0.75;
        % k_expand_ball = (1-(D_ball_valve2^2/D_ball_valve1^2))^2;
        % h_L_contract_ball_valve = minor_loss(k_contract_ball,Q,D_ball_valve2,g);
        % h_L_expand_ball_valve = minor_loss(k_expand_ball,Q,D_ball_valve2,g);
        
        % O -> P (two elbows and lengths)
        [ReOP,fOP,h_L_majOP] = major_loss(rho,mu,epsilon,Q,D_main,L_OP,g);
        h_L_elbow5 = minor_loss(k_elbow,Q,D_main,g);
        h_L_elbow6 = minor_loss(k_elbow,Q,D_main,g);
        
        % P -> Q (two elbows and lengths)
        [RePQ,fPQ,h_L_majPQ] = major_loss(rho,mu,epsilon,Q,D_main,L_PQ,g);
        h_L_elbow7 = minor_loss(k_elbow,Q,D_main,g);
        h_L_elbow8 = minor_loss(k_elbow,Q,D_main,g);
        
        % Q -> R (an elbow and 180 deg bend)
        [ReQR,fQR,h_L_majQR] = major_loss(rho,mu,epsilon,Q,D_main,L_QR,g);
        h_L_elbow9 = minor_loss(k_elbow,Q,D_main,g);
        h_L_bend3 = minor_loss(k_bend,Q,D_main,g);
        
        % R -> S (length)
        [ReRS,fRS,h_L_majRS] = major_loss(rho,mu,epsilon,Q,D_main,L_RS,g);
        
        % S -> 4, end of bernouli's top of the tank
        h_L_exit = minor_loss(k_exit,Q,D_main,g);

        % system head calculation:
        h_L13 = h_L_majCD+h_L_elbow1 ...
              + h_L_majDE+h_L_rot+h_L_contract_rot+h_L_expand_rot ...
              + h_L_majEF ...
              + h_L_majFG+h_L_bend2 ...
              + h_L_parallel ...
              + h_L_majKL+h_L_elbow4 ...
              + h_L_majOP+h_L_elbow5+h_L_elbow6 ...
              + h_L_majPQ+h_L_elbow7+h_L_elbow8 ...
              + h_L_majQR+h_L_elbow9+h_L_bend3 ...
              + h_L_majRS;

        h_L34 = h_L_exit;

        % full theoretical system head estimate
        h_sys(i) = h_L12+h_L13+(z_4-z_2)+h_L34;

        % geometry-only theoretical system head, gauge -> top tank
        h_sys_geom(i) = h_L13+(z_4-z_1)+h_L34;

        % experimental system head from gauge pressure, gauge -> top tank
        h_sys_exp(i) = P_1/(rho*g)+8*Q^2/(pi^2*D_main^4*g);
        
        Re_all(i,:)=[ReAB,ReBC,ReCD,ReDE,ReEF,ReFG,ReGH,ReHK,ReGI,ReIJ,ReJK,ReKL,ReOP,RePQ,ReQR,ReRS];
    end
%% Reynold's Analysis
    Re_table=array2table(Re_all,'VariableNames',Re_names);
    fprintf('\nReynolds number table: %s\n',datasets(dataset_num).name)
    disp(Re_table)

[Q_sort,idx_sort]=sort(Q_data);
Re_sort=Re_all(idx_sort,:);

markerList={'o','s','^','v','d','p','h','x','+','*','>','<','.'};
lineStyleList={'-','--',':','-.'};
C=turbo(length(Re_names));

figure
set(gcf,'Position',[100 100 1300 650])
hold on
box on

for j=1:length(Re_names)

    markerNow=markerList{mod(j-1,length(markerList))+1};
    lineNow=lineStyleList{mod(j-1,length(lineStyleList))+1};

    % shifts where markers appear so overlapping curves are still visible
    markerStep=8;
    markerStart=mod(j-1,markerStep)+1;
    markerIdx=markerStart:markerStep:length(Q_sort);

    plot(Q_sort,Re_sort(:,j), ...
        'LineStyle',lineNow, ...
        'Marker',markerNow, ...
        'MarkerIndices',markerIdx, ...
        'Color',C(j,:), ...
        'LineWidth',1.1, ...
        'MarkerSize',6, ...
        'DisplayName',Re_names{j});
end

yline(2300,'k--','LineWidth',1.4,'HandleVisibility','off');
yline(4000,'k-.','LineWidth',1.4,'HandleVisibility','off');

text(max(Q_sort)*0.98,2300,' Laminar limit', ...
    'HorizontalAlignment','right', ...
    'VerticalAlignment','bottom');

text(max(Q_sort)*0.98,4000,' Turbulent limit', ...
    'HorizontalAlignment','right', ...
    'VerticalAlignment','bottom');

xlabel('Flow Rate [L/min]')
ylabel('Reynolds Number')
title('Flow Regime',[char(datasets(dataset_num).name)])
grid on
lgd=legend('Location','eastoutside');
title(lgd,'Pipe Section')
set(gca,'TickDir','out')

    % averages
    h_pump_avg_trial = zeros(n_trials,1);
    h_sys_avg_trial = zeros(n_trials,1);
    h_sys_exp_avg_trial = zeros(n_trials,1);
    h_sys_geom_avg_trial = zeros(n_trials,1);

    for k = 1:n_trials
        idx = k:n_trials:length(Q_data);
        h_pump_avg_trial(k) = mean(h_pump(idx),'omitnan');
        h_sys_avg_trial(k) = mean(h_sys(idx),'omitnan');
        h_sys_exp_avg_trial(k) = mean(h_sys_exp(idx),'omitnan');
        h_sys_geom_avg_trial(k) = mean(h_sys_geom(idx),'omitnan');
    end

    % propagated instrumental uncertainty in head
    % system experimental head uses measured pressure + main-pipe velocity head
    % pump head also includes Q-dependent pump-side losses, so its Q uncertainty
    % is estimated with a local finite-difference sensitivity instead of only V^2/2g
    Q_m3s_inst = Q_data*1e-3/60;
    dQ_m3s_inst = Q_inst_err*1e-3/60;
    dP_head_inst = dP_inst_psi*6894.76/(rho*g);

    h_sys_exp_Q_inst_err = abs(16*Q_m3s_inst./(pi^2*D_main^4*g).*dQ_m3s_inst);
    h_sys_exp_inst_err = sqrt(dP_head_inst.^2 + h_sys_exp_Q_inst_err.^2);

    h_pump_Q_inst_err = nan(size(Q_m3s_inst));
    for q_idx = 1:numel(Q_m3s_inst)
        q_now = Q_m3s_inst(q_idx);
        dq_now = abs(dQ_m3s_inst(q_idx));

        if isfinite(q_now) && isfinite(dq_now)
            q_plus = max(q_now+dq_now,0);
            q_minus = max(q_now-dq_now,0);

            h_plus = pump_q_dependent_head(q_plus,rho,mu,epsilon,g,k_bend);
            h_minus = pump_q_dependent_head(q_minus,rho,mu,epsilon,g,k_bend);

            h_pump_Q_inst_err(q_idx) = abs(h_plus-h_minus)/2;
        end
    end

    h_pump_inst_err = sqrt(dP_head_inst.^2 + h_pump_Q_inst_err.^2);

    h_sys_exp_inst_err_avg_trial = nan(n_trials,1);
    h_pump_inst_err_avg_trial = nan(n_trials,1);

    for k = 1:n_trials
        idx = k:n_trials:length(Q_data);

        valid_sys_err = isfinite(h_sys_exp_inst_err(idx));
        if any(valid_sys_err)
            h_sys_exp_inst_err_avg_trial(k) = sqrt(sum(h_sys_exp_inst_err(idx(valid_sys_err)).^2))/sum(valid_sys_err);
        end

        valid_pump_err = isfinite(h_pump_inst_err(idx));
        if any(valid_pump_err)
            h_pump_inst_err_avg_trial(k) = sqrt(sum(h_pump_inst_err(idx(valid_pump_err)).^2))/sum(valid_pump_err);
        end
    end

    % store results into structures
    clear result
    
    result.data = data;
    result.dataset_type = dataset_type;
    
    result.pump_current_data = pump_current_data;
    result.pump_voltage_data = pump_voltage_data;
    result.servo_mA_data = servo_mA_data;
    result.flowmeter_data = flowmeter_data;
    
    result.Q_data = Q_data;
    result.Q_avg_trial = Q_avg_trial;
    result.Q_inst_err = Q_inst_err;
    result.Q_avg_inst_err = Q_avg_inst_err;
    result.P_inst_err = P_inst_err;
    result.P_avg_inst_err = P_avg_inst_err;
    result.fill_percent_data = fill_percent_data;
    
    result.h_pump = h_pump;
    result.h_sys = h_sys;
    result.h_sys_exp = h_sys_exp;
    result.h_sys_geom = h_sys_geom;
    
    result.h_pump_avg_trial = h_pump_avg_trial;
    result.h_sys_avg_trial = h_sys_avg_trial;
    result.h_sys_exp_avg_trial = h_sys_exp_avg_trial;
    result.h_sys_geom_avg_trial = h_sys_geom_avg_trial;
    result.h_pump_inst_err = h_pump_inst_err;
    result.h_sys_exp_inst_err = h_sys_exp_inst_err;
    result.h_pump_inst_err_avg_trial = h_pump_inst_err_avg_trial;
    result.h_sys_exp_inst_err_avg_trial = h_sys_exp_inst_err_avg_trial;
    
    result.n_trials = n_trials;
    result.P_plot = P_plot;
    result.x_data = x_data;
    result.x_label = x_label;
    result.plot_title = plot_title;
    
    if dataset_type == "current"
        current = result;
    elseif dataset_type == "servo_old"
        servo = result;
    elseif dataset_type == "lowV_new"
        lowV = result;
    end
end

whos current servo lowV

%% PRINT 6.8 V EFFECTIVE K TABLE

D_main = 10e-3;
A_main = pi*D_main^2/4;

Q_m3s_lowV = lowV.Q_data*1e-3/60;
V_main_lowV = Q_m3s_lowV./A_main;

h_missing_lowV = lowV.h_sys_exp - lowV.h_sys_geom;
K_missing_lowV = h_missing_lowV ./ (V_main_lowV.^2/(2*g));

K_lowV_avg_trial = zeros(lowV.n_trials,1);

for k = 1:lowV.n_trials
    idx = k:lowV.n_trials:length(lowV.Q_data);
    K_lowV_avg_trial(k) = mean(K_missing_lowV(idx),'omitnan');
end

lowV_servo_percent = (lowV.servo_mA_data-6.7)/(19.9-6.7)*100;

lowV_K_table = table((1:lowV.n_trials)', ...
    lowV.pump_voltage_data, ...
    lowV.pump_current_data, ...
    lowV.servo_mA_data, ...
    lowV_servo_percent, ...
    lowV.Q_avg_trial, ...
    lowV.h_sys_exp_avg_trial, ...
    lowV.h_sys_geom_avg_trial, ...
    K_lowV_avg_trial, ...
    'VariableNames',{'Trial','PumpVoltage_V','PumpCurrent_A','Servo_mA','ServoPercent','Q_avg_Lmin','H_exp_m','H_geom_m','K_eff'});

disp(lowV_K_table)

%% MANUAL 6.8 V CALIBRATED GEOMETRY MODEL

K_lowV_open = 16.3;   % manually selected from open 6.8 V trial/table

D_main = 10e-3;
A_main = pi*D_main^2/4;

V_main_lowV = (lowV.Q_data*1e-3/60)./A_main;

lowV.h_sys_calibrated = lowV.h_sys_geom + K_lowV_open*(V_main_lowV.^2/(2*g));

lowV.h_sys_calibrated_avg_trial = zeros(lowV.n_trials,1);

for k = 1:lowV.n_trials
    idx = k:lowV.n_trials:length(lowV.Q_data);
    lowV.h_sys_calibrated_avg_trial(k) = mean(lowV.h_sys_calibrated(idx),'omitnan');
end

lowV.K_lowV_open = K_lowV_open;

fprintf('\nManual 6.8 V open-valve K used for calibrated geometry = %.2f\n',lowV.K_lowV_open)

%% plotting setup
set(groot,'defaultFigureColor','w')
set(groot,'defaultAxesFontName','Times New Roman')
set(groot,'defaultTextFontName','Times New Roman')
set(groot,'defaultAxesFontSize',14)
set(groot,'defaultTextFontSize',14)
set(groot,'defaultLineLineWidth',1.5)
set(groot,'defaultAxesLineWidth',1.1)
set(groot,'defaultFigureUnits','pixels')
set(groot,'defaultFigurePosition',[100 100 1300 650])
set(groot,'defaultFigurePaperPositionMode','auto')

% consistent plot settings
alpha_int = 0.25;
marker_int = 45;
marker_avg = 130;

% c_pump = [0 0.4470 0.7410];       % pump head,servo limited experimental model blue
% c_sys_exp = [0.8500 0.3250 0.0980]; % system head, current limited experimental orange
% c_sys_th = [0.4940 0.1840 0.5560];  % geometry model, losses purple
% c_sys_cal = [0.4660 0.6740 0.1880]; % calibrated model, losses plus eff K

%% SERVO-LIMITED DATA BASED
data = servo.data;
servo_data = servo.servo_mA_data;
Q_data = servo.Q_data;
Q_avg_trial = servo.Q_avg_trial;
fill_percent_data = servo.fill_percent_data;
h_pump = servo.h_pump;
h_sys = servo.h_sys;
h_pump_avg_trial = servo.h_pump_avg_trial;
h_sys_avg_trial = servo.h_sys_avg_trial;
n_trials = servo.n_trials;
C = turbo(n_trials);

% back-calculate effective servo valve K from missing head loss
D_main = 10e-3;
A_main = pi*D_main^2/4;

Q_m3s = Q_data*1e-3/60;
V_main = Q_m3s./A_main;

h_servo_interval = servo.h_sys_exp - servo.h_sys_geom;

K_servo_interval = h_servo_interval ./ (V_main.^2/(2*g));

K_servo_avg_trial = zeros(n_trials,1);
h_servo_avg_trial = zeros(n_trials,1);

for k = 1:n_trials
    idx = k:n_trials:length(Q_data);

    K_servo_avg_trial(k) = mean(K_servo_interval(idx),'omitnan');
    h_servo_avg_trial(k) = mean(h_servo_interval(idx),'omitnan');
end

servo.K_servo_interval = K_servo_interval;
servo.K_servo_avg_trial = K_servo_avg_trial;
servo.h_servo_interval = h_servo_interval;
servo.h_servo_avg_trial = h_servo_avg_trial;

%% residual/outlier analysis: servo position vs average tank flow
servo_percent = (servo_data-6.7)/(19.9-6.7)*100;
x = servo_percent(:);
y = Q_avg_trial(:);

valid = isfinite(x) & isfinite(y);

% linear regression using transformed input terms
mdl_servo = fitlm(x(valid),y(valid),'quadratic');

yhat = nan(size(y));
yhat(valid) = predict(mdl_servo,x(valid));

[servo_x_line,servo_order] = sort(x(valid));
servo_yhat_line = predict(mdl_servo,servo_x_line);

residuals = y - yhat;

STD = std(residuals(valid),'omitnan');
tol = max(2*STD,0.75);

upperBound = tol;
lowerBound = -tol;

outliers_avg = residuals < -tol;

servoFlowResidualSummary = table(x,y,yhat,residuals, ...
    repmat(upperBound,length(x),1), ...
    repmat(lowerBound,length(x),1), ...
    outliers_avg, ...
    'VariableNames',{'ServoPercent','Q_avg','Q_fit','Residual','UpperBound','LowerBound','Outlier'});

disp(servoFlowResidualSummary)
servo.outliers_avg = outliers_avg;

servo.Q_fit = yhat;
servo.Q_residuals = residuals;
servo.Q_residual_STD = STD;
servo.Q_residual_err = STD*ones(size(y));
servo.Q_residual_tol = tol*ones(size(y));
servo.Q_total_err = sqrt(servo.Q_avg_inst_err.^2 + servo.Q_residual_err.^2);

%% FIGURE 1: interval flow by trial, with average marker
figure
hold on
box on

for k = 1:n_trials
    idx = k:n_trials:length(Q_data);
    servo_percent_k = (servo_data(k)-6.7)/(19.9-6.7)*100;

    scatter(fill_percent_data(idx),Q_data(idx),marker_int,C(k,:), ...
        'filled', ...
        'MarkerFaceAlpha',alpha_int, ...
        'MarkerEdgeAlpha',alpha_int, ...
        'MarkerEdgeColor','k', ...
        'LineWidth',0.5, ...
        'HandleVisibility','off');

errorbar(110,Q_avg_trial(k),servo.Q_avg_inst_err(k), ...
    'LineStyle','none', ...
    'Color',C(k,:), ...
    'LineWidth',1.0, ...
    'CapSize',8, ...
    'HandleVisibility','off');

if outliers_avg(k)
    scatter(110,Q_avg_trial(k),marker_avg,C(k,:), ...
        'x', ...
        'LineWidth',2.2, ...
        'DisplayName',[num2str(servo_percent_k,'%.1f'),'% outlier']);
else
    scatter(110,Q_avg_trial(k),marker_avg,C(k,:), ...
        'p', ...
        'filled', ...
        'MarkerEdgeColor','k', ...
        'LineWidth',0.5, ...
        'DisplayName',[num2str(servo_percent_k,'%.1f'),'%']);
end

end

xlim([15 115])
xticks([20 40 60 80 100 110])
xticklabels({'20','40','60','80','100','Avg'})
xlabel('Tank Fill Level [%]')
ylabel('Interval Flow Rate [L/min]')
title('Interval Flow Rate Across Tank Filling')
grid on
lgd = legend('Location','eastoutside','NumColumns',2);
title(lgd,'Servo Position')
set(gca,'TickDir','out')

%% FIGURE 2: pump head by trial, with faded interval points and average markers
figure
hold on
box on

for k = 1:n_trials
    idx = k:n_trials:length(Q_data);
    servo_percent_k = (servo_data(k)-6.7)/(19.9-6.7)*100;

    scatter(Q_data(idx),h_pump(idx),marker_int,C(k,:),mk_12V_pump, ...
        'filled', ...
        'MarkerFaceAlpha',alpha_int, ...
        'MarkerEdgeAlpha',alpha_int, ...
        'MarkerEdgeColor','k', ...
        'LineWidth',0.5, ...
        'HandleVisibility','off');
 
    errorbar(Q_avg_trial(k),h_pump_avg_trial(k),servo.h_pump_inst_err_avg_trial(k), ...
        'LineStyle','none', ...
        'Color',C(k,:), ...
        'LineWidth',1.0, ...
        'CapSize',8, ...
        'HandleVisibility','off');

    if outliers_avg(k)
        scatter(Q_avg_trial(k),h_pump_avg_trial(k),marker_avg,C(k,:), ...
            'x', ...
            'LineWidth',2.2, ...
            'DisplayName',[num2str(servo_percent_k,'%.1f'),'% (outlier)']);
    else
        scatter(Q_avg_trial(k),h_pump_avg_trial(k),marker_avg,C(k,:),mk_12V_pump, ...
            'p', ...
            'filled', ...
            'MarkerEdgeColor','k', ...
            'LineWidth',0.5, ...
            'DisplayName',[num2str(servo_percent_k,'%.1f'),'%']);
    end
end

xlabel('Interval Tank Flow Rate [L/min]')
ylabel('Pump Head [m]')
title('Pump Head vs Flow Rate')
grid on
lgd = legend('Location','eastoutside','NumColumns',2);
title(lgd,'Servo Position')
set(gca,'TickDir','out')

%% CURRENT DATA BASED
Q_data = current.Q_data;
Q_avg_trial = current.Q_avg_trial;
h_sys_exp = current.h_sys_exp;
h_sys_geom = current.h_sys_geom;
h_sys_exp_avg_trial = current.h_sys_exp_avg_trial;
h_sys_geom_avg_trial = current.h_sys_geom_avg_trial;

n_trials = current.n_trials;
C = turbo(n_trials);

% back-calculate effective missing K from current/voltage data
D_main = 10e-3;
A_main = pi*D_main^2/4;

Q_m3s_current = current.Q_data*1e-3/60;
V_main_current = Q_m3s_current./A_main;

h_missing_current = current.h_sys_exp - current.h_sys_geom;
K_missing_current = h_missing_current ./ (V_main_current.^2/(2*g));

K_missing_avg_trial = zeros(current.n_trials,1);
h_missing_avg_trial = zeros(current.n_trials,1);

for k = 1:current.n_trials
    idx = k:current.n_trials:length(current.Q_data);
    K_missing_avg_trial(k) = mean(K_missing_current(idx),'omitnan');
    h_missing_avg_trial(k) = mean(h_missing_current(idx),'omitnan');
end

current.h_missing = h_missing_current;
current.K_missing = K_missing_current;
current.h_missing_avg_trial = h_missing_avg_trial;
current.K_missing_avg_trial = K_missing_avg_trial;

% calibrated system curve using fully open baseline K
validBaseline = current.Q_avg_trial > 2.0 & current.K_missing_avg_trial > 0;

K_baseline_open = mean(current.K_missing_avg_trial(validBaseline),'omitnan');

h_sys_calibrated_current = current.h_sys_geom + K_baseline_open*(V_main_current.^2/(2*g));

h_sys_calibrated_avg_trial = zeros(current.n_trials,1);

for k = 1:current.n_trials
    idx = k:current.n_trials:length(current.Q_data);
    h_sys_calibrated_avg_trial(k) = mean(h_sys_calibrated_current(idx),'omitnan');
end

current.K_baseline_open = K_baseline_open;
current.h_sys_calibrated = h_sys_calibrated_current;
current.h_sys_calibrated_avg_trial = h_sys_calibrated_avg_trial;
%% KL estimate across flow rate, servo restricted data 
figure
hold on
box on

% faint interval K_eff points behind average markers
x_servo_interval = servo.Q_data;

validIntervalK_servo = isfinite(servo.K_servo_interval) & ...
                       servo.K_servo_interval > 0 & ...
                       isfinite(x_servo_interval);

scatter(x_servo_interval(validIntervalK_servo), ...
    servo.K_servo_interval(validIntervalK_servo), ...
    marker_int,mk_geom_keff, ...
    'filled',...
    'MarkerFaceColor',c_geom_keff,...
    'MarkerEdgeColor',c_geom_keff, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'MarkerFaceAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');
scatter(nan,nan,marker_int,mk_geom_keff, ...
    'filled',...
    'MarkerFaceColor',c_geom_keff,...
    'MarkerEdgeColor',c_geom_keff, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'MarkerFaceAlpha',alpha_int, ...
    'LineWidth',0.8, ...
    'DisplayName','Interval Flowrate K_{eff}');

% mark low-flow / blown-up K points as invalid for estimating representative K
baseValidK_servo = isfinite(servo.K_servo_avg_trial) & ...
                   servo.K_servo_avg_trial > 0 & ...
                   servo.K_servo_avg_trial < 150 & ...
                   servo.Q_avg_trial > 1.5;

% manually exclude only obvious high-K spikes after the valve is mostly open
excludeK_spike = servo.x_data > 50 & servo.K_servo_avg_trial > 35;

% final valid/excluded groups
validK_servo = baseValidK_servo & ~excludeK_spike;

invalidK_servo = isfinite(servo.K_servo_avg_trial) & ...
                 servo.K_servo_avg_trial > 0 & ...
                 ~validK_servo;
% average K_eff points, including nonlinear low-flow region
avgK_servo = isfinite(servo.K_servo_avg_trial) & ...
             servo.K_servo_avg_trial > 0 & ...
             isfinite(servo.Q_avg_trial);

scatter(servo.Q_avg_trial(avgK_servo),servo.K_servo_avg_trial(avgK_servo),90,mk_geom_keff, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_keff, ...
    'LineWidth',1.0, ...
    'DisplayName','Average Flowrate K_{eff}');

% representative K_eff from valid region only
openServoK = validK_servo & servo.x_data > 80;
K_servo_open_rep = median(servo.K_servo_avg_trial(openServoK),'omitnan');

% show flow-rate range used for open-servo representative K_eff
Q_open_range = servo.Q_avg_trial(openServoK);

Q_open_min = min(Q_open_range,[],'omitnan');
Q_open_max = max(Q_open_range,[],'omitnan');

xline(Q_open_min,':', ...
    'Color','k', ...
    'LineWidth',1.2, ...
    'DisplayName','Open-servo estimate range');

xline(Q_open_max,':', ...
    'Color','k', ...
    'LineWidth',1.2, ...
    'HandleVisibility','off');

yline(K_servo_open_rep,'--', ...
    'Color','k', ...
    'LineWidth',1.5, ...
    'DisplayName',sprintf('Open-servo median K_{eff} = %.1f',K_servo_open_rep));

xlabel('Average Flow Rate [L/min]')
title('Back-Calculated Effective Unmodeled Loss Coefficient: Servo-Restricted Data')
ylabel('Effective Unmodeled Loss Coefficient, K_{eff}')
set(gca,'YScale','log')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,{'K_{eff} = (h_{exp}-h_{geom})/(V^2/2g)'});
set(gca,'TickDir','out')
%% FIGURE 5: Back calculated from 100% servo open, voltage controlled
figure
hold on
box on

% interval K points
scatter(current.Q_data,current.K_missing,marker_int,mk_geom_keff, ...
    'filled',...
    'MarkerEdgeColor',c_geom_keff, ...
    'MarkerFaceColor',c_geom_keff,...
    'MarkerFaceAlpha',alpha_int,...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.6, ...
    'HandleVisibility','off');

scatter(nan,nan,marker_int,mk_geom_keff, ...
    'filled',...
    'MarkerEdgeColor',c_geom_keff, ...
    'MarkerFaceColor',c_geom_keff,...
    'MarkerFaceAlpha',alpha_int,...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.8, ...
    'DisplayName','Interval Flowrate K_{eff}');

% average K points
scatter(current.Q_avg_trial,current.K_missing_avg_trial,marker_avg,mk_geom_keff, ...
    'MarkerEdgeColor',c_geom_keff, ...
    'LineWidth',1.0, ...
    'DisplayName','Valid Average Flowrate K_{eff}');

yline(current.K_baseline_open,'--', ...
    'Color','k', ...
    'LineWidth',1.5, ...
    'DisplayName',sprintf('Baseline Open Servo K_{eff} = %.2f',current.K_baseline_open));

xlabel('Average Flow Rate [L/min]')
ylabel('Effective Missing Loss Coefficient, K_{eff}')
title('Back-Calculated Effective Unmodeled Loss Coefficient: Voltage Restricted Data')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,{'K_{eff} = (h_{exp}-h_{geom})/(V^2/2g)'});
set(gca,'TickDir','out')

%% residual/outlier analysis: pump current vs average tank flow
pump_current = current.pump_current_data;
x = pump_current(:);
y = Q_avg_trial(:);

valid = isfinite(x) & isfinite(y);

% linear regression using transformed input terms
mdl_current = fitlm(x(valid),y(valid),'quadratic');

yhat = nan(size(y));
yhat(valid) = predict(mdl_current,x(valid));

[x_line,order] = sort(x(valid));
yhat_line = predict(mdl_current,x_line);

% residual = vertical distance from point to fit curve
residuals = y - yhat;

% standard deviation of residuals gives typical scatter around the fit
STD = std(residuals(valid),'omitnan');

% outlier cutoff
upperBound = 2*STD;
lowerBound = -2*STD;

% average trial points outside +/- 2 STD are outliers
outliers_avg = abs(residuals) > upperBound;

currentFlowResidualSummary = table(x,y,yhat,residuals, ...
    repmat(upperBound,length(x),1), ...
    repmat(lowerBound,length(x),1), ...
    outliers_avg, ...
    'VariableNames',{'PumpCurrent','Q_avg','Q_fit','Residual','UpperBound','LowerBound','Outlier'});

disp(currentFlowResidualSummary)

current.outliers_avg = outliers_avg;

current.Q_fit = yhat;
current.Q_residuals = residuals;
current.Q_residual_STD = STD;
current.Q_residual_err = STD*ones(size(y));
current.Q_residual_tol = upperBound*ones(size(y));
current.Q_total_err = sqrt(current.Q_avg_inst_err.^2 + current.Q_residual_err.^2);

%% LINEARIZED FIT EQUATIONS

% current-restricted system curve: H_sys vs Q^2
Q_sys = current.Q_avg_trial(:);
H_sys_exp = current.h_sys_exp_avg_trial(:);

valid_sys = isfinite(Q_sys) & isfinite(H_sys_exp) & ~current.outliers_avg;

mdl_H_sys = fitlm(Q_sys(valid_sys).^2,H_sys_exp(valid_sys),'linear');

Q_sys_line = linspace(min(Q_sys(valid_sys)),max(Q_sys(valid_sys)),300)';
H_sys_fit = predict(mdl_H_sys,Q_sys_line.^2);

H_sys_fit_avg = nan(size(H_sys_exp));
H_sys_fit_avg(valid_sys) = predict(mdl_H_sys,Q_sys(valid_sys).^2);
current.H_sys_residuals = H_sys_exp - H_sys_fit_avg;
current.H_sys_residual_RMSE = sqrt(mean(current.H_sys_residuals(valid_sys).^2,'omitnan'));
current.H_sys_residual_err = current.H_sys_residual_RMSE*ones(size(H_sys_exp));
current.H_sys_total_err = sqrt(current.h_sys_exp_inst_err_avg_trial.^2 + current.H_sys_residual_err.^2);
current.Q2_avg_inst_err = 2*abs(Q_sys).*current.Q_avg_inst_err;


% servo-restricted pump curve: H_pump vs Q^2
Q_pump = servo.Q_avg_trial(:);
H_pump = servo.h_pump_avg_trial(:);

valid_pump = isfinite(Q_pump) & isfinite(H_pump) & ~servo.outliers_avg;

mdl_H_pump = fitlm(Q_pump(valid_pump).^2,H_pump(valid_pump),'linear');

Q_pump_line = linspace(min(Q_pump(valid_pump)),max(Q_pump(valid_pump)),300)';
H_pump_fit = predict(mdl_H_pump,Q_pump_line.^2);

H_pump_fit_avg = nan(size(H_pump));
H_pump_fit_avg(valid_pump) = predict(mdl_H_pump,Q_pump(valid_pump).^2);
servo.H_pump_residuals = H_pump - H_pump_fit_avg;
servo.H_pump_residual_RMSE = sqrt(mean(servo.H_pump_residuals(valid_pump).^2,'omitnan'));
servo.H_pump_residual_err = servo.H_pump_residual_RMSE*ones(size(H_pump));
servo.H_pump_total_err = sqrt(servo.h_pump_inst_err_avg_trial.^2 + servo.H_pump_residual_err.^2);
servo.Q2_avg_inst_err = 2*abs(Q_pump).*servo.Q_avg_inst_err;


% print fit equations
coef_H_sys = mdl_H_sys.Coefficients.Estimate;
coef_H_pump = mdl_H_pump.Coefficients.Estimate;

lbl_lin_sys = sprintf('System fit: H = %.2f %+ .3fQ^{2}', ...
    coef_H_sys(1),coef_H_sys(2));

lbl_lin_pump = sprintf('Pump fit: H = %.2f %+ .3fQ^{2}', ...
    coef_H_pump(1),coef_H_pump(2));

fprintf('\nLINEARIZED HYDRAULIC FIT EQUATIONS using Q in L/min:\n')
fprintf('Current-restricted system curve: H_sys = %.4f + %.4f Q^2\n',coef_H_sys(1),coef_H_sys(2))
fprintf('Servo-restricted pump curve:    H_pump = %.4f + %.4f Q^2\n',coef_H_pump(1),coef_H_pump(2))

%% Current-restricted system curve linearized: H_sys vs Q^2
figure
hold on
box on

% faint interval system points
current_outlier_interval = repmat(current.outliers_avg,5,1);

valid_sys_interval = isfinite(current.Q_data) & ...
                     isfinite(current.h_sys_exp) & ...
                     ~current_outlier_interval;

scatter(current.Q_data(valid_sys_interval).^2, ...
    current.h_sys_exp(valid_sys_interval), ...
    marker_int,mk_12V_sys, ...
    'filled',...
    'MarkerFaceColor',c_12V_sys, ...
    'MarkerEdgeColor',c_12V_sys, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');
scatter(nan,nan,marker_int,mk_12V_sys, ...
    'filled', ...
    'MarkerFaceColor',c_12V_sys, ...
    'MarkerEdgeColor',c_12V_sys, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.8, ...
    'DisplayName','Interval Flowrate');

errorbar(Q_sys(valid_sys).^2,H_sys_exp(valid_sys),current.H_sys_total_err(valid_sys), ...
    'LineStyle','none', ...
    'Color',c_12V_sys, ...
    'LineWidth',1.0, ...
    'CapSize',7, ...
    'HandleVisibility','off');

scatter(Q_sys(valid_sys).^2,H_sys_exp(valid_sys),marker_avg,mk_12V_sys, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_sys, ...
    'LineWidth',1.3, ...
    'DisplayName','Average Flowrate');

plot(Q_sys_line.^2,H_sys_fit,'-', ...
    'Color',c_12V_sys, ...
    'LineWidth',2.0, ...
    'DisplayName',lbl_lin_sys);

xlabel('Q^2 [(L/min)^2]')
ylabel('System Head [m]')
title('Linearized Voltage-Restricted System Curve')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,'Fit')
set(gca,'TickDir','out')


%% Servo-restricted pump curve linearized: H_pump vs Q^2
figure
hold on
box on

servo_outlier_interval = repmat(servo.outliers_avg,5,1);
valid_pump_interval = isfinite(servo.Q_data) & ...
                      isfinite(servo.h_pump) & ...
                      ~servo_outlier_interval;

scatter(servo.Q_data(valid_pump_interval).^2, ...
    servo.h_pump(valid_pump_interval), ...
    marker_int,mk_12V_pump, ...
    'filled',...
    'MarkerFaceColor',c_12V_pump, ...
    'MarkerEdgeColor',c_12V_pump, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');
scatter(nan,nan,marker_int,mk_12V_pump, ...
    'filled', ...
    'MarkerFaceColor',c_12V_pump, ...
    'MarkerEdgeColor',c_12V_pump, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.8, ...
    'DisplayName','Interval Flowrate');

errorbar(Q_pump(valid_pump).^2,H_pump(valid_pump),servo.H_pump_total_err(valid_pump), ...
    'LineStyle','none', ...
    'Color',c_12V_pump, ...
    'LineWidth',1.0, ...
    'CapSize',7, ...
    'HandleVisibility','off');

scatter(Q_pump(valid_pump).^2,H_pump(valid_pump),marker_avg,mk_12V_pump, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_pump, ...
    'LineWidth',1.3, ...
    'DisplayName','Average Flowrate');

plot(Q_pump_line.^2,H_pump_fit,'-', ...
    'Color',c_12V_pump, ...
    'LineWidth',2.0, ...
    'DisplayName',lbl_lin_pump);

xlabel('Q^2 [(L/min)^2]')
ylabel('Pump Head [m]')
title('Linearized Servo-Restricted Pump Curve')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,'Fit')
set(gca,'TickDir','out')

%% COMBINED PUMP/SYSTEM CURVES: RAW DATA, OUTLIERS, AND LINEARIZED FITS
figure
set(gcf,'Position',[100 100 1200 650])
hold on
box on

% interval-level outlier masks
current_outlier_interval = repmat(current.outliers_avg,5,1);
servo_outlier_interval = repmat(servo.outliers_avg,5,1);

valid_sys_interval = isfinite(current.Q_data) & ...
                     isfinite(current.h_sys_exp) & ...
                     ~current_outlier_interval;

valid_pump_interval = isfinite(servo.Q_data) & ...
                      isfinite(servo.h_pump) & ...
                      ~servo_outlier_interval;

% faint raw interval system data
scatter(current.Q_data(valid_sys_interval),current.h_sys_exp(valid_sys_interval), ...
    marker_int,mk_12V_sys, ...
    'filled',...
    'MarkerFaceColor',c_12V_sys, ...
    'MarkerEdgeColor',c_12V_sys, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');

% faint raw interval pump data
scatter(servo.Q_data(valid_pump_interval),servo.h_pump(valid_pump_interval), ...
    marker_int,mk_12V_pump, ...
    'filled',...
    'MarkerFaceColor',c_12V_pump, ...
    'MarkerEdgeColor',c_12V_pump, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');

% average system points
for k = 1:current.n_trials
    errorbar(current.Q_avg_trial(k),current.h_sys_exp_avg_trial(k),current.H_sys_total_err(k), ...
        'LineStyle','none', ...
        'Color',c_12V_sys, ...
        'LineWidth',1.0, ...
        'CapSize',8, ...
        'HandleVisibility','off');

    if current.outliers_avg(k)
        scatter(current.Q_avg_trial(k),current.h_sys_exp_avg_trial(k),marker_avg,'x', ...
            'MarkerEdgeColor',c_12V_sys, ...
            'LineWidth',2.2, ...
            'HandleVisibility','off');
    else
        scatter(current.Q_avg_trial(k),current.h_sys_exp_avg_trial(k),marker_avg,mk_12V_sys, ...
            'MarkerFaceColor','none', ...
            'MarkerEdgeColor',c_12V_sys, ...
            'LineWidth',1.3, ...
            'HandleVisibility','off');
    end
end

% average pump points
for k = 1:servo.n_trials
    errorbar(servo.Q_avg_trial(k),servo.h_pump_avg_trial(k),servo.H_pump_total_err(k), ...
        'LineStyle','none', ...
        'Color',c_12V_pump, ...
        'LineWidth',1.0, ...
        'CapSize',8, ...
        'HandleVisibility','off');

    if servo.outliers_avg(k)
        scatter(servo.Q_avg_trial(k),servo.h_pump_avg_trial(k),marker_avg,'x', ...
            'MarkerEdgeColor',c_12V_pump, ...
            'LineWidth',2.2, ...
            'HandleVisibility','off');
    else
        scatter(servo.Q_avg_trial(k),servo.h_pump_avg_trial(k),marker_avg,mk_12V_pump, ...
            'MarkerFaceColor','none', ...
            'MarkerEdgeColor',c_12V_pump, ...
            'LineWidth',1.3, ...
            'HandleVisibility','off');
    end
end

% fit curves
plot(Q_sys_line,H_sys_fit,'-', ...
    'Color',c_12V_sys, ...
    'LineWidth',2.2, ...
    'DisplayName',lbl_lin_sys);

plot(Q_pump_line,H_pump_fit,'-', ...
    'Color',c_12V_pump, ...
    'LineWidth',2.2, ...
    'DisplayName',lbl_lin_pump);

% clean legend entries for marker types
scatter(nan,nan,marker_int,mk_12V_sys, ...
    'filled',...
    'MarkerFaceColor',c_12V_sys, ...
    'MarkerEdgeColor',c_12V_sys, ...
    'MarkerFaceAlpha',alpha_int,...
    'MarkerEdgeAlpha',alpha_int,...
    'LineWidth',0.8, ...
    'DisplayName','System (interval)');

scatter(nan,nan,marker_avg,mk_12V_sys, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_sys, ...
    'LineWidth',1.3, ...
    'DisplayName','System (average)');

scatter(nan,nan,marker_int,mk_12V_pump, ...
    'filled',...
    'MarkerFaceColor',c_12V_pump, ...
    'MarkerEdgeColor',c_12V_pump, ...
    'MarkerFaceAlpha',alpha_int,...
    'MarkerEdgeAlpha',alpha_int,...
    'LineWidth',0.8, ...
    'DisplayName','Pump (interval)');

scatter(nan,nan,marker_avg,mk_12V_pump, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_pump, ...
    'LineWidth',1.3, ...
    'DisplayName','Pump (average)');

scatter(nan,nan,marker_avg,'x', ...
    'MarkerEdgeColor','k', ...
    'LineWidth',2.2, ...
    'DisplayName','Excluded (average)');

xlabel('Flow Rate [L/min]')
ylabel('Head [m]')
title('Pump and System Head Comparison with Raw Data, Outliers, and Fits')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,'Curve and Fit')
set(gca,'TickDir','out')

%% COMBINED PLOTS
% raw pressure and flow pltos with outliers

pressure_row = {'Pressure 20','Pressure 40','Pressure 60','Pressure 80','Pressure 100'};

% current raw pressure
figure
set(gcf,'Position',[100 100 1300 650])
hold on
box on

C = turbo(current.n_trials);

for k = 1:current.n_trials
    errorbar(current.x_data(k)*ones(1,5),current.P_plot(k,:),dP_inst_psi*ones(1,5), ...
        'LineStyle','none', ...
        'Marker','o', ...
        'MarkerSize',6, ...
        'MarkerFaceColor',C(k,:), ...
        'MarkerEdgeColor','k', ...
        'Color',C(k,:), ...
        'LineWidth',0.8, ...
        'CapSize',6, ...
        'DisplayName',[num2str(current.x_data(k),'%.2f'),' A']);
end
% plot(x_current_line,P_current_fit,'k-', ...
%     'LineWidth',1.8, ...
%     'DisplayName','Pressure fit');

xlabel(current.x_label)
ylabel('Pressure [psi]')
title(current.plot_title)
grid on
lgd = legend('Location','eastoutside','NumColumns',2);
title(lgd,'Pump Current')
set(gca,'TickDir','out')

%% tank flow vs pump current
figure
set(gcf,'Position',[100 100 1200 650])
hold on
box on

C = turbo(current.n_trials);

for k = 1:current.n_trials
    idx = k:current.n_trials:length(current.Q_data);

    scatter(current.x_data(k)*ones(size(current.Q_data(idx))),current.Q_data(idx),35,C(k,:), ...
        'filled', ...
        'MarkerFaceAlpha',0.25, ...
        'MarkerEdgeAlpha',0.25, ...
        'HandleVisibility','off');

    errorbar(current.x_data(k),current.Q_avg_trial(k),current.Q_avg_inst_err(k), ...
        'LineStyle','none', ...
        'Color',C(k,:), ...
        'LineWidth',1.0, ...
        'CapSize',8, ...
        'HandleVisibility','off');

    if current.outliers_avg(k)
        scatter(current.x_data(k),current.Q_avg_trial(k),90,C(k,:), ...
            'x', ...
            'LineWidth',2.2, ...
            'DisplayName',[num2str(current.x_data(k),'%.2f'),' A (outlier)']);
    else
        scatter(current.x_data(k),current.Q_avg_trial(k),90,C(k,:), ...
            'p', ...
            'filled', ...
            'MarkerEdgeColor','k', ...
            'DisplayName',[num2str(current.x_data(k),'%.2f'),' A']);
    end
end

xlabel(current.x_label)
ylabel('Tank Flow Rate [L/min]')
title(strrep(current.plot_title,'Raw Pressure','Tank Flow Rate'))
grid on
lgd = legend('Location','eastoutside','NumColumns',2);
title(lgd,'Pump Current')
set(gca,'TickDir','out')

%% servo raw pressure
figure
set(gcf,'Position',[100 100 1300 650])
hold on
box on

C = turbo(servo.n_trials);

for k = 1:servo.n_trials
    servo_mA_k = servo.servo_mA_data(k);

    errorbar(servo_mA_k*ones(1,5),servo.P_plot(k,:),dP_inst_psi*ones(1,5), ...
        'LineStyle','none', ...
        'Marker','o', ...
        'MarkerSize',6, ...
        'MarkerFaceColor',C(k,:), ...
        'MarkerEdgeColor','k', ...
        'Color',C(k,:), ...
        'LineWidth',0.8, ...
        'CapSize',6, ...
        'DisplayName',[num2str(servo_mA_k,'%.1f'),' mA']);
end

xlabel('Servo Position [mA]')
ylabel('Pressure [psi]')
title('12 V Servo-Restricted Data: Raw Pressure vs Servo Position')
grid on
lgd = legend('Location','eastoutside','NumColumns',2);
title(lgd,'Servo Position')
set(gca,'TickDir','out')

%% servo tank flow vs servo position
figure
set(gcf,'Position',[100 100 1200 650])
hold on
box on

C = turbo(servo.n_trials);

for k = 1:servo.n_trials
    idx = k:servo.n_trials:length(servo.Q_data);
    servo_mA_k = servo.servo_mA_data(k);

    scatter(servo_mA_k*ones(size(servo.Q_data(idx))),servo.Q_data(idx),35,C(k,:), ...
        'filled', ...
        'MarkerFaceAlpha',0.25, ...
        'MarkerEdgeAlpha',0.25, ...
        'HandleVisibility','off');

    errorbar(servo_mA_k,servo.Q_avg_trial(k),servo.Q_avg_inst_err(k), ...
        'LineStyle','none', ...
        'Color',C(k,:), ...
        'LineWidth',1.0, ...
        'CapSize',8, ...
        'HandleVisibility','off');

    if servo.outliers_avg(k)
        scatter(servo_mA_k,servo.Q_avg_trial(k),90,C(k,:), ...
            'x', ...
            'LineWidth',2.2, ...
            'DisplayName',[num2str(servo_mA_k,'%.1f'),' mA (outlier)']);
    else
        scatter(servo_mA_k,servo.Q_avg_trial(k),90,C(k,:), ...
            'p', ...
            'filled', ...
            'MarkerEdgeColor','k', ...
            'DisplayName',[num2str(servo_mA_k,'%.1f'),' mA']);
    end
end

xlabel('Servo Position [mA]')
ylabel('Tank Flow Rate [L/min]')
title('12 V Servo-Restricted Data: Tank Flow Rate vs Servo Position')
grid on
lgd = legend('Location','eastoutside','NumColumns',2);
title(lgd,'Servo Position')
set(gca,'TickDir','out')

%% 12 V VS 6.8 V PUMP/SYSTEM COMPARISON
% final operating plot: experimental pump/system curves only
% no geometric/Keff estimate on this figure

c_6V_sys = [0.6350 0.0780 0.1840]; % dark red for 6.8V system

% 12 V / reference curves
Q_12V_pump = servo.Q_avg_trial(:);
H_12V_pump = servo.h_pump_avg_trial(:);

Q_12V_sys = current.Q_avg_trial(:);
H_12V_sys = current.h_sys_exp_avg_trial(:);

% 6.8 V curves
Q_6V = lowV.Q_avg_trial(:);
H_6V_pump = lowV.h_pump_avg_trial(:);
H_6V_sys = lowV.h_sys_exp_avg_trial(:);

% valid points
valid_12V_pump = isfinite(Q_12V_pump) & isfinite(H_12V_pump) & ~servo.outliers_avg;
valid_12V_sys = isfinite(Q_12V_sys) & isfinite(H_12V_sys) & ~current.outliers_avg;

valid_6V_pump = isfinite(Q_6V) & isfinite(H_6V_pump);
valid_6V_sys = isfinite(Q_6V) & isfinite(H_6V_sys);

% fit curves as H = a + bQ^2
mdl_12V_pump = fitlm(Q_12V_pump(valid_12V_pump).^2,H_12V_pump(valid_12V_pump),'linear');
mdl_12V_sys = fitlm(Q_12V_sys(valid_12V_sys).^2,H_12V_sys(valid_12V_sys),'linear');

mdl_6V_pump = fitlm(Q_6V(valid_6V_pump).^2,H_6V_pump(valid_6V_pump),'linear');
mdl_6V_sys = fitlm(Q_6V(valid_6V_sys).^2,H_6V_sys(valid_6V_sys),'linear');

% coefficients
a12p = mdl_12V_pump.Coefficients.Estimate(1);
b12p = mdl_12V_pump.Coefficients.Estimate(2);

a12s = mdl_12V_sys.Coefficients.Estimate(1);
b12s = mdl_12V_sys.Coefficients.Estimate(2);

a6p = mdl_6V_pump.Coefficients.Estimate(1);
b6p = mdl_6V_pump.Coefficients.Estimate(2);

a6s = mdl_6V_sys.Coefficients.Estimate(1);
b6s = mdl_6V_sys.Coefficients.Estimate(2);

lbl12p = sprintf('12V pump: H = %.2f %+ .3fQ^{2}',a12p,b12p);
lbl12s = sprintf('3-12V experimental system: H = %.2f %+ .3fQ^{2}',a12s,b12s);

lbl6p = sprintf('6.8V pump: H = %.2f %+ .3fQ^{2}',a6p,b6p);
lbl6s = sprintf('6.8V experimental system: H = %.2f %+ .3fQ^{2}',a6s,b6s);

% intersections using experimental system curves
Q12_int_sq = (a12s-a12p)/(b12p-b12s);
Q6_int_sq = (a6s-a6p)/(b6p-b6s);

Q_max_plot = max([Q_12V_pump(valid_12V_pump); ...
                  Q_12V_sys(valid_12V_sys); ...
                  Q_6V(valid_6V_pump); ...
                  Q_6V(valid_6V_sys)],[],'omitnan');

Q_line = linspace(0,Q_max_plot,350)';

H_12V_pump_line = predict(mdl_12V_pump,Q_line.^2);
H_12V_sys_line = predict(mdl_12V_sys,Q_line.^2);
H_6V_pump_line = predict(mdl_6V_pump,Q_line.^2);
H_6V_sys_line = predict(mdl_6V_sys,Q_line.^2);

H_6V_pump_fit_avg = nan(size(H_6V_pump));
H_6V_pump_fit_avg(valid_6V_pump) = predict(mdl_6V_pump,Q_6V(valid_6V_pump).^2);
lowV.H_pump_residuals = H_6V_pump - H_6V_pump_fit_avg;
lowV.H_pump_residual_RMSE = sqrt(mean(lowV.H_pump_residuals(valid_6V_pump).^2,'omitnan'));
lowV.H_pump_residual_err = lowV.H_pump_residual_RMSE*ones(size(H_6V_pump));
lowV.H_pump_total_err = sqrt(lowV.h_pump_inst_err_avg_trial.^2 + lowV.H_pump_residual_err.^2);

H_6V_sys_fit_avg = nan(size(H_6V_sys));
H_6V_sys_fit_avg(valid_6V_sys) = predict(mdl_6V_sys,Q_6V(valid_6V_sys).^2);
lowV.H_sys_residuals = H_6V_sys - H_6V_sys_fit_avg;
lowV.H_sys_residual_RMSE = sqrt(mean(lowV.H_sys_residuals(valid_6V_sys).^2,'omitnan'));
lowV.H_sys_residual_err = lowV.H_sys_residual_RMSE*ones(size(H_6V_sys));
lowV.H_sys_total_err = sqrt(lowV.h_sys_exp_inst_err_avg_trial.^2 + lowV.H_sys_residual_err.^2);
lowV.Q2_avg_inst_err = 2*abs(Q_6V).*lowV.Q_avg_inst_err;

figure
set(gcf,'Position',[100 100 1200 650])
hold on
box on

% faint interval points
scatter(servo.Q_data,servo.h_pump,28,mk_12V_pump, ...
    'filled', ...
    'MarkerFaceColor',c_12V_pump, ...
    'MarkerEdgeColor',c_12V_pump, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');

scatter(current.Q_data,current.h_sys_exp,28,mk_12V_sys, ...
    'filled', ...
    'MarkerFaceColor',c_12V_sys, ...
    'MarkerEdgeColor',c_12V_sys, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');

scatter(lowV.Q_data,lowV.h_pump,24,mk_6V_pump, ...
    'filled', ...
    'MarkerFaceColor',c_6V_pump, ...
    'MarkerEdgeColor',c_6V_pump, ...
    'MarkerFaceAlpha',alpha_int, ...
    'MarkerEdgeAlpha',alpha_int, ...
    'LineWidth',0.5, ...
    'HandleVisibility','off');

% average points
errorbar(Q_12V_pump(valid_12V_pump),H_12V_pump(valid_12V_pump),servo.H_pump_total_err(valid_12V_pump), ...
    'LineStyle','none', ...
    'Color',c_12V_pump, ...
    'LineWidth',1.0, ...
    'CapSize',7, ...
    'HandleVisibility','off');

scatter(Q_12V_pump(valid_12V_pump),H_12V_pump(valid_12V_pump),70,mk_12V_pump, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_pump, ...
    'LineWidth',0.8, ...
    'DisplayName','12V Pump avg');

errorbar(Q_12V_sys(valid_12V_sys),H_12V_sys(valid_12V_sys),current.H_sys_total_err(valid_12V_sys), ...
    'LineStyle','none', ...
    'Color',c_12V_sys, ...
    'LineWidth',1.0, ...
    'CapSize',7, ...
    'HandleVisibility','off');

scatter(Q_12V_sys(valid_12V_sys),H_12V_sys(valid_12V_sys),70,mk_12V_sys, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_sys, ...
    'LineWidth',0.8, ...
    'DisplayName','3-12V System avg');

errorbar(Q_6V(valid_6V_pump),H_6V_pump(valid_6V_pump),lowV.H_pump_total_err(valid_6V_pump), ...
    'LineStyle','none', ...
    'Color',c_6V_pump, ...
    'LineWidth',1.0, ...
    'CapSize',7, ...
    'HandleVisibility','off');

scatter(Q_6V(valid_6V_pump),H_6V_pump(valid_6V_pump),70,mk_6V_pump, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_6V_pump, ...
    'LineWidth',0.8, ...
    'DisplayName','6.8V Pump avg');

% fit curves
plot(Q_line,H_12V_pump_line,'-', ...
    'Color',c_12V_pump, ...
    'LineWidth',1.5, ...
    'DisplayName',lbl12p);

plot(Q_line,H_12V_sys_line,'-', ...
    'Color',c_12V_sys, ...
    'LineWidth',1.5, ...
    'DisplayName',lbl12s);

plot(Q_line,H_6V_pump_line,'-', ...
    'Color',c_6V_pump, ...
    'LineWidth',1.5, ...
    'DisplayName',lbl6p);

% label intersections only if physically real
if isfinite(Q12_int_sq) && Q12_int_sq > 0
    Q12_int = sqrt(Q12_int_sq);
    H12_int = a12p + b12p*Q12_int^2;

    txt12 = sprintf('12 V intersection\nQ = %.2f L/min\nH = %.2f m',Q12_int,H12_int);
    text(Q12_int-3.0,H12_int+0.15,txt12, ...
        'FontSize',11, ...
        'BackgroundColor','w', ...
        'EdgeColor','k', ...
        'Margin',5);
end

if isfinite(Q6_int_sq) && Q6_int_sq > 0
    Q6_int = 4.40;
    H6_int = a6p + b6p*Q6_int^2;

    txt6 = sprintf('6.8 V intersection\nQ = %.2f L/min\nH = %.2f m',Q6_int,H6_int);
    text(Q6_int+1.8,H6_int+0.3,txt6, ...
        'FontSize',11, ...
        'BackgroundColor','w', ...
        'EdgeColor','k', ...
        'Margin',5);
end

xlabel('Flow Rate [L/min]')
ylabel('Head [m]')
title('12V and 6.8V Experimental Pump/System Comparison')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,'Curve and Fit')
set(gca,'TickDir','out')
xlim([0,Q_max_plot+0.25])

%% SYSTEM-SIDE CURVE ADJUSTMENT COMPARISON
% compares experimental system, unadjusted geometry, and Keff-adjusted geometry

Q_12V_geom = current.Q_avg_trial(:);
H_12V_geom_unadj = current.h_sys_geom_avg_trial(:);
H_12V_geom_adj = current.h_sys_calibrated_avg_trial(:);

Q_6V_geom = lowV.Q_avg_trial(:);
H_6V_geom_unadj = lowV.h_sys_geom_avg_trial(:);
H_6V_geom_adj = lowV.h_sys_calibrated_avg_trial(:);

valid_12V_geom_unadj = isfinite(Q_12V_geom) & isfinite(H_12V_geom_unadj) & ~current.outliers_avg;
valid_12V_geom_adj = isfinite(Q_12V_geom) & isfinite(H_12V_geom_adj) & ~current.outliers_avg;

valid_6V_geom_unadj = isfinite(Q_6V_geom) & isfinite(H_6V_geom_unadj);
valid_6V_geom_adj = isfinite(Q_6V_geom) & isfinite(H_6V_geom_adj);

mdl_12V_geom_unadj = fitlm(Q_12V_geom(valid_12V_geom_unadj).^2,H_12V_geom_unadj(valid_12V_geom_unadj),'linear');
mdl_12V_geom_adj = fitlm(Q_12V_geom(valid_12V_geom_adj).^2,H_12V_geom_adj(valid_12V_geom_adj),'linear');

mdl_6V_geom_unadj = fitlm(Q_6V_geom(valid_6V_geom_unadj).^2,H_6V_geom_unadj(valid_6V_geom_unadj),'linear');
mdl_6V_geom_adj = fitlm(Q_6V_geom(valid_6V_geom_adj).^2,H_6V_geom_adj(valid_6V_geom_adj),'linear');

a12u = mdl_12V_geom_unadj.Coefficients.Estimate(1);
b12u = mdl_12V_geom_unadj.Coefficients.Estimate(2);

a12k = mdl_12V_geom_adj.Coefficients.Estimate(1);
b12k = mdl_12V_geom_adj.Coefficients.Estimate(2);

a6u = mdl_6V_geom_unadj.Coefficients.Estimate(1);
b6u = mdl_6V_geom_unadj.Coefficients.Estimate(2);

a6k = mdl_6V_geom_adj.Coefficients.Estimate(1);
b6k = mdl_6V_geom_adj.Coefficients.Estimate(2);

lbl12u = sprintf('12V geom unadjusted: H = %.2f %+ .3fQ^{2}',a12u,b12u);
lbl12k = sprintf('12V K_{eff} adjusted: H = %.2f %+ .3fQ^{2}',a12k,b12k);

lbl6u = sprintf('6.8V geom unadjusted: H = %.2f %+ .3fQ^{2}',a6u,b6u);
lbl6k = sprintf('6.8V K_{eff} adjusted: H = %.2f %+ .3fQ^{2}',a6k,b6k);

Q_max_sys_plot = max([Q_12V_sys(valid_12V_sys); ...
                      Q_12V_geom(valid_12V_geom_unadj); ...
                      Q_12V_geom(valid_12V_geom_adj); ...
                      Q_6V(valid_6V_sys); ...
                      Q_6V_geom(valid_6V_geom_unadj); ...
                      Q_6V_geom(valid_6V_geom_adj)],[],'omitnan');

Q_sys_line = linspace(0,Q_max_sys_plot,350)';

H_12V_sys_line2 = predict(mdl_12V_sys,Q_sys_line.^2);
H_12V_geom_unadj_line = predict(mdl_12V_geom_unadj,Q_sys_line.^2);
H_12V_geom_adj_line = predict(mdl_12V_geom_adj,Q_sys_line.^2);

H_6V_sys_line2 = predict(mdl_6V_sys,Q_sys_line.^2);
H_6V_geom_unadj_line = predict(mdl_6V_geom_unadj,Q_sys_line.^2);
H_6V_geom_adj_line = predict(mdl_6V_geom_adj,Q_sys_line.^2);

figure
set(gcf,'Position',[100 100 1250 650])
hold on
box on

% average points
scatter(Q_12V_sys(valid_12V_sys),H_12V_sys(valid_12V_sys),90,mk_12V_sys, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_sys, ...
    'LineWidth',1.0, ...
    'DisplayName','3-12V experimental system');

scatter(Q_12V_geom(valid_12V_geom_unadj),H_12V_geom_unadj(valid_12V_geom_unadj),90,mk_geom_og, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_og, ...
    'LineWidth',1.0, ...
    'DisplayName','12V unadjusted geometry');

scatter(Q_12V_geom(valid_12V_geom_adj),H_12V_geom_adj(valid_12V_geom_adj),90,mk_geom_keff, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_keff, ...
    'LineWidth',1.0, ...
    'DisplayName','12V K_{eff}-adjusted geometry');

scatter(Q_6V_geom(valid_6V_geom_unadj),H_6V_geom_unadj(valid_6V_geom_unadj),80,mk_geom_og, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',[0.30 0.75 0.93], ...
    'LineWidth',1.0, ...
    'DisplayName','6.8V unadjusted geometry');

scatter(Q_6V_geom(valid_6V_geom_adj),H_6V_geom_adj(valid_6V_geom_adj),80,mk_geom_keff, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_keff_6V, ...
    'LineWidth',1.0, ...
    'DisplayName','6.8V K_{eff}-adjusted geometry');
% average points only, excluded from legend
scatter(Q_12V_sys(valid_12V_sys),H_12V_sys(valid_12V_sys),70,mk_12V_sys, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_sys, ...
    'LineWidth',0.9, ...
    'HandleVisibility','off');

scatter(Q_12V_geom(valid_12V_geom_unadj),H_12V_geom_unadj(valid_12V_geom_unadj),70,mk_geom_og, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_og, ...
    'LineWidth',0.9, ...
    'HandleVisibility','off');

scatter(Q_12V_geom(valid_12V_geom_adj),H_12V_geom_adj(valid_12V_geom_adj),70,mk_geom_keff, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_keff, ...
    'LineWidth',0.9, ...
    'HandleVisibility','off');

scatter(Q_6V_geom(valid_6V_geom_unadj),H_6V_geom_unadj(valid_6V_geom_unadj),65,mk_geom_og, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',[0.30 0.75 0.93], ...
    'LineWidth',0.9, ...
    'HandleVisibility','off');

scatter(Q_6V_geom(valid_6V_geom_adj),H_6V_geom_adj(valid_6V_geom_adj),65,mk_geom_keff, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_keff_6V, ...
    'LineWidth',0.9, ...
    'HandleVisibility','off');

% fit curves
plot(Q_sys_line,H_12V_sys_line2,'-', ...
    'Color',c_12V_sys, ...
    'LineWidth',1.8, ...
    'DisplayName',lbl12s);

plot(Q_sys_line,H_12V_geom_unadj_line,'-', ...
    'Color',c_geom_og, ...
    'LineWidth',1.8, ...
    'DisplayName',lbl12u);

plot(Q_sys_line,H_12V_geom_adj_line,'-', ...
    'Color',c_geom_keff, ...
    'LineWidth',1.8, ...
    'DisplayName',lbl12k);

plot(Q_sys_line,H_6V_geom_unadj_line,'-', ...
    'Color',[0.30 0.75 0.93], ...
    'LineWidth',1.8, ...
    'DisplayName',lbl6u);

plot(Q_sys_line,H_6V_geom_adj_line,'-', ...
    'Color',c_geom_keff_6V, ...
    'LineWidth',1.8, ...
    'DisplayName',lbl6k);

xlabel('Flow Rate [L/min]')
ylabel('System Head [m]')
title('System-Side Curve Adjustment Comparison')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,'Legend and System Curve Approximations')
set(gca,'TickDir','out')
xlim([0,Q_max_sys_plot+0.25])

% keep old variable names alive for the existing R_summary block
a12g = a12k;
b12g = b12k;
a6g = a6k;
b6g = b6k;

valid_12V_geom = valid_12V_geom_adj;
valid_6V_geom = valid_6V_geom_adj;

H_12V_geom = H_12V_geom_adj;
H_6V_geom = H_6V_geom_adj;

%% SYSTEM-SIDE CURVE COMPARISON WITHOUT K_EFF ADJUSTMENT
% clean plot showing experimental system curves vs unadjusted geometry only

figure
set(gcf,'Position',[100 100 1250 650])
hold on
box on

% average points
scatter(Q_12V_sys(valid_12V_sys),H_12V_sys(valid_12V_sys),90,mk_12V_sys, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_sys, ...
    'LineWidth',1.0, ...
    'DisplayName','3-12V experimental system');

scatter(Q_12V_geom(valid_12V_geom_unadj),H_12V_geom_unadj(valid_12V_geom_unadj),90,mk_geom_og, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_geom_og, ...
    'LineWidth',1.0, ...
    'DisplayName','12V unadjusted geometry');

scatter(Q_6V_geom(valid_6V_geom_unadj),H_6V_geom_unadj(valid_6V_geom_unadj),80,mk_geom_og, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',[0.30 0.75 0.93], ...
    'LineWidth',1.0, ...
    'DisplayName','6.8V unadjusted geometry');

% fit curves
plot(Q_sys_line,H_12V_sys_line2,'-', ...
    'Color',c_12V_sys, ...
    'LineWidth',1.8, ...
    'DisplayName',lbl12s);

plot(Q_sys_line,H_12V_geom_unadj_line,'-', ...
    'Color',c_geom_og, ...
    'LineWidth',1.8, ...
    'DisplayName',lbl12u);

plot(Q_sys_line,H_6V_geom_unadj_line,'-', ...
    'Color',[0.30 0.75 0.93], ...
    'LineWidth',1.8, ...
    'DisplayName',lbl6u);

xlabel('Flow Rate [L/min]')
ylabel('System Head [m]')
title('System-Side Curve Comparison Before K_{eff} Adjustment')
grid on
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,'Unadjusted System Curves')
set(gca,'TickDir','out')
xlim([0,Q_max_sys_plot+0.25])

%% SERVO AS VARIABLE SYSTEM RESISTANCE MODEL
% measured data = markers
% estimated/model curves = dashed lines

D_main = 10e-3;
A_main = pi*D_main^2/4;

% geometry-only system curve fit, used only as baseline estimate
Q_geom = current.Q_avg_trial(:);
H_geom = current.h_sys_geom_avg_trial(:);

valid_geom = isfinite(Q_geom) & isfinite(H_geom) & ~current.outliers_avg;
mdl_geom = fitlm(Q_geom(valid_geom).^2,H_geom(valid_geom),'linear');

% baseline effective K from open-servo current-limited data
K_open = current.K_baseline_open;

% servo-dependent K from servo-restricted data
servo_mA = servo.servo_mA_data(:);
servo_percent = (servo_mA-6.7)/(19.9-6.7)*100;
K_servo_total = servo.K_servo_avg_trial(:);

valid_K_servo = isfinite(servo_mA) & ...
                isfinite(servo_percent) & ...
                isfinite(K_servo_total) & ...
                K_servo_total > 0 & ...
                K_servo_total < 150 & ...
                servo.Q_avg_trial(:) > 1.5;

% keep only extra valve restriction above the open-valve baseline
K_servo_extra = max(K_servo_total - K_open,0);
K_variable = K_open + K_servo_extra;

% choose representative servo positions so plot is readable
target_mA = [8 9 10 12 14 16 18 19.3];

valid_indices = find(valid_K_servo);
selected_idx = nan(size(target_mA));

for j = 1:length(target_mA)
    [~,local_idx] = min(abs(servo_mA(valid_indices)-target_mA(j)));
    selected_idx(j) = valid_indices(local_idx);
end

selected_idx = unique(selected_idx,'stable');

% model flow range
Q_model = linspace(0,max([servo.Q_avg_trial;current.Q_avg_trial],[],'omitnan')+0.5,400)';
V_model = (Q_model*1e-3/60)./A_main;

% estimated curves
H_pump_model = predict(mdl_H_pump,Q_model.^2);
H_geom_model = predict(mdl_geom,Q_model.^2);

figure
set(gcf,'Position',[100 100 1250 650])
hold on
box on

% measured average data points
scatter(servo.Q_avg_trial(valid_pump),servo.h_pump_avg_trial(valid_pump),90,mk_12V_pump, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_pump, ...
    'LineWidth',1.3, ...
    'DisplayName','Measured 12 V pump avg');

scatter(current.Q_avg_trial(valid_sys),current.h_sys_exp_avg_trial(valid_sys),90,mk_12V_sys, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',c_12V_sys, ...
    'LineWidth',1.3, ...
    'DisplayName','Measured open-valve system avg');

% estimated fitted pump and open-valve system curves
plot(Q_model,H_pump_model,'-', ...
    'Color',c_12V_pump, ...
    'LineWidth',2.2, ...
    'DisplayName','12 V pump fit');

plot(Q_model,H_geom_model + K_open*(V_model.^2/(2*g)),'-', ...
    'Color',c_12V_sys, ...
    'LineWidth',2.2, ...
    'DisplayName',sprintf('Open-valve system, K_{eff}=%.1f',K_open));

% estimated servo-restricted system curves
Cvar = turbo(length(selected_idx));

for j = 1:length(selected_idx)

    k_idx = selected_idx(j);
    K_now = K_variable(k_idx);

    H_sys_variable = H_geom_model + K_now*(V_model.^2/(2*g));

    plot(Q_model,H_sys_variable,'--', ...
        'Color',Cvar(j,:), ...
        'LineWidth',1.4, ...
        'DisplayName',sprintf('%.1f mA servo, K_{eff}=%.1f',servo_mA(k_idx),K_now));
end

xlabel('Flow Rate [L/min]')
ylabel('Head [m]')
title('Servo Flow Limiting Modeled as Variable Effective Resistance')
grid on
ylim([0 16])
lgd = legend('Location','eastoutside');
lgd.Interpreter = 'tex';
title(lgd,'Servo Restriction')
set(gca,'TickDir','out')

%% EXPORT R / HEAD-FLOW COEFFICIENT SUMMARY
% For all fits, H = a + R*Q^2
% Q is in L/min, so R has units of m/(L/min)^2
% Pump R values are negative because pump head decreases with flow.

CurveName = [
    "12V pump"
    "3-12V experimental system"
    "12V adjusted-geometry system"
    "6.8V pump"
    "3-6.8V adjusted-geometry system"
];

DataSource = [
    "servo-restricted"
    "voltage-restricted"
    "voltage-restricted geometry"
    "servo-restricted"
    "6.8V servo-restricted geometry"
];

Intercept_a_m = [
    a12p
    a12s
    a12g
    a6p
    a6g
];

R_m_per_Lmin2 = [
    b12p
    b12s
    b12g
    b6p
    b6g
];

N_points = [
    sum(valid_12V_pump)
    sum(valid_12V_sys)
    sum(valid_12V_geom)
    sum(valid_6V_pump)
    sum(valid_6V_geom)
];

Q_min_Lmin = [
    min(Q_12V_pump(valid_12V_pump))
    min(Q_12V_sys(valid_12V_sys))
    min(Q_12V_geom(valid_12V_geom))
    min(Q_6V(valid_6V_pump))
    min(Q_6V(valid_6V_geom))
];

Q_max_Lmin = [
    max(Q_12V_pump(valid_12V_pump))
    max(Q_12V_sys(valid_12V_sys))
    max(Q_12V_geom(valid_12V_geom))
    max(Q_6V(valid_6V_pump))
    max(Q_6V(valid_6V_geom))
];

FitEquation = compose("H = %.4f %+0.4f Q^2",Intercept_a_m,R_m_per_Lmin2);

R_summary = table(CurveName,DataSource,FitEquation,Intercept_a_m,R_m_per_Lmin2, ...
    N_points,Q_min_Lmin,Q_max_Lmin);

disp(R_summary)

writetable(R_summary,"R_coefficient_summary.xlsx","Sheet","R Summary")

%% export all figures
figs = findall(groot,'Type','figure');
figs = flipud(figs); % keeps them closer to creation order

for k = 1:numel(figs)
    exportgraphics(figs(k),sprintf('Figure_%02d.png',k),'Resolution',600);
end

%% helpers:
function [Re,f,hLmaj] = major_loss(rho,mu,epsilon,Q,D,L,g)
Re = Re_f(rho,abs(Q),D,mu);
f = f_f(Re,epsilon,D);
hLmaj = h_L_maj_f(f,L,D,Q,g);
end

function hLmin = minor_loss(K,Q,D,g)
A = pi*D^2/4;
V = Q/A;
hLmin = K*V^2/(2*g);
end

function Re = Re_f(rho,Q,D,mu)
Re = 4*rho*Q/(mu*pi*D);
end

function f = f_f(Re,epsilon,D)
f = (-1.8*log10(((epsilon./D)./3.7).^1.11 + 6.9./Re)).^(-2);
end

function hLmaj = h_L_maj_f(f,L,D,Q,g)
hLmaj = f*(8*L*Q.^2)./(pi^2*D.^5*g);
end

function hQ = pump_q_dependent_head(Q,rho,mu,epsilon,g,k_bend)
% Q-dependent part of pump head: velocity head + pump-side major/minor losses.
% Pressure and elevation terms are handled separately in the uncertainty calculation.
D_AB = 12.35e-3;
D_BC = 10e-3;
L_BC = (6+1.75)/39.37;
L_AB = 20.5/39.37-L_BC;
k_contract = 1.35;
k_entrance = 0.5;

if ~isfinite(Q)
    hQ = nan;
    return
end

h_L_entrance = minor_loss(k_entrance,Q,D_AB,g);
h_L_bend = minor_loss(k_bend,Q,D_AB,g);
h_L_contract = minor_loss(k_contract,Q,D_BC,g);
[~,~,h_L_majAB] = major_loss(rho,mu,epsilon,Q,D_AB,L_AB,g);
[~,~,h_L_majBC] = major_loss(rho,mu,epsilon,Q,D_BC,L_BC,g);

h_L12 = h_L_majAB+h_L_majBC+h_L_entrance+h_L_bend+h_L_contract;
hQ = 8*Q^2/(pi^2*D_BC^4*g)+h_L12;
end

% sources
% https://www.engineeringtoolbox.com/water-dynamic-kinematic-viscosity-d_596.html
% https://www.engineeringtoolbox.com/water-density-specific-weight-d_595.html?vA=67&units=F#
% https://www.techniquip.co.uk/product/safety-housed-variable-area-flow-meter-rotameter-type-exstock/