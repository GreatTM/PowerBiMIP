function [Solution] = subproblem2(model,master_problem_solution,subproblem_1_solution,ops)
%SUBPROBLEM2 Solves Subproblem 2 (SP2) of the R&D algorithm.
%
%   Description:
%       This function solves the second subproblem (SP2) of the Reformulation &
%       Decomposition algorithm. The goal of SP2 is to find a feasible
%       solution and a valid upper bound (UB) for the bilevel problem.
%
%       It works by solving for the lower-level continuous variables (x_l)
%       while keeping all upper-level variables fixed to the master problem's
%       solution. It also adds a constraint to ensure the lower-level's optimality.
%
%   Inputs:
%       model                   - struct: The standard PowerBiMIP model structure.
%       master_problem_solution - struct: The solution struct from the master problem.
%       subproblem_1_solution   - struct: The solution struct from subproblem 1.
%       ops                     - struct: A struct containing solver options.
%
%   Output:
%       Solution - struct: A struct containing the solution of SP2. The
%                  objective value of this solution is a valid Upper Bound.

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

    % optimality
    model.constraints = model.constraints + ...
        ([model.c5', model.c6'] * ...
        [model.c5_vars; model.c6_vars] <= ...
        subproblem_1_solution.objective);

    %% Objective building
    model.objective = [model.c1', model.c2', ...
        model.c3', model.c4'] * ...
        [master_problem_solution.c1_vars; master_problem_solution.c2_vars; model.c3_vars; model.c4_vars];

    %% Solving
    model.solution = optimize(model.constraints,model.objective,ops.ops_SP2);

    %% Output
    Solution.var = myFun_GetValue(model.var);
    Solution.solution = model.solution;
    Solution.D_l_vars = value(model.D_l_vars);
    Solution.H_l_vars = value(model.H_l_vars);
    Solution.c6_vars = value(model.c6_vars);

    Solution.objective = value(model.objective);
end