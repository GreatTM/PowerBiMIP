function define_subProblemVars(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Define vars of subproblem');
    t0 = clock;
end
%% Data
global data var_2st;
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
var_2st.primal.pcc.p = sdpvar(num_period, 2, 'full');
var_2st.primal.pcc.q = sdpvar(num_period, 2, 'full');
% % branch
var_2st.primal.branch.p = sdpvar(num_period, num_branch, 'full');
var_2st.primal.branch.q = sdpvar(num_period, num_branch, 'full');
% % bus
var_2st.primal.bus.vol_bus = sdpvar(num_period, num_bus,'full');
var_2st.primal.bus.p_bus = sdpvar(num_period, num_bus, 'full');
var_2st.primal.bus.q_bus = sdpvar(num_period, num_bus, 'full');
var_2st.primal.bus.p_res = sdpvar(num_period, num_bus, 'full');
var_2st.primal.bus.p_es = sdpvar(num_period, num_bus, 'full');
var_2st.primal.bus.p_gt = sdpvar(num_period, num_bus, 'full');
var_2st.primal.bus.p_eb = sdpvar(num_period, num_bus, 'full');
var_2st.primal.bus.p_load = sdpvar(num_period, num_bus, 'full');
var_2st.primal.bus.q_load = sdpvar(num_period, num_bus, 'full');

% % device
if ~isempty(set_res)
    var_2st.primal.res.p = sdpvar(num_period, length(set_res), 'full');
    var_2st.primal.res.p_fore = sdpvar(num_period, length(set_res), 'full');
end
if ~isempty(set_es)
    var_2st.primal.es.p_chr = sdpvar(num_period, length(set_es), 'full');
    var_2st.primal.es.p_dis = sdpvar(num_period, length(set_es), 'full');
end
if ~isempty(set_gt)
    var_2st.primal.gt.gas = sdpvar(num_period, length(set_gt), 'full');
    var_2st.primal.gt.p = sdpvar(num_period, length(set_gt), 'full');
    var_2st.primal.gt.h = sdpvar(num_period, length(set_gt), 'full');
end
if ~isempty(set_eb)
    var_2st.primal.eb.p = sdpvar(num_period, length(set_eb), 'full');
    var_2st.primal.eb.h = sdpvar(num_period, length(set_eb), 'full');
end
if ~isempty(set_tst)
    var_2st.primal.tst.h_chr = sdpvar(num_period, length(set_tst), 'full');
    var_2st.primal.tst.h_dis = sdpvar(num_period, length(set_tst), 'full');
end
% % cost
var_2st.primal.cost.grid_buy = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.grid_sell = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.res = sdpvar(num_period, 1, 'full');
% var_2st.primal.cost.es = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.gt = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.eb = sdpvar(num_period, 1, 'full');
% var_2st.primal.cost.tst = sdpvar(num_period, 1, 'full');

%% heating network
var_2st.primal.heatingnetwork.Tau_pipe_s_in = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.primal.heatingnetwork.Tau_pipe_s_out = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.primal.heatingnetwork.Tau_pipe_r_in = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.primal.heatingnetwork.Tau_pipe_r_out = ...
    sdpvar(num_initialtime+num_period, num_pipe, 'full');
var_2st.primal.heatingnetwork.Tau_node_s = ...
    sdpvar(num_initialtime+num_period, num_node, 'full');
var_2st.primal.heatingnetwork.Tau_node_r = ...
    sdpvar(num_initialtime+num_period, num_node, 'full');
var_2st.primal.heatingnetwork.h_source = ...
    sdpvar(num_initialtime+num_period, 1, 'full');
var_2st.primal.heatingnetwork.h_load = ...
    sdpvar(num_initialtime+num_period, num_building, 'full');

%% building
num_extrmpoint = size(data.buildings.uncertainty.alpha,2);
var_2st.primal.building.h_load = ...
    sdpvar(num_period, num_building, 'full');
var_2st.primal.building.Tau_in = ...
    sdpvar(num_period, num_building, 'full');
var_2st.primal.building.Tau_out = ...
    sdpvar(num_period, 1, 'full');
var_2st.primal.building.Tau_in_extrm = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.primal.building.Tau_act = ...
    sdpvar(num_period, num_building, 'full');

var_2st.primal.building.Tau_in_upperdelta_pos = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.primal.building.Tau_in_upperdelta_neg = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.primal.building.Tau_in_lowerdelta_pos = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');
var_2st.primal.building.Tau_in_lowerdelta_neg = ...
    sdpvar(num_period, num_building, num_extrmpoint, 'full');


%% cost
var_2st.primal.cost.grid_buy = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.grid_sell = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.res = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.es = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.gt = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.eb = sdpvar(num_period, 1, 'full');
var_2st.primal.cost.Tau_in_comp = sdpvar(1,1, 'full');

%% uncertainty
var_2st.primal.uncertainty.p_res_pos = sdpvar(num_period, length(set_res), 'full');
var_2st.primal.uncertainty.p_res_neg = sdpvar(num_period, length(set_res), 'full');
var_2st.primal.uncertainty.p_load_pos = sdpvar(num_period, num_bus, 'full');
var_2st.primal.uncertainty.p_load_neg = sdpvar(num_period, num_bus, 'full');
var_2st.primal.uncertainty.Tau_out_pos = sdpvar(num_period, 1, 'full');
var_2st.primal.uncertainty.Tau_out_neg = sdpvar(num_period, 1, 'full');
var_2st.primal.uncertainty.Tau_act_pos = sdpvar(num_period, num_building, 'full');
var_2st.primal.uncertainty.Tau_act_neg = sdpvar(num_period, num_building, 'full');

%%
if DisplayTime
    t1 = clock;
    fprintf('%8.2f%s\n', etime(t1,t0), 's');
end
end