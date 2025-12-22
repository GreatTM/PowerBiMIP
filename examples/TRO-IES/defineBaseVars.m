function var_1st = defineBaseVars()
%DEFINEBASEVARS Define first-stage (base) variables
%
%   This function is refactored from examples/original_code/define_baseVars.m
%   with global variables removed.
global data
[loc_devicetype] = deal(2);
num_period = data.period;
set_res = find(data.device.param(:,loc_devicetype) == 1);
set_es = find(data.device.param(:,loc_devicetype) == 2);
set_gt = find(data.device.param(:,loc_devicetype) == 3);
set_eb = find(data.device.param(:,loc_devicetype) == 4);
set_tst = find(data.device.param(:,loc_devicetype) == 5);
num_pipe = size(data.heatingnetwork.pipe,1);
num_node = size(data.heatingnetwork.node,1);
num_building = size(data.buildings.param,1);

%% Vars
var_1st = [];
%% grid
% % pcc
var_1st.pcc.p_state = binvar(num_period, 2, 'full');
var_1st.pcc.q_state = binvar(num_period, 2, 'full');
% % % es
if ~isempty(set_es)
    var_1st.es.p_chr_state = binvar(num_period, length(set_es), 'full');
    var_1st.es.p_dis_state = binvar(num_period, length(set_es), 'full');
    var_1st.es.p_chr = sdpvar(num_period, length(set_es), 'full');
    var_1st.es.p_dis = sdpvar(num_period, length(set_es), 'full');
    var_1st.es.soc = sdpvar(num_period, length(set_es), 'full');
end
% %  gt
if ~isempty(set_gt)
    var_1st.gt.state = binvar(num_period, length(set_gt), 'full');
end
% % tst
if ~isempty(set_tst)
    var_1st.tst.h_chr_state = binvar(num_period, length(set_tst), 'full');
    var_1st.tst.h_dis_state = binvar(num_period, length(set_tst), 'full');
    var_1st.tst.h_chr = sdpvar(num_period, length(set_tst), 'full');
    var_1st.tst.h_dis = sdpvar(num_period, length(set_tst), 'full');
    var_1st.tst.soc = sdpvar(num_period, length(set_tst), 'full');
end
var_1st.cost = sdpvar(1,1, 'full');
var_1st.cost_es = sdpvar(num_period, 1, 'full');
var_1st.cost_tst = sdpvar(num_period, 1, 'full');
var_1st.cost_base = sdpvar(1,1, 'full');
var_1st.cost_recourse = sdpvar(1,1, 'full');

end

