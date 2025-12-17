function model_dualProblem_OA(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Model dual problem (outer approximation)');
    t0 = clock;
end
%%
global data model var_2st;
big_M = 1e6;
[loc_profilestype] = deal(2);       % profiles
num_period = data.period;
num_building = size(data.buildings.param,1);
set_loadpower = find(data.profiles.bus(:,loc_profilestype) == 1);
set_respower = find(data.profiles.bus(:,loc_profilestype) == 2);
details = model.sub_problem.details;
%% Initial
model.sub_problem.BLP.LowerBound = [];
model.sub_problem.BLP.UpperBound = [];
model.sub_problem.BLP.scenario = [];
%%
model.sub_problem.BLP.scenario.uncertainty.p_res_pos = ...
    model.uncertainty_set(end).p_res_pos;
model.sub_problem.BLP.scenario.uncertainty.p_res_neg = ...
    model.uncertainty_set(end).p_res_neg;
model.sub_problem.BLP.scenario.uncertainty.p_load_pos = ...
    model.uncertainty_set(end).p_load_pos;
model.sub_problem.BLP.scenario.uncertainty.p_load_neg = ...
    model.uncertainty_set(end).p_load_neg;
model.sub_problem.BLP.scenario.uncertainty.Tau_out_pos = ...
    model.uncertainty_set(end).Tau_out_pos;
model.sub_problem.BLP.scenario.uncertainty.Tau_out_neg = ...
    model.uncertainty_set(end).Tau_out_neg;
model.sub_problem.BLP.scenario.uncertainty.Tau_act_pos = ...
    model.uncertainty_set(end).Tau_act_pos;
model.sub_problem.BLP.scenario.uncertainty.Tau_act_neg = ...
    model.uncertainty_set(end).Tau_act_neg;
%%
Max_iter = 200;
num_iter = 1;
flag_convergence = 0;
flag_unbounded = 0;
while num_iter < Max_iter && ~flag_convergence && ~flag_unbounded
    fprintf('%s%2d%s\n', '-------- Iter:  ', num_iter, ' --------');
    %% sub problem
    model_BLP_subProblem();
    solve_BLP_subProblem();
    getValue('var_2st');
    add_scenario_lambda();
    model.sub_problem.BLP.LowerBound = ...
        [model.sub_problem.BLP.LowerBound ...
        value(model.sub_problem.BLP.sub_problem.obj)];
    
    %% main problem
    model_BLP_mainProblem();
    solve_BLP_mainProblem();
    getValue('var_2st');
    add_scenario_uncertainty();
    model.sub_problem.BLP.UpperBound = ...
        [model.sub_problem.BLP.UpperBound ...
        value(model.sub_problem.BLP.main_problem.obj)];
    %% covergence
    delta_bound = (model.sub_problem.BLP.UpperBound(end) - ...
        model.sub_problem.BLP.LowerBound(end))/ ...
        model.sub_problem.BLP.UpperBound(end);
    fprintf('%-40s\t\t%8.2f%s\n', '(UB-LB)/UB:  ', ...
        100*delta_bound, '%');
    if delta_bound < 5e-3
        flag_convergence = 1;
    end
    if model.sub_problem.BLP.UpperBound(end) > 10*big_M || ...
         model.sub_problem.BLP.LowerBound(end) > 10*big_M   
        flag_unbounded = 1;
    end
    num_iter = num_iter + 1;
end
if ~isfield(model.sub_problem.BLP,'num_iter')
    model.sub_problem.BLP.num_iter = [];
end
model.sub_problem.BLP.num_iter = [model.sub_problem.BLP.num_iter num_iter - 1];

% pause();
%% --------------------- add_scenario_lambda() ---------------------
    function add_scenario_lambda()
        f_start_res = 7441; f_end_res= 7536;            % 7441   7536
        f_start_load = 7537; f_end_load = 8328;         % 7537   8328
        f_start_Tau = 17815; f_end_Tau = 17838;         % 17815  17838
        f_start_Tau_act = 17839; f_end_Tau_act = 18462; % 17839  18462
        for i = 1:length(set_respower)
            index_res(:,i) = f_start_res + num_period*(i-1) : f_start_res+num_period*i-1; %#ok<*AGROW>
        end
        for i = 1:length(set_loadpower)
            index_load(:,i) = f_start_load + num_period*(i-1) : f_start_load+num_period*i-1;
        end
        index_Tau_out = f_start_Tau:f_end_Tau;
        for i = 1:num_building
            index_Tau_act(:,i) = f_start_Tau_act + num_period*(i-1) : f_start_Tau_act+num_period*i-1;
        end
        % %
        for i = 1:length(set_respower)
            model.sub_problem.BLP.scenario(num_iter).lambda.p_res(:,i) = ...
                var_2st.BLP.sub_problem.dual_lambda(index_res(:,i),1);
        end
        for i = 1:length(set_loadpower)
            model.sub_problem.BLP.scenario(num_iter).lambda.p_load(:,i) = ...
                var_2st.BLP.sub_problem.dual_lambda(index_load(:,i),1);
        end
        model.sub_problem.BLP.scenario(num_iter).lambda.Tau_out = ...
            var_2st.BLP.sub_problem.dual_lambda(index_Tau_out);
        for i = 1:num_building
            model.sub_problem.BLP.scenario(num_iter).lambda.Tau_act(:,i) = ...
                var_2st.BLP.sub_problem.dual_lambda(index_Tau_act(:,i),1);
        end
        
    end

%% ------------------- add_scenario_uncertainty() ------------------
    function add_scenario_uncertainty()
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.p_res_pos = ...
            var_2st.BLP.main_problem.p_res_pos;
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.p_res_neg = ...
            var_2st.BLP.main_problem.p_res_neg;
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.p_load_pos = ...
            var_2st.BLP.main_problem.p_load_pos;
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.p_load_neg = ...
            var_2st.BLP.main_problem.p_load_neg;
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.Tau_out_pos = ...
            var_2st.BLP.main_problem.Tau_out_pos;
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.Tau_out_neg = ...
            var_2st.BLP.main_problem.Tau_out_neg;
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.Tau_act_pos = ...
            var_2st.BLP.main_problem.Tau_act_pos;
        model.sub_problem.BLP.scenario(num_iter+1).uncertainty.Tau_act_neg = ...
            var_2st.BLP.main_problem.Tau_act_neg;
    end
end