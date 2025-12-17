function solve_subProblem(varargin)
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
    fprintf('%-40s\t\n','- Solve sub problem');
    t0 = clock;
end
%%
global model;
ops = sdpsettings('solver', 'gurobi', 'verbose',0, ...
    'savesolverinput',1,'savesolveroutput',1);
ops.gurobi.MIPGap = 1e-2;    % %  gap between the lower/upper objective bound, relative value of upper bound
ops.gurobi.MIPGapAbs = 1e0;  % % gap between the lower/upper objective bound, absolute value
ops.gurobi.TimeLimit = TimeLimit;

ops.cplex.mip.tolerances.mipgap = 1e-2;
ops.cplex.mip.tolerances.absmipgap = 1e0;
ops.cplex.timelimit = TimeLimit;

sol = optimize(model.sub_problem.dual_problem.cons, ...
    -model.sub_problem.dual_problem.obj, ops);
if sol.problem~=0 && sol.problem~=3 
    warning on;
    warning(sol.info);
    warning off;
    return;
end
if DisplayTime
    fprintf('%-40s\t\t',['  - Objective: '] );
    fprintf('%8.2f\n', -sol.solveroutput.result.objval);
    fprintf('%-40s\t\t','  - Solver time: ');
    fprintf('%8.2f%s\n', sol.solvertime, 's');
end

%%
% if DisplayTime
%     t1 = clock;
%     fprintf('%8.2f%s\n', etime(t1,t0), 's');
% end
end