function [var_2st, var_u] = defineSubProblemVars()
%DEFINESUBPROBLEMVARS Define second-stage and uncertainty variables
%
%   This function is refactored from examples/original_code/define_subProblemVars.m
%   with global variables removed.
%
%   Inputs:
%       data - Data structure
%       var_struct - Variable structure (may contain base variables)
%
%   Outputs:
%       var_struct - Updated variable structure with primal (second-stage) variables
%       var_u - Uncertainty variables structure
global data
[loc_devicetype] = deal(2);
num_period = data.period;
num_initialtime = data.num_initialtime;
num_bus = size(data.grid.bus,1);
num_branch = size(data.grid.branch,1);
set_res = find(data.device.param(:,loc_devicetype) == 1);
set_es = find(data.device.param(:,loc_devicetype) == 2);
set_gt = find(data.device.param(:,loc_devicetype) == 3);
set_eb = find(data.device.param(:,loc_devicetype) == 4);
set_tst = find(data.device.param(:,loc_devicetype) == 5);
num_pipe = size(data.heatingnetwork.pipe,1);
num_node = size(data.heatingnetwork.node,1);
num_building = size(data.buildings.param,1);

%% Vars
%% grid
% % pcc
var_2st.pcc.p = sdpvar(num_period, 2, 'full');
var_2st.pcc.q = sdpvar(num_period, 2, 'full');
% % branch
var_2st.branch.p = sdpvar(num_period, num_branch, 'full');
var_2st.branch.q = sdpvar(num_period, num_branch, 'full');
% % bus
var_2st.bus.vol_bus = sdpvar(num_period, num_bus,'full');
var_2st.bus.p_bus = sdpvar(num_period, num_bus, 'full');
var_2st.bus.q_bus = sdpvar(num_period, num_bus, 'full');
var_2st.bus.p_res = sdpvar(num_period, num_bus, 'full');
var_2st.bus.p_es = sdpvar(num_period, num_bus, 'full');
var_2st.bus.p_gt = sdpvar(num_period, num_bus, 'full');
var_2st.bus.p_eb = sdpvar(num_period, num_bus, 'full');
var_2st.bus.p_load = sdpvar(num_period, num_bus, 'full');
var_2st.bus.q_load = sdpvar(num_period, num_bus, 'full');

% % device
% res
if ~isempty(set_res)
    var_2st.res.p = sdpvar(num_period, length(set_res), 'full');
    var_2st.res.p_fore = sdpvar(num_period, length(set_res), 'full');
end
% es
if ~isempty(set_es)
    var_2st.es.p_chr = sdpvar(num_period, length(set_es), 'full');
    var_2st.es.p_dis = sdpvar(num_period, length(set_es), 'full');
end
% gt
if ~isempty(set_gt)
    var_2st.gt.gas = sdpvar(num_period, length(set_gt), 'full');
    var_2st.gt.p = sdpvar(num_period, length(set_gt), 'full');
    var_2st.gt.h = sdpvar(num_period, length(set_gt), 'full');
end
% eb
if ~isempty(set_eb)
    var_2st.eb.p = sdpvar(num_period, length(set_eb), 'full');
    var_2st.eb.h = sdpvar(num_period, length(set_eb), 'full');
end
% tst
if ~isempty(set_tst)
    var_2st.tst.h_chr = sdpvar(num_period, length(set_tst), 'full');
    var_2st.tst.h_dis = sdpvar(num_period, length(set_tst), 'full');
end
% % cost
var_2st.cost.grid_buy = sdpvar(num_period, 1, 'full');
var_2st.cost.grid_sell = sdpvar(num_period, 1, 'full');
var_2st.cost.res = sdpvar(num_period, 1, 'full');
% var_struct.primal.cost.es = sdpvar(num_period, 1, 'full');
var_2st.cost.gt = sdpvar(num_period, 1, 'full');
var_2st.cost.eb = sdpvar(num_period, 1, 'full');
% var_struct.primal.cost.tst = sdpvar(1,1, 'full');

%% heating network
var_2st.heatingnetwork.Tau_pipe_s_in = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.heatingnetwork.Tau_pipe_s_out = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.heatingnetwork.Tau_pipe_r_in = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.heatingnetwork.Tau_pipe_r_out = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.heatingnetwork.Tau_node_s = ...
    sdpvar(num_initialtime+num_period, num_node, 'full');
var_2st.heatingnetwork.Tau_node_r = ...
    sdpvar(num_initialtime+num_period, num_node, 'full');
var_2st.heatingnetwork.h_source = ...
    sdpvar(num_initialtime+num_period, 1, 'full');
var_2st.heatingnetwork.h_load = ...
    sdpvar(num_initialtime+num_period, num_building, 'full');

%% building
num_extrmpoint = size(data.buildings.uncertainty.alpha,2);
var_2st.building.h_load = ...
    sdpvar(num_period, num_building, 'full');
var_2st.building.Tau_in = ...
    sdpvar(num_period, num_building, 'full');
var_2st.building.Tau_out = ...
    sdpvar(num_period, 1, 'full');
var_2st.building.Tau_in_extrm = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.building.Tau_act = ...
    sdpvar(num_period, num_building, 'full');

var_2st.building.Tau_in_upperdelta_pos = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.building.Tau_in_upperdelta_neg = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.building.Tau_in_lowerdelta_pos = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.building.Tau_in_lowerdelta_neg = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');

%% cost
var_2st.cost.grid_buy = sdpvar(num_period, 1, 'full');
var_2st.cost.grid_sell = sdpvar(num_period, 1, 'full');
var_2st.cost.res = sdpvar(num_period, 1, 'full');
var_2st.cost.es = sdpvar(num_period, 1, 'full');
var_2st.cost.gt = sdpvar(num_period, 1, 'full');
var_2st.cost.eb = sdpvar(num_period, 1, 'full');
var_2st.cost.Tau_in_comp = sdpvar(1,1, 'full');

%% uncertainty
var_u.p_res_pos = sdpvar(num_period, length(set_res), 'full');
var_u.p_res_neg = sdpvar(num_period, length(set_res), 'full');
var_u.p_load_pos = sdpvar(num_period, num_bus, 'full');
var_u.p_load_neg = sdpvar(num_period, num_bus, 'full');
var_u.Tau_out_pos = sdpvar(num_period, 1, 'full');
var_u.Tau_out_neg = sdpvar(num_period, 1, 'full');
var_u.Tau_act_pos = sdpvar(num_period, num_building, 'full');
var_u.Tau_act_neg = sdpvar(num_period, num_building, 'full');

end

