function model_BLP_subProblem(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Model BLP sub problem');
    t0 = clock;
end
%%
global data model var_2st big_M;
[loc_profilestype] = deal(2);       % profiles
num_period = data.period;
set_loadpower = find(data.profiles.bus(:,loc_profilestype) == 1);
set_respower = find(data.profiles.bus(:,loc_profilestype) == 2);
num_building = size(data.buildings.param,1);
details = model.sub_problem.details;
%%
model.sub_problem.BLP.sub_problem.cons = [];
model.sub_problem.BLP.sub_problem.obj = 0;
var_2st.BLP.sub_problem = [];
%% Initialize uncertainty
var_2st.BLP.sub_problem.p_res_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_res_pos;
var_2st.BLP.sub_problem.p_res_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_res_neg;
var_2st.BLP.sub_problem.p_load_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_load_pos;
var_2st.BLP.sub_problem.p_load_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_load_neg;
var_2st.BLP.sub_problem.Tau_out_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_out_pos;
var_2st.BLP.sub_problem.Tau_out_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_out_neg;
var_2st.BLP.sub_problem.Tau_act_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_act_pos;
var_2st.BLP.sub_problem.Tau_act_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_act_neg;
% % p_res
var_2st.BLP.sub_problem.p_res = data.profiles.data(set_respower, :)' .* ...
    ( 1 + ...
    data.uncertainty.Deviation.p_res * var_2st.BLP.sub_problem.p_res_pos - ...
    data.uncertainty.Deviation.p_res * var_2st.BLP.sub_problem.p_res_neg); 
% % p_load
var_2st.BLP.sub_problem.p_load = data.profiles.data(set_loadpower,:)' .* ...
    ( 1 + ...
    data.uncertainty.Deviation.p_load * var_2st.BLP.sub_problem.p_load_pos - ...
    data.uncertainty.Deviation.p_load * var_2st.BLP.sub_problem.p_load_neg);
% % Tau_out
var_2st.BLP.sub_problem.Tau_out = data.buildings.Tau_out .* ...
    ( 1 + ...
    data.uncertainty.Deviation.Tau_out * var_2st.BLP.sub_problem.Tau_out_pos - ...
    data.uncertainty.Deviation.Tau_out * var_2st.BLP.sub_problem.Tau_out_neg);
% % Tau_act
var_2st.BLP.sub_problem.Tau_act = data.buildings.Tau_act' .* ...
    ( 1 + ...
    data.uncertainty.Deviation.Tau_act * var_2st.BLP.sub_problem.Tau_act_pos - ...
    data.uncertainty.Deviation.Tau_act * var_2st.BLP.sub_problem.Tau_act_neg);

%% Dual constraints
f_start_res = 7441; f_end_res= 7536;            % 7441   7536
f_start_load = 7537; f_end_load = 8328;         % 7537   8328
f_start_Tau_out = 17815; f_end_Tau_out = 17838;         % 17815  17838
f_start_Tau_act = 17839; f_end_Tau_act = 18462; % 17839  18462
for i = 1:length(set_respower)
    index_res(:,i) = f_start_res + num_period*(i-1) : f_start_res+num_period*i-1;
end
for i = 1:length(set_loadpower)
    index_load(:,i) = f_start_load + num_period*(i-1) : f_start_load+num_period*i-1;
end
index_Tau_out = f_start_Tau_out:f_end_Tau_out;
for i = 1:num_building
    index_Tau_act(:,i) = f_start_Tau_act + num_period*(i-1) : f_start_Tau_act+num_period*i-1;    
end
var_2st.BLP.sub_problem.dual_nu = sdpvar(length(details.b),1,'full');
var_2st.BLP.sub_problem.dual_lambda = sdpvar(length(details.f),1,'full');
model.sub_problem.BLP.sub_problem.cons = ...
    model.sub_problem.BLP.sub_problem.cons + ( ...
    (-big_M <= var_2st.BLP.sub_problem.dual_nu <= 0) : '');
model.sub_problem.BLP.sub_problem.cons = ...
    model.sub_problem.BLP.sub_problem.cons + ( ...
    (-big_M <= var_2st.BLP.sub_problem.dual_lambda <= big_M) : '');
% % dual_nu'*A + dual_lambda'*E == c'
model.sub_problem.BLP.sub_problem.cons = ...
    model.sub_problem.BLP.sub_problem.cons + ( ...
    (details.A'*var_2st.BLP.sub_problem.dual_nu + ...
    details.E'*var_2st.BLP.sub_problem.dual_lambda == ...
    details.c) : '');

%% details.f
for i = 1:length(set_respower)
    details.f(index_res(:,i),1) = -var_2st.BLP.sub_problem.p_res(:,i);
end
for i = 1:length(set_loadpower)
    details.f(index_load(:,i),1) = -var_2st.BLP.sub_problem.p_load(:,i);
end
details.f(index_Tau_out,1) = -var_2st.BLP.sub_problem.Tau_out;
for i = 1:num_building
    details.f(index_Tau_act(:,i),1) = -var_2st.BLP.sub_problem.Tau_act(:,i);
end
%% Obj
model.sub_problem.BLP.sub_problem.obj = ...
    var_2st.BLP.sub_problem.dual_nu'*details.b + ...
    var_2st.BLP.sub_problem.dual_lambda'*details.f;

%%
var_2st.BLP.sub_problem.details = details;

% figure(1);
% subplot(3,1,1);
% plot(sum(var_2st.BLP.sub_problem.p_res,2)); hold on;
% subplot(3,1,2);
% plot(sum(var_2st.BLP.sub_problem.p_load,2)); hold on;
% subplot(3,1,3);
% plot(var_2st.BLP.sub_problem.Tau_out); hold on;

%%
if DisplayTime
    t1 = clock;
    fprintf('%8.2f%s\n', etime(t1,t0), 's');
end
end