function define_initialScenario(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Initialize scenario');
    t0 = clock;
end
%% 
global data model;
num_period = data.period;
num_building = size(data.buildings.param,1);
model.uncertainty_set = [];
model.uncertainty_set.p_res_pos(1:num_period, 4) = 0;
model.uncertainty_set.p_res_neg(1:num_period, 4) = 0;
model.uncertainty_set.p_load_pos(1:num_period, 33) = 0;
model.uncertainty_set.p_load_neg(1:num_period, 33) = 0;
model.uncertainty_set.Tau_out_pos(1:num_period, 1) = 0;
model.uncertainty_set.Tau_out_neg(1:num_period, 1) = 0;
model.uncertainty_set.Tau_act_pos(1:num_period, num_building) = 0;
model.uncertainty_set.Tau_act_neg(1:num_period, num_building) = 0;
%%
if DisplayTime
    t1 = clock;
    fprintf('%8.2f%s\n', etime(t1,t0), 's');
end
end