%TRO_IES_EXAMPLE Two-stage robust optimization for Integrated Energy System
%
%   This example demonstrates how to use solve_Robust to solve a complex
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
%       Run this script to solve the TRO-IES problem using solve_Robust.
%
%   See also: solve_Robust, RobustCCGsettings

clc; clear all; close all;
dbstop if error
global data
%% ==================== Data Reading and Initialization ====================
fprintf('%-40s\t\t', '- Reading data');
% Read data
data = readData();

% Initialize parameters
fprintf('%-40s\t\t','- Initialize parameters');
num_initialtime = 10;
interval_heat = 1;
data = initializeParameters(data, num_initialtime, interval_heat);
data.grid.p_pcc = 10e3;
data.grid.q_pcc = 10e3;

% Define uncertainty parameters
fprintf('%-40s\t\t','- Define uncertainty parameters');
data.uncertainty.Deviation.p_res = 0.2;
data.uncertainty.Deviation.p_load = 0.2;
data.uncertainty.Deviation.Tau_out = 0.2;
data.uncertainty.Deviation.Tau_act = 0.2;
data.uncertainty.Gamma.p_res = 12;
data.uncertainty.Gamma.p_load = 12;
data.uncertainty.Gamma.Tau_out = 12;
data.uncertainty.Gamma.Tau_act = 12;

% Calculate building parameters
fprintf('%-40s\t\t','- Calculate building parameters');
delta_alpha = 0;
delta_beta = 0;
set_type = 0;
num_points = 0;
data = calculateBuildingParameters(delta_alpha, delta_beta, set_type, num_points);

%% ==================== Define Variables ====================
fprintf('%-40s\t\t','- Define variables');
var = struct();
% Define first-stage variables (from define_baseVars.m)
model.var.var_stage1 = defineBaseVars();

% Define second-stage and uncertainty variables (from define_subProblemVars.m)
[model.var.var_stage2, model.var.var_u] = defineSubProblemVars();

%% ==================== Define Constraints ====================
fprintf('%-40s\t\t','- Define constraints');

% First-stage constraints (from model_grid_1st.m, model_heatingnetwork_1st.m, model_building_1st.m)
model.cons_1st = defineFirstStageConstraints(model.var.var_stage1);

% Second-stage constraints (from model_grid_2st.m, model_heatingwork_2st.m, model_building_2st.m, model_coupling_1st.m)
model.cons_2nd = defineSecondStageConstraints(model.var.var_stage2, model.var.var_u, model.var.var_stage1);

% Uncertainty set constraints (from define_uncertaintyParam.m)
model.cons_uncertainty = defineUncertaintyConstraints(model.var.var_u, model.var.var_stage2);
% model.cons_uncertainty = [];

%% ==================== Define Objectives ====================
fprintf('%-40s\t\t','- Define objectives');

% Extract cost parameter indices
[loc_devicetype, loc_om, loc_c1, loc_c0] = deal(2, 9, 6, 7); % device cost indices
[loc_gridprice_buy, loc_gridprice_sell] = deal(1, 2); % grid price indices

% Extract device sets
set_es = find(data.device.param(:,loc_devicetype) == 2);
set_tst = find(data.device.param(:,loc_devicetype) == 5);

% First-stage objective: ES and TST operation and maintenance costs
model.obj_1st = 0;
if ~isempty(set_es)
    model.obj_1st = model.obj_1st + ...
        sum(sum(model.var.var_stage1.es.p_chr(:,:) * data.device.cost(set_es, loc_om))) + ...
        sum(sum(model.var.var_stage1.es.p_dis(:,:) * data.device.cost(set_es, loc_om)));
end

if ~isempty(set_tst)
    model.obj_1st = model.obj_1st + ...
        sum(sum(model.var.var_stage1.tst.h_chr(:,:) * data.device.cost(set_tst, loc_om))) + ...
        sum(sum(model.var.var_stage1.tst.h_dis(:,:) * data.device.cost(set_tst, loc_om)));
end

% Second-stage objective: grid, RES, GT, EB costs, and building temperature compensation
num_period = data.period;
set_res = find(data.device.param(:,loc_devicetype) == 1);
set_gt = find(data.device.param(:,loc_devicetype) == 3);
set_eb = find(data.device.param(:,loc_devicetype) == 4);

% Grid costs
cost_grid_buy = data.grid.price(loc_gridprice_buy,:)' .* model.var.var_stage2.pcc.p(:,1);
cost_grid_sell = data.grid.price(loc_gridprice_sell,:)' .* model.var.var_stage2.pcc.p(:,2);

% RES costs
cost_res = 0;
if ~isempty(set_res)
    cost_res = sum(model.var.var_stage2.res.p(:,:) * data.device.cost(set_res, loc_c1)) + ...
        sum(ones(num_period, length(set_res)) * data.device.cost(set_res, loc_c0)) + ...
        sum(model.var.var_stage2.res.p * data.device.cost(set_res, loc_om));
end

% GT costs
cost_gt = 0;
if ~isempty(set_gt)
    cost_gt = sum(model.var.var_stage2.gt.gas * data.device.cost(set_gt, loc_c1)) + ...
        sum(model.var.var_stage2.gt.p * data.device.cost(set_gt, loc_om));
end

% EB costs
cost_eb = 0;
if ~isempty(set_eb)
    cost_eb = sum(model.var.var_stage2.eb.p * data.device.cost(set_eb, loc_om));
end

% Combine all second-stage costs
model.obj_2nd = sum(cost_grid_buy) - sum(cost_grid_sell) + ...
    cost_res + cost_gt + cost_eb + model.var.var_stage2.cost.Tau_in_comp;
% model.obj_2nd = sum(cost_grid_buy) - sum(cost_grid_sell) + ...
%     cost_res + cost_gt + cost_eb;

%% ==================== Prepare Variables for solve_Robust ====================
fprintf('%-40s\t\t','- Prepare variables for solve_Robust');

% Combine first-stage variables into vectors
var_x_1st = [];
var_z_1st = [];

% Extract binary variables (z)
if isfield(model.var.var_stage1, 'pcc')
    var_z_1st = [var_z_1st; model.var.var_stage1.pcc.p_state(:); model.var.var_stage1.pcc.q_state(:)];
end
if isfield(model.var.var_stage1, 'es')
    var_z_1st = [var_z_1st; model.var.var_stage1.es.p_chr_state(:); model.var.var_stage1.es.p_dis_state(:)];
end
if isfield(model.var.var_stage1, 'gt')
    var_z_1st = [var_z_1st; model.var.var_stage1.gt.state(:)];
end
if isfield(model.var.var_stage1, 'tst')
    var_z_1st = [var_z_1st; model.var.var_stage1.tst.h_chr_state(:); model.var.var_stage1.tst.h_dis_state(:)];
end

% Extract continuous variables (x) - excluding cost variables
if isfield(model.var.var_stage1, 'es')
    var_x_1st = [var_x_1st; model.var.var_stage1.es.p_chr(:); model.var.var_stage1.es.p_dis(:); model.var.var_stage1.es.soc(:)];
end
if isfield(model.var.var_stage1, 'tst')
    var_x_1st = [var_x_1st; model.var.var_stage1.tst.h_chr(:); model.var.var_stage1.tst.h_dis(:); model.var.var_stage1.tst.soc(:)];
end

% Combine second-stage variables into vector
var_x_2nd = [];
var_x_2nd = [var_x_2nd; model.var.var_stage2.pcc.p(:); model.var.var_stage2.pcc.q(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.branch.p(:); model.var.var_stage2.branch.q(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.bus.vol_bus(:); model.var.var_stage2.bus.p_bus(:); model.var.var_stage2.bus.q_bus(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.bus.p_res(:); model.var.var_stage2.bus.p_es(:); model.var.var_stage2.bus.p_gt(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.bus.p_eb(:); model.var.var_stage2.bus.p_load(:); model.var.var_stage2.bus.q_load(:)];

if isfield(model.var.var_stage2, 'res')
    var_x_2nd = [var_x_2nd; model.var.var_stage2.res.p(:); model.var.var_stage2.res.p_fore(:)];
end
if isfield(model.var.var_stage2, 'es')
    var_x_2nd = [var_x_2nd; model.var.var_stage2.es.p_chr(:); model.var.var_stage2.es.p_dis(:)];
end
if isfield(model.var.var_stage2, 'gt')
    var_x_2nd = [var_x_2nd; model.var.var_stage2.gt.gas(:); model.var.var_stage2.gt.p(:); model.var.var_stage2.gt.h(:)];
end
if isfield(model.var.var_stage2, 'eb')
    var_x_2nd = [var_x_2nd; model.var.var_stage2.eb.p(:); model.var.var_stage2.eb.h(:)];
end
if isfield(model.var.var_stage2, 'tst')
    var_x_2nd = [var_x_2nd; model.var.var_stage2.tst.h_chr(:); model.var.var_stage2.tst.h_dis(:)];
end

var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.Tau_pipe_s_in(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.Tau_pipe_s_out(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.Tau_pipe_r_in(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.Tau_pipe_r_out(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.Tau_node_s(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.Tau_node_r(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.h_source(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.heatingnetwork.h_load(:)];

var_x_2nd = [var_x_2nd; model.var.var_stage2.building.h_load(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_in(:)];
var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_out(:)];
if isfield(model.var.var_stage2.building, 'Tau_in_extrm')
    var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_in_extrm(:)];
end
var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_act(:)];
if isfield(model.var.var_stage2.building, 'Tau_in_upperdelta_pos')
    var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_in_upperdelta_pos(:)];
    var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_in_upperdelta_neg(:)];
    var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_in_lowerdelta_pos(:)];
    var_x_2nd = [var_x_2nd; model.var.var_stage2.building.Tau_in_lowerdelta_neg(:)];
end
var_x_2nd = [var_x_2nd; model.var.var_stage2.cost.Tau_in_comp(:)];

% No second-stage integer variables for TRO-LP
var_z_2nd = [];

% Combine uncertainty variables into vector
var_u = [model.var.var_u.p_res_pos(:); model.var.var_u.p_res_neg(:)];
var_u = [var_u; model.var.var_u.p_load_pos(:); model.var.var_u.p_load_neg(:)];
var_u = [var_u; model.var.var_u.Tau_out_pos(:); model.var.var_u.Tau_out_neg(:)];
var_u = [var_u; model.var.var_u.Tau_act_pos(:); model.var.var_u.Tau_act_neg(:)];

% Original variable struct (preserves all user-defined fields)
original_var = model.var;

%% ==================== Initial Scenario ====================
% Uncertainty variables are deviations, initial scenario sets all deviations to 0
u_init = zeros(size(var_u));

%% ==================== Configure Solver ====================
ops = RobustCCGsettings('solver', 'gurobi', 'verbose', 4, 'gap_tol', 1e-3, 'max_iterations', 200, 'mode', 'quick');

%% ==================== Solve ====================
fprintf('\n%s\n', '---------------------- Start C&CG -----------------------');
[Solution, Robust_record] = solve_Robust(original_var, var_x_1st, var_z_1st, ...
    var_x_2nd, var_z_2nd, var_u, model.cons_1st, model.cons_2nd, model.cons_uncertainty, ...
    model.obj_1st, model.obj_2nd, ops, u_init);

%% ==================== Display Results ====================
fprintf('\n%s\n', '---------------------- Results -----------------------');
fprintf('Optimal objective value: %.4f\n', Solution.obj);
fprintf('Total iterations: %d\n', Robust_record.cuts_count);
fprintf('Total runtime: %.2f seconds\n', Robust_record.runtime);

fprintf('\n%s\n', '---------------------- Finished -----------------------');

