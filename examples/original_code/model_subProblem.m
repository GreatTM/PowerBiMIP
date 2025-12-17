function model_subProblem(varargin)
if nargin > 0
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t\n','- Model sub problem');
    t0 = clock;
end
%%
global model var_2st;
model.sub_problem.cons = [];
model.sub_problem.obj = 0;
var_2st = [];
%%
define_subProblemVars('DisplayTime',0);
model_grid_2st('DisplayTime',0);
model_heatingwork_2st('DisplayTime',0);
model_building_2st('DisplayTime',0);
model_coupling_2st('DisplayTime',0);
model_obj_2st('DisplayTime',0);
%%
ops = sdpsettings('kkt.dualbounds',0, 'verbose',0);
[model.sub_problem.KKTsystem, model.sub_problem.details] = ...
    kkt(model.sub_problem.cons, model.sub_problem.obj, ...
    [var_2st.primal.uncertainty.p_res_pos var_2st.primal.uncertainty.p_res_neg ...
    var_2st.primal.uncertainty.p_load_pos var_2st.primal.uncertainty.p_load_neg ...
    var_2st.primal.uncertainty.Tau_out_pos var_2st.primal.uncertainty.Tau_out_neg ...
    var_2st.primal.uncertainty.Tau_act_pos var_2st.primal.uncertainty.Tau_act_neg], ops);
%% 验证子问题与原问题同解，注意这里不包括es和tst成，所以目标函数要小一点
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.p_res_pos == 0));
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.p_res_neg == 0));
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.p_load_pos == 0));
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.p_load_neg == 0));
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.Tau_out_pos == 0));
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.Tau_out_neg == 0));
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.Tau_act_pos == 0));
% model.sub_problem.cons = model.sub_problem.cons + ( ...
%     (var_2st.primal.uncertainty.Tau_act_neg == 0));
% 
% optimize(model.sub_problem.cons, model.sub_problem.obj,sdpsettings('solver','cplex'))


% model_dualProblem('DisplayTime',0);
model_dualProblem_OA('DisplayTime', 0);

%%
% if DisplayTime
%     t1 = clock;
%     fprintf('%8.2f%s\n', etime(t1,t0), 's');
% end
end