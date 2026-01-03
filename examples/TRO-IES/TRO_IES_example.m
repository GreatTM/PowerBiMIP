%TRO_IES_EXAMPLE Two-stage robust optimization for Integrated Energy System
%
%   This example demonstrates how to use solve_TRO to solve a complex
%   two-stage robust optimization problem for an Integrated Energy System (IES).
%
%   Description:
%       This example solves a TRO-LP problem for an IES including:
%       - Power grid with PCC, branches, buses
%       - Energy storage (ES) and thermal storage (TST) devices
%       - Gas turbine (GT) and electric boiler (EB) devices
%       - Heating network with pipes and nodes
%       - Buildings with thermal dynamics
%       - Uncertainty in renewable generation, load, and temperatures
%
%   Usage:
%       Run this script to solve the TRO-IES problem using solve_TRO.
%
%   See also: solve_TRO, TROsettings

dbstop if error
clc; clear all; close all;
yalmip('clear');
global data

%% ==================== Data Reading and Initialization ====================
data = readData();

% Initialize parameters
num_initialtime = 10;
interval_heat = 1;
data = initializeParameters(data, num_initialtime, interval_heat);
data.grid.p_pcc = 10e3;
data.grid.q_pcc = 10e3;

% Define uncertainty parameters
data.uncertainty.Deviation.p_res = 0.2;
data.uncertainty.Deviation.p_load = 0.2;
data.uncertainty.Deviation.Tau_out = 0.2;
data.uncertainty.Deviation.Tau_act = 0.2;
data.uncertainty.Gamma.p_res = 12;
data.uncertainty.Gamma.p_load = 12;
data.uncertainty.Gamma.Tau_out = 12;
data.uncertainty.Gamma.Tau_act = 12;

% Calculate building parameters
delta_alpha = 0;
delta_beta = 0;
set_type = 0;
num_points = 0;
data = calculateBuildingParameters(delta_alpha, delta_beta, set_type, num_points);

%% ==================== Define Variables (Into tro_model directly) ====================
% 1. Define First-Stage Variables
% (Assuming defineBaseVars returns a struct of sdpvars/binvars)
tro_model.var_1st = defineBaseVars();

% 2. Define Second-Stage and Uncertainty Variables
% (Assuming defineSubProblemVars returns two structs)
[tro_model.var_2nd, tro_model.var_uncertain] = defineSubProblemVars();

% Create local aliases for cleaner objective definition below
var_stage1 = tro_model.var_1st;
var_stage2 = tro_model.var_2nd;
var_u = tro_model.var_uncertain;

%% ==================== Define Constraints ====================
% 1. First-Stage Constraints
% (Assuming defineFirstStageConstraints accepts the struct and returns constraint object)
tro_model.cons_1st = defineFirstStageConstraints(var_stage1);

% 2. Second-Stage Constraints
% (Assuming defineSecondStageConstraints accepts the structs and returns constraint object)
tro_model.cons_2nd = defineSecondStageConstraints(var_stage2, var_u, var_stage1);

% 3. Uncertainty Set Constraints
% (Assuming defineUncertaintyConstraints accepts the structs and returns constraint object)
tro_model.cons_uncertainty = defineUncertaintyConstraints(var_u, var_stage2);
% tro_model.cons_uncertainty = []; % Uncomment if no uncertainty constraints

%% ==================== Define Objectives ====================
% Extract cost parameter indices
[loc_devicetype, loc_om, loc_c1, loc_c0] = deal(2, 9, 6, 7); % device cost indices
[loc_gridprice_buy, loc_gridprice_sell] = deal(1, 2); % grid price indices

% Extract device sets
set_es = find(data.device.param(:,loc_devicetype) == 2);
set_tst = find(data.device.param(:,loc_devicetype) == 5);

% --- First-Stage Objective: Investment / O&M of storage ---
obj_1st = 0;
if ~isempty(set_es)
    obj_1st = obj_1st + ...
        sum(sum(var_stage1.es.p_chr(:,:) * data.device.cost(set_es, loc_om))) + ...
        sum(sum(var_stage1.es.p_dis(:,:) * data.device.cost(set_es, loc_om)));
end
if ~isempty(set_tst)
    obj_1st = obj_1st + ...
        sum(sum(var_stage1.tst.h_chr(:,:) * data.device.cost(set_tst, loc_om))) + ...
        sum(sum(var_stage1.tst.h_dis(:,:) * data.device.cost(set_tst, loc_om)));
end
tro_model.obj_1st = obj_1st;

% --- Second-Stage Objective: Operational Costs ---
num_period = data.period;
set_res = find(data.device.param(:,loc_devicetype) == 1);
set_gt = find(data.device.param(:,loc_devicetype) == 3);
set_eb = find(data.device.param(:,loc_devicetype) == 4);

% Grid costs
cost_grid_buy = data.grid.price(loc_gridprice_buy,:)' .* var_stage2.pcc.p(:,1);
cost_grid_sell = data.grid.price(loc_gridprice_sell,:)' .* var_stage2.pcc.p(:,2);

% RES costs
cost_res = 0;
if ~isempty(set_res)
    cost_res = sum(var_stage2.res.p(:,:) * data.device.cost(set_res, loc_c1)) + ...
        sum(ones(num_period, length(set_res)) * data.device.cost(set_res, loc_c0)) + ...
        sum(var_stage2.res.p * data.device.cost(set_res, loc_om));
end

% GT costs
cost_gt = 0;
if ~isempty(set_gt)
    cost_gt = sum(var_stage2.gt.gas * data.device.cost(set_gt, loc_c1)) + ...
        sum(var_stage2.gt.p * data.device.cost(set_gt, loc_om));
end

% EB costs
cost_eb = 0;
if ~isempty(set_eb)
    cost_eb = sum(var_stage2.eb.p * data.device.cost(set_eb, loc_om));
end

% Combine all second-stage costs
tro_model.obj_2nd = sum(cost_grid_buy) - sum(cost_grid_sell) + ...
    cost_res + cost_gt + cost_eb + var_stage2.cost.Tau_in_comp;

%% ==================== Initial Scenario ==================== 
u_init = zeros(3072, 1);

%% ==================== Configure Solver ====================
ops = TROsettings('solver', 'cplex', ...
                        'verbose', 2, ...
                        'gap_tol', 1e-3, ...
                        'max_iterations', 200, ...
                        'mode', 'quick', ...
                        'plot.verbose', 1);

%% ==================== Solve ====================
fprintf('\n%s\n', '---------------------- Start C&CG -----------------------');

% New simplified interface call
[Solution, Robust_record] = solve_TRO(tro_model, ops, u_init);

fprintf('\n%s\n', '---------------------- C&CG Finished --------------------');