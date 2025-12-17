function define_recourseVars(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Define recourse vars');
    t0 = clock;
end
%% Data
global data var_1st model;
[loc_devicetype] = deal(2);
num_period = data.period;
num_initialtime = data.num_initialtime;
num_scenario = length(model.uncertainty_set);
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
var_1st.recourse = [];
for i = 1:num_scenario
    %% grid
    % % pcc
    var_1st.recourse(i).pcc.p = sdpvar(num_period, 2, 'full');
    var_1st.recourse(i).pcc.q = sdpvar(num_period, 2, 'full');
    % % branch
    var_1st.recourse(i).branch.p = sdpvar(num_period, num_branch, 'full');
    var_1st.recourse(i).branch.q = sdpvar(num_period, num_branch, 'full');
    % % bus
    var_1st.recourse(i).bus.vol_bus = sdpvar(num_period, num_bus,'full');
    var_1st.recourse(i).bus.p_bus = sdpvar(num_period, num_bus, 'full');
    var_1st.recourse(i).bus.q_bus = sdpvar(num_period, num_bus, 'full');
    var_1st.recourse(i).bus.p_res = sdpvar(num_period, num_bus, 'full');
    var_1st.recourse(i).bus.p_es = sdpvar(num_period, num_bus, 'full');
    var_1st.recourse(i).bus.p_gt = sdpvar(num_period, num_bus, 'full');
    var_1st.recourse(i).bus.p_eb = sdpvar(num_period, num_bus, 'full');
    var_1st.recourse(i).bus.p_load = sdpvar(num_period, num_bus, 'full');
    var_1st.recourse(i).bus.q_load = sdpvar(num_period, num_bus, 'full');
    
    % % device
    % % res
    if ~isempty(set_res)
        var_1st.recourse(i).res.p = sdpvar(num_period, length(set_res), 'full');
        var_1st.recourse(i).res.p_fore = sdpvar(num_period, length(set_res), 'full');
    end
    % % es
    if ~isempty(set_es)
%         var_1st.recourse(i).es.p_chr = sdpvar(num_period, length(set_es), 'full');
%         var_1st.recourse(i).es.p_dis = sdpvar(num_period, length(set_es), 'full');
%         var_1st.recourse(i).es.soc = sdpvar(num_period, length(set_es), 'full');
    end
    % % tst
    if ~isempty(set_es)
%         var_1st.recourse(i).tst.h_chr = sdpvar(num_period, length(set_tst), 'full');
%         var_1st.recourse(i).tst.h_dis = sdpvar(num_period, length(set_tst), 'full');
%         var_1st.recourse(i).tst.soc = sdpvar(num_period, length(set_tst), 'full');
    end
    % % gt
    if ~isempty(set_gt)
        var_1st.recourse(i).gt.gas = sdpvar(num_period, length(set_gt), 'full');
        var_1st.recourse(i).gt.p = sdpvar(num_period, length(set_gt), 'full');
        var_1st.recourse(i).gt.h = sdpvar(num_period, length(set_gt), 'full');
    end
    % % eb
    if ~isempty(set_eb)
        var_1st.recourse(i).eb.p = sdpvar(num_period, length(set_eb), 'full');
        var_1st.recourse(i).eb.h = sdpvar(num_period, length(set_eb), 'full');
    end
    % % cost
    var_1st.recourse(i).cost.grid_buy = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.grid_sell = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.res = sdpvar(num_period, 1, 'full');
%     var_1st.recourse(i).cost.es = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.gt = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.eb = sdpvar(num_period, 1, 'full');
%     var_1st.recourse(i).cost.tst = sdpvar(num_period, 1, 'full');
    %% heating network
    var_1st.recourse(i).heatingnetwork.Tau_pipe_s_in = ...
        sdpvar(num_initialtime+num_period, num_pipe, 'full');
    var_1st.recourse(i).heatingnetwork.Tau_pipe_s_out = ...
        sdpvar(num_initialtime+num_period, num_pipe, 'full');
    var_1st.recourse(i).heatingnetwork.Tau_pipe_r_in = ...
        sdpvar(num_initialtime+num_period, num_pipe, 'full');
    var_1st.recourse(i).heatingnetwork.Tau_pipe_r_out = ...
        sdpvar(num_initialtime+num_period, num_pipe, 'full');
    var_1st.recourse(i).heatingnetwork.Tau_node_s = ...
        sdpvar(num_initialtime+num_period, num_node, 'full');
    var_1st.recourse(i).heatingnetwork.Tau_node_r = ...
        sdpvar(num_initialtime+num_period, num_node, 'full');
    var_1st.recourse(i).heatingnetwork.h_source = ...
        sdpvar(num_initialtime+num_period, 1, 'full');
    var_1st.recourse(i).heatingnetwork.h_load = ...
        sdpvar(num_initialtime+num_period, num_building, 'full');
    
    %% building
    num_extrmpoint = size(data.buildings.uncertainty.alpha,2);
    var_1st.recourse(i).building.h_load = ...
        sdpvar(num_period, num_building, 'full');
    var_1st.recourse(i).building.Tau_in = ...
        sdpvar(num_period, num_building, 'full');
    var_1st.recourse(i).building.Tau_out = ...
        sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).building.Tau_in_extrm = ...
        sdpvar(num_period, num_building, num_extrmpoint, 'full');
    var_1st.recourse(i).building.Tau_act = ...
        sdpvar(num_period, num_building, 'full');
    
    var_1st.recourse(i).building.Tau_in_upperdelta_pos = ...
        sdpvar(num_period, num_building, num_extrmpoint, 'full');
    var_1st.recourse(i).building.Tau_in_upperdelta_neg = ...
        sdpvar(num_period, num_building, num_extrmpoint, 'full');
    var_1st.recourse(i).building.Tau_in_lowerdelta_pos = ...
        sdpvar(num_period, num_building, num_extrmpoint, 'full');
    var_1st.recourse(i).building.Tau_in_lowerdelta_neg = ...
        sdpvar(num_period, num_building, num_extrmpoint, 'full');
    
    %% cost
    var_1st.recourse(i).cost.grid_buy = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.grid_sell = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.res = sdpvar(num_period, 1, 'full');
%     var_1st.recourse(i).cost.es = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.gt = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost.eb = sdpvar(num_period, 1, 'full');
    var_1st.recourse(i).cost_sum = sdpvar(1,1, 'full');
    
    var_1st.recourse(i).cost.Tau_in_comp = sdpvar(1, 1,'full');
end

%%
if DisplayTime
    t1 = clock;
    fprintf('%8.2f%s\n', etime(t1,t0), 's');
end
end