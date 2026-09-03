% Ray Ramadhar and Bri Connors
% me 342 heat exchanger design, where L, D_i, and t are parameterized

clc; clear; close all force;

set(groot,'defaultAxesFontName','Times New Roman');
set(groot,'defaultTextFontName','Times New Roman');
set(groot,'defaultLegendFontName','Times New Roman');

% parameters
cp_hot = 1006;
temp_hot_in = 25;
mu_hot = 1.81e-5;
k_hot = 0.0264;
Pr_hot = 0.715;

mass_flow_cold = 4.5;
cp_cold = 1006;
temp_cold_in = 0;
mu_cold = 1.81e-5;
k_cold = 0.0264;
Pr_cold = 0.715;

k_wall = 15;

% basic design values
mass_flow_hot_design = mass_flow_cold;
diameter_annulus = 0.15;

C_hot = mass_flow_hot_design*cp_hot;
C_cold = mass_flow_cold*cp_cold;
C_min = min(C_hot,C_cold);
C_max = max(C_hot,C_cold);
capacity_ratio = C_min/C_max;
q_max = C_min*(temp_hot_in - temp_cold_in);

% try a bunch of different geometries
inner_diameter_vec = linspace(0.03,0.135,80);
length_vec = linspace(1,300,300);
wall_thickness_vec = [0.001 0.002 0.004 0.006];
wall_thickness_base = 0.002;

num_thickness = length(wall_thickness_vec);
num_lengths = length(length_vec);
num_diameters = length(inner_diameter_vec);

temp_cold_out_sweep = nan(num_thickness,num_lengths,num_diameters);
temp_hot_out_sweep = nan(num_thickness,num_lengths,num_diameters);
effectiveness_sweep = nan(num_thickness,num_lengths,num_diameters);
heat_rate_sweep = nan(num_thickness,num_lengths,num_diameters);
overall_U_sweep = nan(num_thickness,num_lengths,num_diameters);
Re_cold_sweep = nan(num_thickness,num_lengths,num_diameters);
Re_hot_sweep = nan(num_thickness,num_lengths,num_diameters);
q_diff_pct_sweep = nan(num_thickness,num_lengths,num_diameters);

effectiveness_counter_sweep = nan(num_thickness,num_lengths,num_diameters);
effectiveness_parallel_sweep = nan(num_thickness,num_lengths,num_diameters);

for thickness_index = 1:num_thickness

    wall_thickness = wall_thickness_vec(thickness_index);

    for diameter_index = 1:num_diameters

        inner_diameter = inner_diameter_vec(diameter_index);

        for length_index = 1:num_lengths

            pipe_length = length_vec(length_index);

            [overall_U,outer_diameter,Re_cold,Re_hot] = calc_Uo_doublepipe(inner_diameter,wall_thickness,diameter_annulus,mass_flow_cold,mass_flow_hot_design,mu_cold,mu_hot,k_cold,k_hot,Pr_cold,Pr_hot,k_wall);

            if isnan(overall_U)
                continue
            end

            outer_area = pi*outer_diameter*pipe_length;
            UA = overall_U*outer_area;
            NTU = UA/C_min;

            effectiveness_counter = eps_counterflow(NTU,capacity_ratio);
            effectiveness_parallel = eps_parallelflow(NTU,capacity_ratio);

            q_ntu = effectiveness_counter*q_max;

            % solve outlet temp instead of assuming it
            temp_cold_out = solve_Tco_lmtd_ntu(q_ntu,UA,temp_hot_in,temp_cold_in,C_hot,C_cold,q_max);

            heat_rate = C_cold*(temp_cold_out - temp_cold_in);
            temp_hot_out = temp_hot_in - heat_rate/C_hot;
            effectiveness = heat_rate/q_max;

            delta_T1 = temp_hot_in - temp_cold_out;
            delta_T2 = temp_hot_out - temp_cold_in;
            delta_T_lm = calc_lmtd(delta_T1,delta_T2);
            q_lmtd = UA*delta_T_lm;

            temp_cold_out_sweep(thickness_index,length_index,diameter_index) = temp_cold_out;
            temp_hot_out_sweep(thickness_index,length_index,diameter_index) = temp_hot_out;
            effectiveness_sweep(thickness_index,length_index,diameter_index) = effectiveness;
            heat_rate_sweep(thickness_index,length_index,diameter_index) = heat_rate;
            overall_U_sweep(thickness_index,length_index,diameter_index) = overall_U;
            Re_cold_sweep(thickness_index,length_index,diameter_index) = Re_cold;
            Re_hot_sweep(thickness_index,length_index,diameter_index) = Re_hot;
            q_diff_pct_sweep(thickness_index,length_index,diameter_index) = 100*(q_lmtd - q_ntu)/q_ntu;

            effectiveness_counter_sweep(thickness_index,length_index,diameter_index) = effectiveness_counter;
            effectiveness_parallel_sweep(thickness_index,length_index,diameter_index) = effectiveness_parallel;

        end
    end
end

[~,thickness_base_id] = min(abs(wall_thickness_vec - wall_thickness_base));

% outlet temperature vs length
diameter_plot_mm = [30 60 90 120 135];
diameter_plot_m = diameter_plot_mm/1000;

figure;
hold on; grid on; box on;

diameter_legend = strings(length(diameter_plot_m),1);
h_diameter = gobjects(length(diameter_plot_m),1);

for plot_index = 1:length(diameter_plot_m)
    [~,diameter_id] = min(abs(inner_diameter_vec - diameter_plot_m(plot_index)));
    h_diameter(plot_index) = plot(length_vec,squeeze(temp_cold_out_sweep(thickness_base_id,:,diameter_id)),'LineWidth',2);
    diameter_legend(plot_index) = sprintf('D_i = %.0f mm',diameter_plot_mm(plot_index));
end

h_limit = yline(temp_hot_in,'k--','LineWidth',1.5);
ylim([0 temp_hot_in+1]);

xlabel('Length L [m]');
ylabel('Solved Cold Outlet Temperature T_{co} [C]');
title(sprintf('Solved T_{co} from LMTD-NTU Iteration, t = %.1f mm',wall_thickness_base*1000));

legend([h_diameter; h_limit],...
    [diameter_legend; sprintf('Ideal upper limit, T_{h,i} = %.0f C',temp_hot_in)],...
    'Location','best');

set(gca,'FontName','Times New Roman');
set(gcf,'Color','w');

% compare counterflow and parallel flow
diameter_flow_plot_mm = [30 80 135];
diameter_flow_plot_m = diameter_flow_plot_mm/1000;

figure;
tiledlayout(1,length(diameter_flow_plot_m),'TileSpacing','compact','Padding','compact');

for plot_index = 1:length(diameter_flow_plot_m)
    [~,diameter_flow_id] = min(abs(inner_diameter_vec - diameter_flow_plot_m(plot_index)));

    nexttile;
    hold on; grid on; box on;

    plot(length_vec,squeeze(effectiveness_counter_sweep(thickness_base_id,:,diameter_flow_id)),'LineWidth',2);
    plot(length_vec,squeeze(effectiveness_parallel_sweep(thickness_base_id,:,diameter_flow_id)),'--','LineWidth',2);

    xlabel('Length L [m]');
    ylabel('Effectiveness \epsilon');
    title(sprintf('D_i = %.0f mm',diameter_flow_plot_mm(plot_index)));
    set(gca,'FontName','Times New Roman');

    if plot_index == length(diameter_flow_plot_m)
        legend('Counterflow','Parallel flow','Location','best');
    end
end

sgtitle(sprintf('Flow Arrangement Effect on Effectiveness, t = %.1f mm',wall_thickness_base*1000),...
    'FontName','Times New Roman','FontSize',12,'FontWeight','bold');
set(gcf,'Color','w');

% outlet temperature vs diameter for a few lengths
length_plot_vec = [10 20 40 60 80 100];

figure;
hold on; grid on; box on;

length_legend = strings(length(length_plot_vec),1);

for plot_index = 1:length(length_plot_vec)
    [~,length_id] = min(abs(length_vec - length_plot_vec(plot_index)));
    plot(inner_diameter_vec*1000,squeeze(temp_cold_out_sweep(thickness_base_id,length_id,:)),'LineWidth',2);
    length_legend(plot_index) = sprintf('L = %.0f m',length_vec(length_id));
end

xlabel('Inner Diameter D_i [mm]');
ylabel('Solved Cold Outlet Temperature T_{co} [C]');
title(sprintf('Solved T_{co} vs Diameter, t = %.1f mm',wall_thickness_base*1000));
legend(length_legend,'Location','best');
set(gca,'FontName','Times New Roman');
set(gcf,'Color','w');

% see what wall thickness does to effectiveness
length_sample_vec = [20 40 60];
diameter_thickness_plot_mm = [30 80 135];
diameter_thickness_plot_m = diameter_thickness_plot_mm/1000;

figure;
tiledlayout(1,length(length_sample_vec),'TileSpacing','compact','Padding','compact');

diameter_thickness_legend = strings(length(diameter_thickness_plot_m),1);

for plot_index = 1:length(length_sample_vec)

    [~,length_id] = min(abs(length_vec - length_sample_vec(plot_index)));

    nexttile;
    hold on; grid on; box on;

    for diameter_index = 1:length(diameter_thickness_plot_m)
        [~,diameter_id] = min(abs(inner_diameter_vec - diameter_thickness_plot_m(diameter_index)));
        plot(wall_thickness_vec*1000,squeeze(effectiveness_sweep(:,length_id,diameter_id)),'-o','LineWidth',2);
        diameter_thickness_legend(diameter_index) = sprintf('D_i = %.0f mm',diameter_thickness_plot_mm(diameter_index));
    end

    xlabel('Wall Thickness t [mm]');
    ylabel('Solved Effectiveness \epsilon');
    title(sprintf('L = %.0f m',length_vec(length_id)));
    ylim([0 1]);
    set(gca,'FontName','Times New Roman');

    if plot_index == length(length_sample_vec)
        legend(diameter_thickness_legend,'Location','best');
    end
end

sgtitle('Effect of Wall Thickness on Solved Effectiveness',...
    'FontName','Times New Roman','FontSize',12,'FontWeight','bold');
set(gcf,'Color','w');

% make sure lmtd and ntu agree
q_diff_all = abs(q_diff_pct_sweep(:));
q_diff_all = q_diff_all(~isnan(q_diff_all));
max_q_difference = max(q_diff_all);

fprintf('\nLMTD vs NTU consistency check:\n');
fprintf('Maximum percent difference between q_LMTD and q_NTU = %.3e %%\n',max_q_difference);

if max_q_difference < 1e-6
    fprintf('The LMTD and NTU heat-transfer predictions agree to numerical precision.\n');
else
    fprintf('The LMTD and NTU heat-transfer predictions show a noticeable difference.\n');
end

% put a few designs in a table
diameter_table_mm = [30 80 135];
length_table_vec = [20 40 60];
wall_thickness_table = wall_thickness_base;

[~,thickness_table_id] = min(abs(wall_thickness_vec - wall_thickness_table));

num_table_rows = length(diameter_table_mm)*length(length_table_vec);

inner_diameter_out = nan(num_table_rows,1);
outer_diameter_out = nan(num_table_rows,1);
length_out = nan(num_table_rows,1);
wall_thickness_out = nan(num_table_rows,1);
temp_cold_out = nan(num_table_rows,1);
temp_hot_out = nan(num_table_rows,1);
effectiveness_out = nan(num_table_rows,1);
heat_rate_out = nan(num_table_rows,1);
overall_U_out = nan(num_table_rows,1);
Re_cold_out = nan(num_table_rows,1);
Re_hot_out = nan(num_table_rows,1);
q_diff_pct_out = nan(num_table_rows,1);

table_row = 0;

for length_index = 1:length(length_table_vec)

    [~,length_table_id] = min(abs(length_vec - length_table_vec(length_index)));

    for diameter_index = 1:length(diameter_table_mm)

        table_row = table_row + 1;

        [~,diameter_table_id] = min(abs(inner_diameter_vec - diameter_table_mm(diameter_index)/1000));

        inner_diameter = inner_diameter_vec(diameter_table_id);
        wall_thickness = wall_thickness_vec(thickness_table_id);
        outer_diameter = inner_diameter + 2*wall_thickness;

        inner_diameter_out(table_row) = inner_diameter*1000;
        outer_diameter_out(table_row) = outer_diameter*1000;
        length_out(table_row) = length_vec(length_table_id);
        wall_thickness_out(table_row) = wall_thickness*1000;

        temp_cold_out(table_row) = temp_cold_out_sweep(thickness_table_id,length_table_id,diameter_table_id);
        temp_hot_out(table_row) = temp_hot_out_sweep(thickness_table_id,length_table_id,diameter_table_id);
        effectiveness_out(table_row) = effectiveness_sweep(thickness_table_id,length_table_id,diameter_table_id);
        heat_rate_out(table_row) = heat_rate_sweep(thickness_table_id,length_table_id,diameter_table_id);
        overall_U_out(table_row) = overall_U_sweep(thickness_table_id,length_table_id,diameter_table_id);
        Re_cold_out(table_row) = Re_cold_sweep(thickness_table_id,length_table_id,diameter_table_id);
        Re_hot_out(table_row) = Re_hot_sweep(thickness_table_id,length_table_id,diameter_table_id);
        q_diff_pct_out(table_row) = q_diff_pct_sweep(thickness_table_id,length_table_id,diameter_table_id);
    end
end

SolvedDesignTable = table(inner_diameter_out,outer_diameter_out,wall_thickness_out,length_out,temp_cold_out,temp_hot_out,effectiveness_out,heat_rate_out,overall_U_out,Re_cold_out,Re_hot_out,q_diff_pct_out,...
    'VariableNames',{'Di_mm','Do_mm','WallThickness_mm','Length_m','Solved_Tco_C','Solved_Tho_C','Solved_Effectiveness','Solved_q_W','Uo_W_m2K','Re_cold','Re_hot','qDiff_pct'});

disp('Solved design table from LMTD-NTU iteration:')
disp(SolvedDesignTable)

fprintf('\nNo outlet temperature was manually fixed in this design sweep.\n');
fprintf('For each geometry, Tco and Tho were solved from the LMTD-NTU iteration.\n');
fprintf('The plots parameterize design constraints after solving the thermal model.\n');

% compare phe and double pipe for one geometry

% pick one double pipe geometry to compare
inner_diameter_compare = 0.120;      % [m]
length_compare = 50;                 % [m]
wall_thickness_compare = wall_thickness_base;

outer_diameter_compare = inner_diameter_compare + 2*wall_thickness_compare;
area_compare = pi*outer_diameter_compare*length_compare;

if outer_diameter_compare >= diameter_annulus
    error('chosen comparison diameter is too large for the annulus diameter')
end

fprintf('\nPHE/double pipe comparison geometry:\n');
fprintf('D_i = %.1f mm\n',inner_diameter_compare*1000);
fprintf('D_o = %.1f mm\n',outer_diameter_compare*1000);
fprintf('L = %.1f m\n',length_compare);
fprintf('A_o = %.2f m^2\n',area_compare);

% use the same hot and cold flow rate
mass_flow_compare_vec = linspace(0.5,mass_flow_cold,10);

% phe geometry and correlation values
b_phe = 0.01;
W_phe = 0.3;
D_e_phe = 2*b_phe;
t_phe = 0.006;
k_phe = k_wall;
C_phe = 0.4;
n_phe = 0.5;

% use about the same heat transfer area
plate_length_phe = 1.0;                 % assumed plate flow length [m]
plate_area_single = W_phe*plate_length_phe; % one-side area per plate [m^2]

area_target = area_compare;             % selected double-pipe area [m^2]
plates_equal_area = ceil(area_target/plate_area_single) + 2;

% keep an odd number of plates so the channels split evenly
if mod(plates_equal_area,2) == 0
    plates_equal_area = plates_equal_area + 1;
end

heat_transfer_plates = plates_equal_area - 2;
area_equal_compare = heat_transfer_plates*plate_area_single;

hot_channels = (plates_equal_area - 1)/2;
cold_channels = hot_channels;

flow_area_hot_phe = hot_channels*b_phe*W_phe;
flow_area_cold_phe = cold_channels*b_phe*W_phe;

EqualAreaBasisTable = table(area_target,area_equal_compare,plates_equal_area,hot_channels,cold_channels,plate_area_single,...
    'VariableNames',{'DoublePipeArea_m2','EqualPHEArea_m2','PHE_Plates','HotChannels','ColdChannels','AreaPerPlate_m2'});

disp('Equal-area basis for PHE comparison:')
disp(EqualAreaBasisTable)

q_phe = nan(size(mass_flow_compare_vec));
q_dp = nan(size(mass_flow_compare_vec));
effectiveness_phe = nan(size(mass_flow_compare_vec));
effectiveness_dp = nan(size(mass_flow_compare_vec));
temp_cold_out_phe = nan(size(mass_flow_compare_vec));
temp_cold_out_dp = nan(size(mass_flow_compare_vec));
temp_hot_out_phe = nan(size(mass_flow_compare_vec));
temp_hot_out_dp = nan(size(mass_flow_compare_vec));
delta_T_lm_phe = nan(size(mass_flow_compare_vec));
delta_T_lm_dp = nan(size(mass_flow_compare_vec));

for flow_index = 1:length(mass_flow_compare_vec)

    mass_flow_hot_compare = mass_flow_compare_vec(flow_index);
    mass_flow_cold_compare = mass_flow_compare_vec(flow_index);

    C_hot_compare = mass_flow_hot_compare*cp_hot;
    C_cold_compare = mass_flow_cold_compare*cp_cold;
    C_min_compare = min(C_hot_compare,C_cold_compare);
    C_max_compare = max(C_hot_compare,C_cold_compare);
    capacity_ratio_compare = C_min_compare/C_max_compare;
    q_max_compare = C_min_compare*(temp_hot_in - temp_cold_in);

    % PHE calculation
    G_hot_phe = mass_flow_hot_compare/flow_area_hot_phe;
    Re_hot_phe = G_hot_phe*D_e_phe/mu_hot;
    Nu_hot_phe = C_phe*(Re_hot_phe^n_phe)*(Pr_hot^(1/3))*0.9;
    h_hot_phe = Nu_hot_phe*k_hot/D_e_phe;

    G_cold_phe = mass_flow_cold_compare/flow_area_cold_phe;
    Re_cold_phe = G_cold_phe*D_e_phe/mu_cold;
    Nu_cold_phe = C_phe*(Re_cold_phe^n_phe)*(Pr_cold^(1/3))*0.7;
    h_cold_phe = Nu_cold_phe*k_cold/D_e_phe;

    U_phe = 1/(1/h_hot_phe + t_phe/k_phe + 1/h_cold_phe);
    UA_phe = U_phe*area_equal_compare;
    NTU_phe = UA_phe/C_min_compare;

    effectiveness_phe(flow_index) = eps_counterflow(NTU_phe,capacity_ratio_compare);
    q_phe(flow_index) = effectiveness_phe(flow_index)*q_max_compare;

    temp_cold_out_phe(flow_index) = temp_cold_in + q_phe(flow_index)/C_cold_compare;
    temp_hot_out_phe(flow_index) = temp_hot_in - q_phe(flow_index)/C_hot_compare;

    delta_T1_phe = temp_hot_in - temp_cold_out_phe(flow_index);
    delta_T2_phe = temp_hot_out_phe(flow_index) - temp_cold_in;
    delta_T_lm_phe(flow_index) = calc_lmtd(delta_T1_phe,delta_T2_phe);

    % double pipe calculation using the same selected geometry area
    [U_dp,~] = calc_Uo_doublepipe(inner_diameter_compare,wall_thickness_compare,diameter_annulus,mass_flow_cold_compare,mass_flow_hot_compare,mu_cold,mu_hot,k_cold,k_hot,Pr_cold,Pr_hot,k_wall);

    UA_dp = U_dp*area_equal_compare;
    NTU_dp = UA_dp/C_min_compare;

    effectiveness_dp(flow_index) = eps_counterflow(NTU_dp,capacity_ratio_compare);
    q_dp(flow_index) = effectiveness_dp(flow_index)*q_max_compare;

    temp_cold_out_dp(flow_index) = temp_cold_in + q_dp(flow_index)/C_cold_compare;
    temp_hot_out_dp(flow_index) = temp_hot_in - q_dp(flow_index)/C_hot_compare;

    delta_T1_dp = temp_hot_in - temp_cold_out_dp(flow_index);
    delta_T2_dp = temp_hot_out_dp(flow_index) - temp_cold_in;
    delta_T_lm_dp(flow_index) = calc_lmtd(delta_T1_dp,delta_T2_dp);
end

figure;
plot(mass_flow_compare_vec,q_phe/1000,'r-o','LineWidth',2); hold on;
plot(mass_flow_compare_vec,q_dp/1000,'b--s','LineWidth',2);
grid on; box on;
xlabel('Common Hot and Cold Mass Flow Rate [kg/s]');
ylabel('Heat Rate q [kW]');
title(sprintf('PHE and Double Pipe Heat Rate, D_i = %.0f mm, L = %.0f m',inner_diameter_compare*1000,length_compare));
legend('PHE','Double Pipe','Location','best');
set(gca,'FontName','Times New Roman');
set(gcf,'Color','w');

figure;
plot(mass_flow_compare_vec,effectiveness_phe,'r-o','LineWidth',2); hold on;
plot(mass_flow_compare_vec,effectiveness_dp,'b--s','LineWidth',2);
grid on; box on;
xlabel('Common Hot and Cold Mass Flow Rate [kg/s]');
ylabel('Effectiveness \epsilon');
title(sprintf('PHE and Double Pipe Effectiveness, D_i = %.0f mm, L = %.0f m',inner_diameter_compare*1000,length_compare));
legend('PHE','Double Pipe','Location','best');
set(gca,'FontName','Times New Roman');
set(gcf,'Color','w');

figure;
plot(mass_flow_compare_vec,delta_T_lm_phe,'r-o','LineWidth',2); hold on;
plot(mass_flow_compare_vec,delta_T_lm_dp,'b--s','LineWidth',2);
grid on; box on;
xlabel('Common Hot and Cold Mass Flow Rate [kg/s]');
ylabel('LMTD [C]');
title(sprintf('PHE and Double Pipe LMTD, D_i = %.0f mm, L = %.0f m',inner_diameter_compare*1000,length_compare));
legend('PHE','Double Pipe','Location','best');
set(gca,'FontName','Times New Roman');
set(gcf,'Color','w');

figure;
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile;
plot(mass_flow_compare_vec,temp_cold_out_phe,'r-o','LineWidth',2); hold on;
plot(mass_flow_compare_vec,temp_cold_out_dp,'b--s','LineWidth',2);
grid on; box on;
xlabel('Common Hot and Cold Mass Flow Rate [kg/s]');
ylabel('Cold Outlet Temperature T_{co} [C]');
title('Cold Outlet Temperature');
legend('PHE','Double Pipe','Location','best');
set(gca,'FontName','Times New Roman');

nexttile;
plot(mass_flow_compare_vec,temp_hot_out_phe,'r-o','LineWidth',2); hold on;
plot(mass_flow_compare_vec,temp_hot_out_dp,'b--s','LineWidth',2);
grid on; box on;
xlabel('Common Hot and Cold Mass Flow Rate [kg/s]');
ylabel('Hot Outlet Temperature T_{ho} [C]');
title('Hot Outlet Temperature');
legend('PHE','Double Pipe','Location','best');
set(gca,'FontName','Times New Roman');

sgtitle(sprintf('Equal-Area Outlet Temperature Comparison, A \\approx %.2f m^2',area_equal_compare),...
    'FontName','Times New Roman','FontSize',12,'FontWeight','bold');
set(gcf,'Color','w');

% fan stuff

% air density at the inlet temperatures
rho_hot = 1.184;       % hot air density near 25 C [kg/m^3]
rho_cold = 1.293;      % cold air density near 0 C [kg/m^3]
fan_efficiency = 1.0;  % assumed fan fully efficient
mass_flow_total_parallel = 4.5; % test flow rate [kg/s]

% see if splitting the flow between exchangers helps
exchanger_count_vec = 1:15;

best_ratio_vec = nan(size(exchanger_count_vec));
best_net_heat_vec = nan(size(exchanger_count_vec));
best_diameter_vec = nan(size(exchanger_count_vec));
best_length_vec = nan(size(exchanger_count_vec));
best_heat_rate_vec = nan(size(exchanger_count_vec));
best_fan_power_vec = nan(size(exchanger_count_vec));
best_net_ratio_vec = nan(size(exchanger_count_vec));
best_net_diameter_vec = nan(size(exchanger_count_vec));
best_net_length_vec = nan(size(exchanger_count_vec));
best_net_heat_rate_vec = nan(size(exchanger_count_vec));
best_net_fan_power_vec = nan(size(exchanger_count_vec));
best_net_output_vec = nan(size(exchanger_count_vec));

for exchanger_index = 1:length(exchanger_count_vec)

    exchangers = exchanger_count_vec(exchanger_index);

    mass_flow_cold_branch = mass_flow_total_parallel/exchangers;
    mass_flow_hot_branch = mass_flow_total_parallel/exchangers;

    ratio_sweep = nan(num_lengths,num_diameters);
    net_heat_parallel_sweep = nan(num_lengths,num_diameters);
    heat_parallel_sweep = nan(num_lengths,num_diameters);
    fan_parallel_sweep = nan(num_lengths,num_diameters);

    for diameter_index = 1:num_diameters

        inner_diameter = inner_diameter_vec(diameter_index);
        wall_thickness = wall_thickness_base;

        for length_index = 1:num_lengths

            pipe_length = length_vec(length_index);

            [overall_U_branch,outer_diameter] = calc_Uo_doublepipe(inner_diameter,wall_thickness,diameter_annulus,mass_flow_cold_branch,mass_flow_hot_branch,mu_cold,mu_hot,k_cold,k_hot,Pr_cold,Pr_hot,k_wall);

            if isnan(overall_U_branch)
                continue
            end

            C_hot_branch = mass_flow_hot_branch*cp_hot;
            C_cold_branch = mass_flow_cold_branch*cp_cold;
            C_min_branch = min(C_hot_branch,C_cold_branch);
            C_max_branch = max(C_hot_branch,C_cold_branch);
            capacity_ratio_branch = C_min_branch/C_max_branch;
            q_max_branch = C_min_branch*(temp_hot_in - temp_cold_in);

            outer_area_branch = pi*outer_diameter*pipe_length;
            UA_branch = overall_U_branch*outer_area_branch;
            NTU_branch = UA_branch/C_min_branch;

            effectiveness_branch = eps_counterflow(NTU_branch,capacity_ratio_branch);
            q_branch = effectiveness_branch*q_max_branch;

            [~,~,fan_power_branch] = calc_fan_power_doublepipe(inner_diameter,outer_diameter,diameter_annulus,pipe_length,mass_flow_cold_branch,mass_flow_hot_branch,rho_cold,rho_hot,mu_cold,mu_hot,fan_efficiency);

            q_total = exchangers*q_branch;
            fan_power_total = exchangers*fan_power_branch;
            net_heat_total = q_total - fan_power_total;

            ratio_sweep(length_index,diameter_index) = fan_power_total/q_total;
            net_heat_parallel_sweep(length_index,diameter_index) = net_heat_total;
            heat_parallel_sweep(length_index,diameter_index) = q_total;
            fan_parallel_sweep(length_index,diameter_index) = fan_power_total;

        end
    end

    [best_ratio,best_index] = min(ratio_sweep(:));
    [best_length_id,best_diameter_id] = ind2sub(size(ratio_sweep),best_index);

    best_ratio_vec(exchanger_index) = best_ratio;
    best_net_heat_vec(exchanger_index) = net_heat_parallel_sweep(best_length_id,best_diameter_id);
    best_diameter_vec(exchanger_index) = inner_diameter_vec(best_diameter_id);
    best_length_vec(exchanger_index) = length_vec(best_length_id);
    best_heat_rate_vec(exchanger_index) = heat_parallel_sweep(best_length_id,best_diameter_id);
    best_fan_power_vec(exchanger_index) = fan_parallel_sweep(best_length_id,best_diameter_id);
    
    [max_net_output,max_net_index] = max(net_heat_parallel_sweep(:));
    [best_net_length_id,best_net_diameter_id] = ind2sub(size(net_heat_parallel_sweep),max_net_index);
    
    best_net_ratio_vec(exchanger_index) = ratio_sweep(best_net_length_id,best_net_diameter_id);
    best_net_diameter_vec(exchanger_index) = inner_diameter_vec(best_net_diameter_id);
    best_net_length_vec(exchanger_index) = length_vec(best_net_length_id);
    best_net_heat_rate_vec(exchanger_index) = heat_parallel_sweep(best_net_length_id,best_net_diameter_id);
    best_net_fan_power_vec(exchanger_index) = fan_parallel_sweep(best_net_length_id,best_net_diameter_id);
    best_net_output_vec(exchanger_index) = max_net_output;

end

% same idea for different phe sizes

plate_count_vec = 5:2:201;

W_phe_vec = [0.3 1.0];
phe_label_vec = ["PHE, 1 m x 0.3 m plates","PHE, 1 m x 1 m plates"];

phe_ratio_mat = nan(length(W_phe_vec),length(plate_count_vec));
phe_area_mat = nan(length(W_phe_vec),length(plate_count_vec));

for geom_index = 1:length(W_phe_vec)

    W_phe_test = W_phe_vec(geom_index);
    plate_area_test = W_phe_test*plate_length_phe;

    for plate_index = 1:length(plate_count_vec)

        plate_count = plate_count_vec(plate_index);

        hot_channels_i = (plate_count - 1)/2;
        cold_channels_i = hot_channels_i;
        heat_transfer_plates_i = plate_count - 2;

        area_phe_i = heat_transfer_plates_i*plate_area_test;
        phe_area_mat(geom_index,plate_index) = area_phe_i;

        flow_area_hot_i = hot_channels_i*b_phe*W_phe_test;
        flow_area_cold_i = cold_channels_i*b_phe*W_phe_test;

        C_hot_i = mass_flow_total_parallel*cp_hot;
        C_cold_i = mass_flow_total_parallel*cp_cold;
        C_min_i = min(C_hot_i,C_cold_i);
        C_max_i = max(C_hot_i,C_cold_i);
        capacity_ratio_i = C_min_i/C_max_i;
        q_max_i = C_min_i*(temp_hot_in - temp_cold_in);

        G_hot_i = mass_flow_total_parallel/flow_area_hot_i;
        Re_hot_i = G_hot_i*D_e_phe/mu_hot;
        Nu_hot_i = C_phe*(Re_hot_i^n_phe)*(Pr_hot^(1/3))*0.9;
        h_hot_i = Nu_hot_i*k_hot/D_e_phe;

        G_cold_i = mass_flow_total_parallel/flow_area_cold_i;
        Re_cold_i = G_cold_i*D_e_phe/mu_cold;
        Nu_cold_i = C_phe*(Re_cold_i^n_phe)*(Pr_cold^(1/3))*0.7;
        h_cold_i = Nu_cold_i*k_cold/D_e_phe;

        U_phe_i = 1/(1/h_hot_i + t_phe/k_phe + 1/h_cold_i);
        UA_phe_i = U_phe_i*area_phe_i;
        NTU_phe_i = UA_phe_i/C_min_i;

        effectiveness_phe_i = eps_counterflow(NTU_phe_i,capacity_ratio_i);
        q_phe_i = effectiveness_phe_i*q_max_i;

        velocity_hot_i = mass_flow_total_parallel/(rho_hot*flow_area_hot_i);
        velocity_cold_i = mass_flow_total_parallel/(rho_cold*flow_area_cold_i);

        friction_hot_i = calc_friction_factor(Re_hot_i);
        friction_cold_i = calc_friction_factor(Re_cold_i);

        pressure_drop_hot_i = friction_hot_i*(plate_length_phe/D_e_phe)*(rho_hot*velocity_hot_i^2/2);
        pressure_drop_cold_i = friction_cold_i*(plate_length_phe/D_e_phe)*(rho_cold*velocity_cold_i^2/2);

        volume_flow_hot_i = mass_flow_total_parallel/rho_hot;
        volume_flow_cold_i = mass_flow_total_parallel/rho_cold;

        fan_power_phe_i = (pressure_drop_hot_i*volume_flow_hot_i + pressure_drop_cold_i*volume_flow_cold_i)/fan_efficiency;

        phe_ratio_mat(geom_index,plate_index) = fan_power_phe_i/q_phe_i;

    end
end

phe_area_vec = phe_area_mat(1,:);
phe_ratio_vec = phe_ratio_mat(1,:);
phe_area_big_vec = phe_area_mat(2,:);
phe_ratio_big_vec = phe_ratio_mat(2,:);

dp_area_vec = exchanger_count_vec.*pi.*(best_diameter_vec + 2*wall_thickness_base).*best_length_vec;

figure;
semilogy(dp_area_vec,best_ratio_vec,'-o','LineWidth',2,'Color',[0 0.4470 0.7410]);
hold on; grid on; box on;
% semilogy(phe_area_vec,phe_ratio_vec,'-s','LineWidth',2,'Color',[0.9290 0.6940 0.1250],'MarkerIndices',1:6:length(plate_count_vec));
semilogy(phe_area_big_vec,phe_ratio_big_vec,'-^','LineWidth',2,'Color',[0.8500 0.3250 0.0980],'MarkerIndices',1:6:length(plate_count_vec));
yline(1,'k--','Break-even','LineWidth',1.5);
xlim([0 80]);

xlabel('Total Heat-Transfer Area A [m^2]');
ylabel('P_{fan,ideal}/q_{recovered}');
title(sprintf('Double-Pipe vs PHE Fan-Power Ratio, Total Flow = %.1f kg/s',mass_flow_total_parallel));
legend('Double-pipe optimized paths','PHE 1 m x 1 m plates','Break-even','Location','best');

set(gca,'FontName','Times New Roman');
set(gca,'YScale','log');
set(gcf,'Color','w');

for geom_index = 1:length(W_phe_vec)
    break_even_index = find(phe_ratio_mat(geom_index,:) <= 1,1,'first');

    if ~isempty(break_even_index)
        fprintf('\n%s first reaches break-even at approximately:\n',phe_label_vec(geom_index));
        fprintf('Plates = %d\n',plate_count_vec(break_even_index));
        fprintf('Area = %.2f m^2\n',phe_area_mat(geom_index,break_even_index));
        fprintf('Pfan/q = %.3f\n',phe_ratio_mat(geom_index,break_even_index));
    else
        fprintf('\n%s did not reach break-even in the plate-count range tested.\n',phe_label_vec(geom_index));
    end
end

% put the useful results in tables
ParallelExchangerTable = table(exchanger_count_vec(:),best_ratio_vec(:),best_diameter_vec(:)*1000,best_length_vec(:),best_heat_rate_vec(:)/1000,best_fan_power_vec(:)/1000,best_net_heat_vec(:)/1000,...
    'VariableNames',{'Exchangers','Best_PfanIdeal_over_q','Best_Di_mm','Best_Length_m','q_recovered_kW','PfanIdeal_kW','q_net_kW'});

disp('Parallel exchanger count sweep:')
disp(ParallelExchangerTable)

ParallelNetOutputTable = table(exchanger_count_vec(:),best_net_ratio_vec(:),best_net_diameter_vec(:)*1000,best_net_length_vec(:),best_net_heat_rate_vec(:)/1000,best_net_fan_power_vec(:)/1000,best_net_output_vec(:)/1000,...
    'VariableNames',{'Exchangers','PfanIdeal_over_q','Best_Di_mm','Best_Length_m','q_recovered_kW','PfanIdeal_kW','q_net_kW'});

disp('Parallel exchanger max net-output design table:')
disp(ParallelNetOutputTable)

export_all_figures('ME342_figures');

fprintf('\nTemperature-label sanity check:\n');
fprintf('At first flow point:\n');
fprintf('q_phe = %.2f kW, Tco_phe = %.2f C, Tho_phe = %.2f C\n',q_phe(1)/1000,temp_cold_out_phe(1),temp_hot_out_phe(1));
fprintf('q_dp  = %.2f kW, Tco_dp  = %.2f C, Tho_dp  = %.2f C\n',q_dp(1)/1000,temp_cold_out_dp(1),temp_hot_out_dp(1));

fprintf('\nAt last flow point:\n');
fprintf('q_phe = %.2f kW, Tco_phe = %.2f C, Tho_phe = %.2f C\n',q_phe(end)/1000,temp_cold_out_phe(end),temp_hot_out_phe(end));
fprintf('q_dp  = %.2f kW, Tco_dp  = %.2f C, Tho_dp  = %.2f C\n',q_dp(end)/1000,temp_cold_out_dp(end),temp_hot_out_dp(end));

% functions
function temp_cold_out = solve_Tco_lmtd_ntu(q_ntu,UA,temp_hot_in,temp_cold_in,C_hot,C_cold,q_max)

temp_cold_low = temp_cold_in + 1e-8;
temp_cold_high = temp_cold_in + 0.999999*q_max/C_cold;

temp_cold_guess = temp_cold_in + q_ntu/C_cold;
temp_cold_guess = min(max(temp_cold_guess,temp_cold_low),temp_cold_high);

residual_function = @(temp_cold_out) lmtd_ntu_residual(temp_cold_out,q_ntu,UA,temp_hot_in,temp_cold_in,C_hot,C_cold);

residual_low = residual_function(temp_cold_low);
residual_high = residual_function(temp_cold_high);

if isfinite(residual_low) && isfinite(residual_high) && residual_low*residual_high < 0
    temp_cold_out = fzero(residual_function,[temp_cold_low,temp_cold_high]);
else
    try
        temp_cold_out = fzero(residual_function,temp_cold_guess);
    catch
        temp_cold_out = temp_cold_guess;
    end
end
end

function residual = lmtd_ntu_residual(temp_cold_out,q_ntu,UA,temp_hot_in,temp_cold_in,C_hot,C_cold)

q_energy = C_cold*(temp_cold_out - temp_cold_in);
temp_hot_out = temp_hot_in - q_energy/C_hot;

delta_T1 = temp_hot_in - temp_cold_out;
delta_T2 = temp_hot_out - temp_cold_in;

delta_T_lm = calc_lmtd(delta_T1,delta_T2);

if isnan(delta_T_lm)
    residual = 1e12;
else
    q_lmtd = UA*delta_T_lm;
    residual = q_lmtd - q_ntu;
end

end

function delta_T_lm = calc_lmtd(delta_T1,delta_T2)

if delta_T1 <= 0 || delta_T2 <= 0
    delta_T_lm = NaN;
elseif abs(delta_T1-delta_T2) < 1e-8
    delta_T_lm = delta_T1;
else
    delta_T_lm = (delta_T1-delta_T2)/log(delta_T1/delta_T2);
end
end

function effectiveness = eps_counterflow(NTU,capacity_ratio)

if abs(capacity_ratio - 1) < 1e-8
    effectiveness = NTU/(1 + NTU);
else
    effectiveness = (1 - exp(-NTU*(1 - capacity_ratio)))/(1 - capacity_ratio*exp(-NTU*(1 - capacity_ratio)));
end
end

function effectiveness = eps_parallelflow(NTU,capacity_ratio)
effectiveness = (1 - exp(-NTU*(1 + capacity_ratio)))/(1 + capacity_ratio);
end

function [overall_U,outer_diameter,Re_cold,Re_hot] = calc_Uo_doublepipe(inner_diameter,wall_thickness,diameter_annulus,mass_flow_cold,mass_flow_hot,mu_cold,mu_hot,k_cold,k_hot,Pr_cold,Pr_hot,k_wall)
outer_diameter = inner_diameter + 2*wall_thickness;
hydraulic_diameter_annulus = diameter_annulus - outer_diameter;

Re_cold = NaN;
Re_hot = NaN;

if hydraulic_diameter_annulus <= 0
    overall_U = NaN;
    return
end

Re_cold = (4*mass_flow_cold)/(pi*inner_diameter*mu_cold);

if Re_cold > 2300
    Nu_cold = 0.023*(Re_cold^0.8)*(Pr_cold^0.4);
else
    Nu_cold = 3.66;
end

h_cold = Nu_cold*k_cold/inner_diameter;

Re_hot = (4*mass_flow_hot)/(pi*(diameter_annulus + outer_diameter)*mu_hot);

if Re_hot > 2300
    Nu_hot = 0.023*(Re_hot^0.8)*(Pr_hot^0.3);
else
    Nu_hot = 3.66;
end

h_hot = Nu_hot*k_hot/hydraulic_diameter_annulus;

overall_U = 1/(outer_diameter/(inner_diameter*h_cold) + outer_diameter*log(outer_diameter/inner_diameter)/(2*k_wall) + 1/h_hot);

end

function export_all_figures(folder_name)

if ~exist(folder_name,'dir')
    mkdir(folder_name);
end

figures = findall(0,'Type','figure');
[~,figure_order] = sort([figures.Number]);
figures = figures(figure_order);

for figure_index = 1:length(figures)

    figure(figures(figure_index));
    set(gcf,'Color','w');

    file_name = sprintf('figure_%02d.png',figure_index);
    exportgraphics(gcf,fullfile(folder_name,file_name),'Resolution',300);

end

fprintf('\nExported %d figures to folder: %s\n',length(figures),folder_name);

end

function [pressure_drop_cold,pressure_drop_hot,fan_power] = calc_fan_power_doublepipe(inner_diameter,outer_diameter,diameter_annulus,pipe_length,mass_flow_cold,mass_flow_hot,rho_cold,rho_hot,mu_cold,mu_hot,fan_efficiency)

area_cold = pi*inner_diameter^2/4;
area_hot = pi*(diameter_annulus^2 - outer_diameter^2)/4;
hydraulic_diameter_hot = diameter_annulus - outer_diameter;

if area_cold <= 0 || area_hot <= 0 || hydraulic_diameter_hot <= 0
    pressure_drop_cold = NaN;
    pressure_drop_hot = NaN;
    fan_power = NaN;
    return
end

velocity_cold = mass_flow_cold/(rho_cold*area_cold);
velocity_hot = mass_flow_hot/(rho_hot*area_hot);

Re_cold = rho_cold*velocity_cold*inner_diameter/mu_cold;
Re_hot = rho_hot*velocity_hot*hydraulic_diameter_hot/mu_hot;

friction_cold = calc_friction_factor(Re_cold);
friction_hot = calc_friction_factor(Re_hot);

pressure_drop_cold = friction_cold*(pipe_length/inner_diameter)*(rho_cold*velocity_cold^2/2);
pressure_drop_hot = friction_hot*(pipe_length/hydraulic_diameter_hot)*(rho_hot*velocity_hot^2/2);

volume_flow_cold = mass_flow_cold/rho_cold;
volume_flow_hot = mass_flow_hot/rho_hot;

fan_power = (pressure_drop_cold*volume_flow_cold + pressure_drop_hot*volume_flow_hot)/fan_efficiency;

end

function friction_factor = calc_friction_factor(Re)

if Re <= 0 || isnan(Re)
    friction_factor = NaN;
elseif Re < 2300
    friction_factor = 64/Re;
else
    friction_factor = 0.3164/(Re^0.25);
end
end