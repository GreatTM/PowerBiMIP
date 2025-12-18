function [Solution] = master_problem_strong_duality(model,ops,iteration_record)
%MASTER_PROBLEM_STRONG_DUALITY Solves the strong-duality-based master problem for the R&D algorithm.
%
%   Description:
%       This function builds and solves the master problem (MP) of the
%       Reformulation & Decomposition (R&D) algorithm using the principle of
%       strong duality to represent the lower-level problem's optimality.
%
%       - In the first iteration, it solves a relaxed version of the full
%         bilevel problem.
%       - In subsequent iterations, it adds optimality cuts formulated from
%         the strong duality condition of the lower-level problem.
%
%   Inputs:
%       model            - struct: The standard PowerBiMIP model structure.
%       ops              - struct: A struct containing solver options.
%       iteration_record - struct: A struct containing the history of the
%                          R&D algorithm's progress.
%
%   Output:
%       Solution - struct: A struct containing the solution of the master problem.

    if iteration_record.iteration_num == 1
        %% Constraints building
        model.constraints = [];
        % upper level
        % inequality
        if isempty(model.b_u)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.A_u, model.B_u, ...
                model.C_u, model.D_u] * ...
                [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
                model.b_u);
        end

        % equality
        if isempty(model.f_u)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.E_u, model.F_u, ...
                model.G_u, model.H_u] * ...
                [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
                model.f_u);
        end

        % lower level
        % inequality
        if isempty(model.b_l)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.A_l, model.B_l, ...
                model.C_l, model.D_l] * ...
                [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
                model.b_l);
        end
        % equality
        if isempty(model.f_l)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.E_l, model.F_l, ...
                model.G_l, model.H_l] * ...
                [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
                model.f_l);
        end

        %% Objective building
        model.objective = [model.c1', model.c2', ...
            model.c3', model.c4'] * ...
            [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];

        %% Solving
        model.solution = optimize(model.constraints,model.objective,ops.ops_MP);
        % ops = sdpsettings('solver','gurobi', 'verbose',2);
        % model.solution = optimize(model.constraints,0,ops);
        %% Output
        Solution.var = myFun_GetValue(model.var);
        Solution.solution = model.solution;

        Solution.A_u_vars = value(model.A_u_vars);
        Solution.B_u_vars = value(model.B_u_vars);
        Solution.E_u_vars = value(model.E_u_vars);
        Solution.F_u_vars = value(model.F_u_vars);

        Solution.A_l_vars = value(model.A_l_vars);
        Solution.B_l_vars = value(model.B_l_vars);
        Solution.E_l_vars = value(model.E_l_vars);
        Solution.F_l_vars = value(model.F_l_vars);

        Solution.c1_vars = value(model.c1_vars);
        Solution.c2_vars = value(model.c2_vars);
        Solution.c3_vars = value(model.c3_vars);
        Solution.c4_vars = value(model.c4_vars);


        Solution.objective = value(model.objective);

    else
        % --- Subsequent Iterations: Add strong duality optimality cuts ---

        %% Define Dual Variables for Strong Duality Cuts
        for i = 1 : iteration_record.iteration_num - 1
            % Create dual variables for the lower-level primal constraints.
                model.new_var(i).dual_ineq = sdpvar(model.length_b_l, 1, 'full');
                model.new_var(i).dual_eq = sdpvar(model.length_f_l, 1, 'full');

            % Use the fixed integer variables from the i-th subproblem solution.
                model.new_var(i).c6_vars = iteration_record.optimal_solution_hat{i}.c6_vars;  % fixing lower level integer variables
                model.new_var(i).D_l_vars = iteration_record.optimal_solution_hat{i}.D_l_vars;  % fixing lower level integer variables
                model.new_var(i).H_l_vars = iteration_record.optimal_solution_hat{i}.H_l_vars;  % fixing lower level integer variables
        end

        %% Constraints building
        model.constraints = [];
        % upper level
        % inequality
        if isempty(model.b_u)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.A_u, model.B_u, ...
                model.C_u, model.D_u] * ...
                [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
                model.b_u);
        end

        % equality
        if isempty(model.f_u)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.E_u, model.F_u, ...
                model.G_u, model.H_u] * ...
                [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
                model.f_u);
        end

        % lower level
        % inequality
        if isempty(model.b_l)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.A_l, model.B_l, ...
                model.C_l, model.D_l] * ...
                [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
                model.b_l);
        end
        % equality
        if isempty(model.f_l)
            model.constraints = model.constraints + [];
        else
            model.constraints = model.constraints + ...
                ([model.E_l, model.F_l, ...
                model.G_l, model.H_l] * ...
                [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
                model.f_l);
        end

        % optimality condition(strong duality approach)
        for i = 1 : iteration_record.iteration_num - 1
            % cut
            model.constraints = model.constraints + ...
                ([model.c5', model.c6'] * ...
                [model.c5_vars; model.c6_vars] <= ...
                [model.new_var(i).dual_ineq', model.new_var(i).dual_eq', model.c6'] * ...
                [(model.b_l - [model.A_l, model.B_l, model.D_l] * [model.A_l_vars; model.B_l_vars; model.new_var(i).D_l_vars]);...
                 (model.f_l - [model.E_l, model.F_l, model.H_l] * [model.E_l_vars; model.F_l_vars; model.new_var(i).H_l_vars]);...
                model.new_var(i).c6_vars]);
            
            % Add dual feasibility constraints for the lower-level problem.
            % Initialize constraint expressions.
            constraint_ineq = 0;
            constraint_eq = 0;
            
            % If dual variables for inequality constraints exist, add their part.
            if ~isempty(model.new_var(i).dual_ineq) && ~isempty(model.C_l)
                constraint_ineq = model.new_var(i).dual_ineq' * model.C_l;
            end
            
            % If dual variables for equality constraints exist, add their part.
            if ~isempty(model.new_var(i).dual_eq) && ~isempty(model.G_l)
                constraint_eq = model.new_var(i).dual_eq' * model.G_l;
            end
            
            % Add the combined dual feasibility constraint.
            model.constraints = model.constraints + (constraint_ineq + constraint_eq == model.c5');

            % Dual variable sign constraints
            model.constraints = model.constraints + ...
                (model.new_var(i).dual_ineq <= 0);
        end
        
        %% Objective building
        model.objective = [model.c1', model.c2', ...
            model.c3', model.c4'] * ...
            [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];
        %% Solving
        model.solution = optimize(model.constraints,model.objective,ops.ops_MP);
        %% Output
        Solution.var = myFun_GetValue(model.var);
        Solution.new_var = myFun_GetValue(model.new_var);
        Solution.solution = model.solution;

        Solution.A_u_vars = value(model.A_u_vars);
        Solution.B_u_vars = value(model.B_u_vars);
        Solution.E_u_vars = value(model.E_u_vars);
        Solution.F_u_vars = value(model.F_u_vars);

        Solution.A_l_vars = value(model.A_l_vars);
        Solution.B_l_vars = value(model.B_l_vars);
        Solution.E_l_vars = value(model.E_l_vars);
        Solution.F_l_vars = value(model.F_l_vars);

        Solution.c1_vars = value(model.c1_vars);
        Solution.c2_vars = value(model.c2_vars);
        Solution.c3_vars = value(model.c3_vars);
        Solution.c4_vars = value(model.c4_vars);
        Solution.c5_vars = value(model.c5_vars);
        Solution.c6_vars = value(model.c6_vars);

        Solution.objective = value(model.objective);
    end
end