function Solution = master_problem_KKT(model,ops,iteration_record)
%MASTER_PROBLEM_KKT Solves the KKT-based master problem for the R&D algorithm.
%
%   Description:
%       This function builds and solves the master problem (MP) of the
%       Reformulation & Decomposition (R&D) algorithm using KKT conditions to
%       represent the lower-level problem's optimality.
%
%       - In the first iteration, it solves a relaxed version of the full
%         bilevel problem.
%       - In subsequent iterations, it adds KKT optimality cuts derived from
%         the solutions of previous subproblems.
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
        % --- First Iteration: Solve the relaxed problem ---
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
        % model.solution = optimize(model.constraints,0,ops.ops_MP);

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

        Solution.objective = value(model.objective);

    else
        % --- Subsequent Iterations: Add KKT optimality cuts ---
        
        %% Define Variables for KKT Cuts
        for i = 1 : iteration_record.iteration_num - 1
            % Create continuous variables for the lower-level subproblem of iteration i.            
            % Step 1: Extract and find unique identifiers for all continuous lower-level variables.        
                all_vars = unique([
                    getvariables(model.c5_vars(:));
                    getvariables(model.C_l_vars(:));
                    getvariables(model.G_l_vars(:))
                ]);
                
                % Step 2: Create a new base vector of sdpvars.
                n = length(all_vars);
                V_new = sdpvar(n, 1,'full');
                
                % Step 3: Create a map from original variable identifiers to the new base vector indices.
                get_indices = @(x) find(ismember(all_vars, getvariables(x(:))));
                
                % Step 4: Reconstruct the variable groups (c5_vars, etc.) using the
                % new base variables, preserving their original shapes.
                model.new_var(i).c5_vars = reshape(V_new(get_indices(model.c5_vars)), size(model.c5_vars));
                model.new_var(i).C_l_vars = reshape(V_new(get_indices(model.C_l_vars)), size(model.C_l_vars));
                model.new_var(i).G_l_vars = reshape(V_new(get_indices(model.G_l_vars)), size(model.G_l_vars));
                        
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

        % optimality condition(KKT approach)
%         big_M = 1e6;
        model.cons_for_KKT = cell(1,iteration_record.iteration_num - 1);
        model.obj_for_KKT = cell(1,iteration_record.iteration_num - 1);
        kkt_conditions = cell(1,iteration_record.iteration_num - 1);
        kkt_details = cell(1,iteration_record.iteration_num - 1);
        for i = 1 : iteration_record.iteration_num - 1
            % Define the objective term for the i-th subproblem.
            obj_term_i = [model.c5', model.c6'] * ...
                         [model.new_var(i).c5_vars; model.new_var(i).c6_vars];
            
            % Add the optimality cut to the master problem.
            model.constraints = model.constraints + ...
                ([model.c5', model.c6'] * ...
                [model.c5_vars; model.c6_vars] <= ...
                obj_term_i);
            % Check if the objective term is constant. YALMIP's kkt() function
            % does not support constant objectives.
            if degree(obj_term_i) == 0
                % If it is constant, the optimality cut above is sufficient.
                % Skip generating full KKT conditions for this iteration.
                continue;
            else
                % If not constant, generate the full KKT conditions to enforce optimality.
                % kkt condition---primary
                % lower level
                % inequality
                if isempty(model.b_l)
                    model.cons_for_KKT{i} = model.cons_for_KKT{i} + [];
                else
                    model.cons_for_KKT{i} = model.cons_for_KKT{i} + ...
                        ([model.A_l, model.B_l, ...
                        model.C_l, model.D_l] * ...
                        [model.A_l_vars; model.B_l_vars; model.new_var(i).C_l_vars; model.new_var(i).D_l_vars] <= ...
                        model.b_l);
                end
                % equality
                if isempty(model.f_l)
                    model.cons_for_KKT{i} = model.cons_for_KKT{i} + [];
                else
                    model.cons_for_KKT{i} = model.cons_for_KKT{i} + ...
                        ([model.E_l, model.F_l, ...
                        model.G_l, model.H_l] * ...
                        [model.E_l_vars; model.F_l_vars; model.new_var(i).G_l_vars; model.new_var(i).H_l_vars] == ...
                        model.f_l);
                end
                model.obj_for_KKT{i} = [model.c5', model.c6'] * [model.new_var(i).c5_vars; model.new_var(i).c6_vars];
                [kkt_conditions{i}, kkt_details{i}] = kkt(model.cons_for_KKT{i}, ...
                    model.obj_for_KKT{i}, [model.A_l_vars; model.B_l_vars; ...
                    model.E_l_vars; model.F_l_vars], sdpsettings('kkt.dualbounds',0,'verbose',0));

                % Store the dual variables associated with the KKT conditions.
                model.new_var(i).dual_ineq = kkt_details{i}.dual;
                model.new_var(i).dual_eq = kkt_details{i}.dualeq;
                
                model.constraints = model.constraints + kkt_conditions{i};

%             % kkt condition---dual
%             model.constraints = model.constraints + ...
%                 (model.new_var(i).dual_ineq >= 0);
%             % kkt condition---complementary
%             model.constraints = model.constraints + ...
%                 (model.new_var(i).dual_ineq <= big_M * model.new_var(i).dual_ineq_bin);
%             model.constraints = model.constraints + ...
%                 (model.new_var(i).dual_eq >= -big_M);
%             model.constraints = model.constraints + ...
%                 (model.new_var(i).dual_eq <= big_M);
%             model.constraints = model.constraints + ...
%                 (-big_M * (1 - model.new_var(i).dual_ineq_bin) <= ...
%                 [model.A_l, model.B_l, ...
%                 model.C_l, model.D_l] * ...
%                 [model.A_l_vars; model.B_l_vars; model.new_var(i).C_l_vars; model.new_var(i).D_l_vars] - ...
%                 model.b_l);
%             % kkt condition---stationary
%             model.constraints = model.constraints + ...
%                 (model.c5' + ...
%                 model.new_var(i).dual_ineq' * model.C_l + ...
%                 model.new_var(i).dual_eq' * model.G_l == 0);
            end
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

        Solution.objective = value(model.objective);
    end
end