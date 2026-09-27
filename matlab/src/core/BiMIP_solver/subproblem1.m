function [Solution] = subproblem1(model,master_problem_solution,ops)
%SUBPROBLEM1 Solves Subproblem 1 (SP1) of the R&D algorithm.
%
%   Description:
%       This function solves the first subproblem (SP1) of the Reformulation &
%       Decomposition algorithm.
%
%   Inputs:
%       model                   - struct: The standard PowerBiMIP model structure.
%       master_problem_solution - struct: The solution struct from the master problem.
%       ops                     - struct: A struct containing solver options.
%
%   Output:
%       Solution - struct: A struct containing the solution of SP1

    %% Constraints building
    model.constraints = [];
    % lower level
    % inequality
    if isempty(model.b_l)
        model.constraints = model.constraints + [];
    else
        model.constraints = model.constraints + ...
            ([model.A_l, model.B_l, ...
            model.C_l, model.D_l] * ...
            [master_problem_solution.A_l_vars; master_problem_solution.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
            model.b_l);
    end
    % equality
    if isempty(model.f_l)
        model.constraints = model.constraints + [];
    else
        model.constraints = model.constraints + ...
            ([model.E_l, model.F_l, ...
            model.G_l, model.H_l] * ...
            [master_problem_solution.E_l_vars; master_problem_solution.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
            model.f_l);
    end

    %% Objective building
    model.objective = [model.c5', model.c6'] * ...
        [model.c5_vars; model.c6_vars];

    %% Solving
    model.solution = optimize(model.constraints,model.objective,ops.ops_SP1);

    %% Output
    Solution.var = myFun_GetValue(model.var);
    Solution.D_l_vars = value(model.D_l_vars);
    Solution.H_l_vars = value(model.H_l_vars);
    Solution.c6_vars = value(model.c6_vars);
    Solution.solution = model.solution;

    Solution.objective = value(model.objective);
end