function model_obj_2st(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Model objective');
    t0 = clock;
end
%%
global model var_2st;
model.sub_problem.obj = ...
    sum(var_2st.primal.cost.grid_buy) - sum(var_2st.primal.cost.grid_sell) + ...
    sum(var_2st.primal.cost.res) + ...
    sum(var_2st.primal.cost.gt) + sum(var_2st.primal.cost.eb) + ...
    var_2st.primal.cost.Tau_in_comp;
%%
if DisplayTime
    t1 = clock;
    fprintf('%8.2f%s\n', etime(t1,t0), 's');
end
end