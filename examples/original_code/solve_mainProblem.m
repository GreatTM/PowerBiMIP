function solve_mainProblem(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\n','- Solve main problem');
    t0 = clock;
end
%%
global model;
ops = sdpsettings('solver', 'gurobi', 'verbose',0, ...
    'savesolverinput',1,'savesolveroutput',1);
sol = optimize(model.main_problem.cons, model.main_problem.obj,ops);
if sol.problem
    warning on;
    warning(sol.info);
    warning off;
    return;
end
if DisplayTime
    fprintf('%-40s\t\t',['  - Objective: '] );
    fprintf('%8.2f\n', value(model.main_problem.obj));
    fprintf('%-40s\t\t','  - Solver time: ');
    fprintf('%8.2f%s\n', sol.solvertime, 's');
end
if ~isfield(model.main_problem,'solvertime')
    model.main_problem.solvertime = [];
end
model.main_problem.solvertime = [model.main_problem.solvertime sol.solvertime];
%%
% if DisplayTime
%     t1 = clock;
%     fprintf('%8.2f%s\n', etime(t1,t0), 's');
% end
end