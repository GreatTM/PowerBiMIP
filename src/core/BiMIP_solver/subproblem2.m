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

    %% Determine which upper-level variables appear in lower-level constraints
    % Extract variable indices that appear in lower-level constraints
    lower_vars_from_upper = [];
    if ~isempty(model.A_l_vars)
        lower_vars_from_upper = [lower_vars_from_upper; getvariables(model.A_l_vars(:))];
    end
    if ~isempty(model.B_l_vars)
        lower_vars_from_upper = [lower_vars_from_upper; getvariables(model.B_l_vars(:))];
    end
    if ~isempty(model.E_l_vars)
        lower_vars_from_upper = [lower_vars_from_upper; getvariables(model.E_l_vars(:))];
    end
    if ~isempty(model.F_l_vars)
        lower_vars_from_upper = [lower_vars_from_upper; getvariables(model.F_l_vars(:))];
    end
    lower_vars_from_upper = unique(lower_vars_from_upper);
    
    %% Build fixed variable substitutions for lower-level constraints only
    % Only fix variables that appear in lower-level constraints
    fixed_A_l_vars = model.A_l_vars;
    fixed_B_l_vars = model.B_l_vars;
    fixed_E_l_vars = model.E_l_vars;
    fixed_F_l_vars = model.F_l_vars;
    
    % Replace with fixed values for variables that appear in lower constraints
    if ~isempty(model.A_l_vars)
        idx_in_lower = ismember(getvariables(model.A_l_vars(:)), lower_vars_from_upper);
        fixed_A_l_vars(idx_in_lower) = master_problem_solution.A_l_vars(idx_in_lower);
    end
    if ~isempty(model.B_l_vars)
        idx_in_lower = ismember(getvariables(model.B_l_vars(:)), lower_vars_from_upper);
        fixed_B_l_vars(idx_in_lower) = master_problem_solution.B_l_vars(idx_in_lower);
    end
    if ~isempty(model.E_l_vars)
        idx_in_lower = ismember(getvariables(model.E_l_vars(:)), lower_vars_from_upper);
        fixed_E_l_vars(idx_in_lower) = master_problem_solution.E_l_vars(idx_in_lower);
    end
    if ~isempty(model.F_l_vars)
        idx_in_lower = ismember(getvariables(model.F_l_vars(:)), lower_vars_from_upper);
        fixed_F_l_vars(idx_in_lower) = master_problem_solution.F_l_vars(idx_in_lower);
    end
    
    %% Constraints building
    model.constraints = [];
    
    % --- Add UPPER-level constraints if model has "simple coupled" flag ---
    if isfield(model, 'has_simple_coupled') && model.has_simple_coupled
        % Upper level inequality constraints with partial fixing
        if ~isempty(model.b_u)
            upper_ineq_lhs = model.A_u * master_problem_solution.A_u_vars + ...
                             model.B_u * master_problem_solution.B_u_vars + ...
                             model.C_u * model.C_u_vars + ...
                             model.D_u * model.D_u_vars;
            
            % Filter out constraints that become logical (constant <= constant)
            for i = 1:length(model.b_u)
                if isa(upper_ineq_lhs(i), 'sdpvar') && ~is(upper_ineq_lhs(i), 'constant')
                    model.constraints = model.constraints + (upper_ineq_lhs(i) <= model.b_u(i));
                end
            end
        end
        
        % Upper level equality constraints with partial fixing
        if ~isempty(model.f_u)
            upper_eq_lhs = model.E_u * master_problem_solution.E_u_vars + ...
                           model.F_u * master_problem_solution.F_u_vars + ...
                           model.G_u * model.G_u_vars + ...
                           model.H_u * model.H_u_vars;
            
            % Filter out constraints that become logical
            for i = 1:length(model.f_u)
                if isa(upper_eq_lhs(i), 'sdpvar') && ~is(upper_eq_lhs(i), 'constant')
                    model.constraints = model.constraints + (upper_eq_lhs(i) == model.f_u(i));
                end
            end
        end
    end
    
    % --- Lower level constraints (with partial fixing) ---
    % inequality
    if isempty(model.b_l)
        model.constraints = model.constraints + [];
    else
        model.constraints = model.constraints + ...
            ([model.A_l, model.B_l, ...
            model.C_l, model.D_l] * ...
            [fixed_A_l_vars; fixed_B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
            model.b_l);
    end

    % equality
    if isempty(model.f_l)
        model.constraints = model.constraints + [];
    else
        model.constraints = model.constraints + ...
            ([model.E_l, model.F_l, ...
            model.G_l, model.H_l] * ...
            [fixed_E_l_vars; fixed_F_l_vars; model.G_l_vars; model.H_l_vars] == ...
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