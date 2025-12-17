function solve_BLP_mainProblem(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if find(strcmp(varargin, 'TimeLimit'))
    TimeLimit = varargin{find(strcmp(varargin, 'TimeLimit'))+1};
else
    TimeLimit = 60*5;
end
if DisplayTime
    fprintf('%-40s\t\n','- Solve BLP main problem');
    t0 = clock;
end
%%
global model;
ops = sdpsettings('solver', 'gurobi', 'verbose',0, ...
    'savesolverinput',1,'savesolveroutput',1);

sol = optimize(model.sub_problem.BLP.main_problem.cons, ...
    -model.sub_problem.BLP.main_problem.obj, ops);
if sol.problem~=0 && sol.problem~=3 
    warning on;
    warning(sol.info);
    warning off;
    return;
end
if DisplayTime
    fprintf('%-40s\t\t',['  - Objective: '] );
    fprintf('%8.2f\n', value(model.sub_problem.BLP.main_problem.obj));
    fprintf('%-40s\t\t','  - Solver time: ');
    fprintf('%8.2f%s\n', sol.solvertime, 's');
end
if ~isfield(model.sub_problem.BLP.main_problem,'solvertime')
    model.sub_problem.BLP.main_problem.solvertime = [];
end
model.sub_problem.BLP.main_problem.solvertime = [model.sub_problem.BLP.main_problem.solvertime sol.solvertime];

%%
% if DisplayTime
%     t1 = clock;
%     fprintf('%8.2f%s\n', etime(t1,t0), 's');
% end
end