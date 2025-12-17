clc, clear all;
warning off;
data_update = 0;
%%
if data_update && exist([cd '\mydata.mat'])
    delete('mydata.mat'); 
end
global data var_1st var_2st model big_M big_M_Tau_in;
data = []; model = []; var_1st = []; var_2st = [];
%%
ReadData();
myIntialize(10, 1);    % num_initialtime=10, interval_heat=1
data.grid.p_pcc = 10e3; data.grid.q_pcc = 10e3;
define_uncertaintyParam(0.2, 0.2, 0.2, 0.2, 12, 12, 12, 12); % deviation, Gamma: res, load, Tau_out, Tau_act
cal_buildingParam(0, 0, 0, 0); % delta_alpha, delta_beta, type: 0-X0; 1-X1; 2-X1:nPoint
%% 
model.LowerBound = [];
model.UpperBound = [];
model.main_problem.num_iter = [];
big_M = 1e6;
big_M_Tau_in = 1e6;
Max_iter = 200;
num_iter = 1;
flag_convergence = 0;
fprintf('%s\n', '---------------------- Start C&CG -----------------------');
while num_iter <= Max_iter && ~flag_convergence
    fprintf('%s%2d%s\n', '----------------------- Iter:  ', num_iter, ' -----------------------');
    fprintf('%s\n', 'Main problem:');
    if num_iter == 1
        define_initialScenario();
    end
    %% main problem
    model_mainProblem();
    solve_mainProblem();
    getValue('var_1st');
    model.LowerBound = [model.LowerBound value(model.main_problem.obj)];
    
    %% sub problem
    fprintf('\n%s\n', 'Sub problem:');
    model_subProblem();
    model.UpperBound = [model.UpperBound model.sub_problem.BLP.UpperBound(end)+var_1st.base.cost_base];
    
    %% covergence
    delta_bound = (min(model.UpperBound)-model.LowerBound(end))/min(model.UpperBound);
    fprintf('\n%-40s\t\t%8.2f%s\n\n', '(UB-LB)/UB:  ', ...
        100*delta_bound, '%');
    if delta_bound < 1e-3
        flag_convergence = 1;
    end
    %%
    add_uncertainty_set(num_iter);
    model.main_problem.num_iter = num_iter;
    num_iter = num_iter + 1;
end
save 'results.mat';
load chirp;
sound(y, Fs);
str = [num2str(year(now)) '-' num2str(month(now)) '-' num2str(day(now)) ' ' ...
    num2str(hour(now)) ':' num2str(minute(now)) ':' num2str(floor(second(now)))];
% SendMail('Programming Finished!', str);
%% -------------------- add_uncertainty_set ------------------------
function add_uncertainty_set(num_iter)
global model;
model.uncertainty_set(num_iter+1).p_res_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_res_pos;
model.uncertainty_set(num_iter+1).p_res_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_res_neg;
model.uncertainty_set(num_iter+1).p_load_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_load_pos;
model.uncertainty_set(num_iter+1).p_load_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.p_load_neg;
model.uncertainty_set(num_iter+1).Tau_out_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_out_pos;
model.uncertainty_set(num_iter+1).Tau_out_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_out_neg;
model.uncertainty_set(num_iter+1).Tau_act_pos = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_act_pos;
model.uncertainty_set(num_iter+1).Tau_act_neg = ...
    model.sub_problem.BLP.scenario(end).uncertainty.Tau_act_neg;
end