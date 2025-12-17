function [Solution] = master_problem_quick(model,ops,iteration_record)
%MASTER_PROBLEM_QUICK Solves the master problem for the R&D algorithm using a L1-penalty PADM approach.
%
%   Description:
%       This function implements the "quick" method for solving the master
%       problem.
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

        %% Output
        Solution.var = myFun_GetValue(model.var);
        Solution.solution = model.solution;

        Solution.A_u_vars = value(model.A_u_vars);
        Solution.B_u_vars = value(model.B_u_vars);
        Solution.C_u_vars = value(model.C_u_vars);
        Solution.D_u_vars = value(model.D_u_vars);
        Solution.E_u_vars = value(model.E_u_vars);
        Solution.F_u_vars = value(model.F_u_vars);
        Solution.G_u_vars = value(model.G_u_vars);
        Solution.H_u_vars = value(model.H_u_vars);

        Solution.A_l_vars = value(model.A_l_vars);
        Solution.B_l_vars = value(model.B_l_vars);
        Solution.C_l_vars = value(model.C_l_vars);
        Solution.D_l_vars = value(model.D_l_vars);
        Solution.E_l_vars = value(model.E_l_vars);
        Solution.F_l_vars = value(model.F_l_vars);
        Solution.G_l_vars = value(model.G_l_vars);
        Solution.H_l_vars = value(model.H_l_vars);

        Solution.c1_vars = value(model.c1_vars);
        Solution.c2_vars = value(model.c2_vars);
        Solution.c3_vars = value(model.c3_vars);
        Solution.c4_vars = value(model.c4_vars);
        Solution.c5_vars = value(model.c5_vars);
        Solution.c6_vars = value(model.c6_vars);
        Solution.objective = value(model.objective);

    else
        %% --- Subsequent Iterations: Solve with L1-PADM ---

        %% Define New Variables for Cuts
        for i = 1 : iteration_record.iteration_num - 1
            % Create dual variables and penalty helper variable (Phi) for each cut.
            model.new_var(i).dual_ineq = sdpvar(size(model.b_l,1), 1, 'full');
            model.new_var(i).dual_eq = sdpvar(size(model.f_l,1), 1, 'full');
            model.new_var(i).Phi = sdpvar(1,1); % Penalty helper variable
            
            % Fix lower-level integer variables based on the i-th subproblem solution.
            model.new_var(i).c6_vars = iteration_record.optimal_solution_hat{i}.c6_vars;
            model.new_var(i).D_l_vars = iteration_record.optimal_solution_hat{i}.D_l_vars;
            model.new_var(i).H_l_vars = iteration_record.optimal_solution_hat{i}.H_l_vars;
        end
        temp.var = sdpvar(iteration_record.iteration_num - 1, 1, 'full');

        % Initialize variables to store L1-PADM data
        padm1_objectives = [];
        padm2_objectives = [];
        padm_gaps = [];        
        rho_values = [];       

        %% Main L1-PADM Loop
        flag_penalty = 0;
        flag_bisection = 0;
        high_rho = ops.penalty_rho;
        low_rho = 0;
        mid_rho = ops.penalty_rho;
        % Create convergence plot for L1-PADM (only if verbose >= 2).
        if ops.verbose >= 2
            padm_fig = figure('Name', sprintf('R&D Iter %d L1-PADM Convergence', iteration_record.iteration_num));
            ax = gca(padm_fig);
            yyaxis(ax, 'left');
            
            padm1_curve = plot(ax, nan, 'r-s', 'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'L1-PADM1 Obj');
            hold(ax, 'on');
            padm2_curve = plot(ax, nan, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'L1-PADM2 Obj');
            ylabel(ax, 'Objective Value');
            
            yyaxis(ax, 'right');
            gap_curve = plot(ax, nan, 'k--^', 'LineWidth', 1, 'MarkerSize', 8, 'DisplayName', 'Gap');
            ylabel(ax, 'Obj Diff (%)');
            xlabel(ax, 'L1-PADM Iteration');
            title(ax, sprintf('L1-PADM Convergence for R&D Iteration %d', iteration_record.iteration_num));
            legend(ax, 'Location', 'best');
            grid(ax, 'on');
            hold(ax, 'off');
            
            padm_fig_handles.padm1_curve = padm1_curve;
            padm_fig_handles.padm2_curve = padm2_curve;
            padm_fig_handles.gap_curve = gap_curve;
            padm_fig_handles.ax = ax;
        end

        
        padm_iter = 1;

        while padm_iter <= ops.padm_max_iter
            current_rho = ops.penalty_rho;
            rho_values(end+1) = current_rho;
            %% L1-PADM Subproblem 1
%             fprintf('L1-PADM Iteration %d, Step 1: Optimizing dual variables...\n', padm_iter);
            
            % Set fixed values for all primal variables.
            if padm_iter > 1
                current_A_u_vars = value(model.A_u_vars); current_B_u_vars = value(model.B_u_vars);
                current_C_u_vars = value(model.C_u_vars); current_D_u_vars = value(model.D_u_vars);
                current_E_u_vars = value(model.E_u_vars); current_F_u_vars = value(model.F_u_vars);
                current_G_u_vars = value(model.G_u_vars); current_H_u_vars = value(model.H_u_vars);

                current_A_l_vars = value(model.A_l_vars); current_B_l_vars = value(model.B_l_vars);
                current_C_l_vars = value(model.C_l_vars); current_D_l_vars = value(model.D_l_vars);
                current_E_l_vars = value(model.E_l_vars); current_F_l_vars = value(model.F_l_vars);
                current_G_l_vars = value(model.G_l_vars); current_H_l_vars = value(model.H_l_vars);

                current_c1_vars = value(model.c1_vars); current_c2_vars = value(model.c2_vars);
                current_c3_vars = value(model.c3_vars); current_c4_vars = value(model.c4_vars);
                current_c5_vars = value(model.c5_vars); current_c6_vars = value(model.c6_vars);
            else
                % set initial value
                current_A_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.A_u_vars;
                current_B_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.B_u_vars;
                current_C_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.C_u_vars;
                current_D_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.D_u_vars;
                current_E_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.E_u_vars;
                current_F_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.F_u_vars;
                current_G_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.G_u_vars;
                current_H_u_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.H_u_vars;

                current_A_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.A_l_vars;
                current_B_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.B_l_vars;
                current_C_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.C_l_vars;
                current_D_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.D_l_vars;
                current_E_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.E_l_vars;
                current_F_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.F_l_vars;
                current_G_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.G_l_vars;
                current_H_l_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.H_l_vars; 
            
                current_c1_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.c1_vars;
                current_c2_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.c2_vars;
                current_c3_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.c3_vars;
                current_c4_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.c4_vars;
                current_c5_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.c5_vars;
                current_c6_vars = iteration_record.master_problem_solution{iteration_record.iteration_num - 1}.c6_vars;
            end

            %% constraints
            model.constraints_PADM1 = [];    
            % optimality condition(strong duality approach)
            for i = 1 : iteration_record.iteration_num - 1
                % cut
                % strong duality
                rhs = [model.new_var(i).dual_ineq', model.new_var(i).dual_eq', model.c6'] * ...
                      [safe_subtract(model.b_l, model.D_l * model.new_var(i).D_l_vars); ... % model.b_l - model.D_l * model.new_var(i).D_l_vars
                       safe_subtract(model.f_l, model.H_l * model.new_var(i).H_l_vars); ... % model.f_l - model.H_l * model.new_var(i).H_l_vars
                       model.new_var(i).c6_vars] - model.new_var(i).Phi;
    
                model.constraints_PADM1 = model.constraints_PADM1 + (...
                    [model.c5', model.c6'] * [current_c5_vars; current_c6_vars] <= rhs);
    
                % 对偶约束
                % 初始化约束项
                constraint_ineq = 0;
                constraint_eq = 0;
                
                if ~isempty(model.new_var(i).dual_ineq)
                    constraint_ineq = model.new_var(i).dual_ineq' * model.C_l;
                end
                
                if ~isempty(model.new_var(i).dual_eq)
                    constraint_eq = model.new_var(i).dual_eq' * model.G_l;
                end
                
                model.constraints_PADM1 = model.constraints_PADM1 + (constraint_ineq + constraint_eq == model.c5');
    
                model.constraints_PADM1 = model.constraints_PADM1 + ...
                    (model.new_var(i).dual_ineq <= 0);
            end
    
            %% objectives
            original_objective = [model.c1', model.c2', ...
                                  model.c3', model.c4'] * ...
                                 [current_c1_vars; current_c2_vars; current_c3_vars; current_c4_vars];

            for i = 1 : iteration_record.iteration_num - 1
                % compute penalty term
                bilinear_term = [model.new_var(i).dual_ineq', model.new_var(i).dual_eq'] * ...
                                [([model.A_l, model.B_l] * [current_A_l_vars; current_B_l_vars]); ...
                                ([model.E_l, model.F_l] * [current_E_l_vars; current_F_l_vars])];
                model.constraints_PADM1 = model.constraints_PADM1 + ...
                    (temp.var(i) >= bilinear_term - model.new_var(i).Phi);
                model.constraints_PADM1 = model.constraints_PADM1 + ...
                    (temp.var(i) >= - bilinear_term + model.new_var(i).Phi);
            end
            penalty_term = sum(temp.var(:));

            model.objective_PADM1 = original_objective + ops.penalty_rho * penalty_term;
            % solve L1-PADM1
             padm1_diag = optimize(model.constraints_PADM1, model.objective_PADM1, ops.ops_MP);
            if padm1_diag.problem ~=0
                error(['L1-PADM1 of MP is failed to solve in iter ',...
                        num2str(padm_iter),'  ', yalmiperror(padm1_diag.problem)]);
            end
            padm1_obj = value(model.objective_PADM1);
            padm1_objectives(end+1) = padm1_obj;

            %% L1-PADM Subproblem 2: Fix dual variables, optimize primal variables
%             fprintf('L1-PADM Iteration %d, Step 2: Optimizing upper variables...\n', padm_iter);
                        
            % Fix dual variables
            for j = 1:iteration_record.iteration_num-1
                current_new_var(j).dual_ineq = value(model.new_var(j).dual_ineq);
                current_new_var(j).dual_eq = value(model.new_var(j).dual_eq);
                current_new_var(j).dual_eq(isnan(current_new_var(j).dual_eq)) = 0;
            end
            
            %% Constraints building
            model.constraints_PADM2 = [];
            % upper level
            % inequality
            if isempty(model.b_u)
                model.constraints_PADM2 = model.constraints_PADM2 + [];
            else
                model.constraints_PADM2 = model.constraints_PADM2 + ...
                    ([model.A_u, model.B_u, ...
                    model.C_u, model.D_u] * ...
                    [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
                    model.b_u);
            end
    
            % equality
            if isempty(model.f_u)
                model.constraints_PADM2 = model.constraints_PADM2 + [];
            else
                model.constraints_PADM2 = model.constraints_PADM2 + ...
                    ([model.E_u, model.F_u, ...
                    model.G_u, model.H_u] * ...
                    [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
                    model.f_u);
            end
    
            % lower level
            % inequality
            if isempty(model.b_l)
                model.constraints_PADM2 = model.constraints_PADM2 + [];
            else
                model.constraints_PADM2 = model.constraints_PADM2 + ...
                    ([model.A_l, model.B_l, ...
                    model.C_l, model.D_l] * ...
                    [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
                    model.b_l);
            end
            % equality
            if isempty(model.f_l)
                model.constraints_PADM2 = model.constraints_PADM2 + [];
            else
                model.constraints_PADM2 = model.constraints_PADM2 + ...
                    ([model.E_l, model.F_l, ...
                    model.G_l, model.H_l] * ...
                    [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
                    model.f_l);
            end
    
            % optimality condition(strong duality approach)
            for i = 1 : iteration_record.iteration_num - 1
                % cut
                rhs = [current_new_var(i).dual_ineq', current_new_var(i).dual_eq', model.c6'] * ...
                      [safe_subtract(model.b_l, model.D_l * model.new_var(i).D_l_vars); ...
                       safe_subtract(model.f_l, model.H_l * model.new_var(i).H_l_vars); ...
                       model.new_var(i).c6_vars] - model.new_var(i).Phi;
    
                model.constraints_PADM2 = model.constraints_PADM2 + (...
                    [model.c5', model.c6'] * [model.c5_vars; model.c6_vars] <= rhs);
            end
            
            %% objective
            original_objective = [model.c1', model.c2', model.c3', model.c4'] * ...
                               [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];
            
            penalty_term = 0;
            for i = 1 : iteration_record.iteration_num - 1
                % penalty term
                bilinear_term = [current_new_var(i).dual_ineq', current_new_var(i).dual_eq'] * ...
                                [([model.A_l, model.B_l] * [model.A_l_vars; model.B_l_vars]); ...
                                ([model.E_l, model.F_l] * [model.E_l_vars; model.F_l_vars])];
                
                model.constraints_PADM2 = model.constraints_PADM2 + ...
                    (temp.var(i) >= bilinear_term - model.new_var(i).Phi);
                model.constraints_PADM2 = model.constraints_PADM2 + ...
                    (temp.var(i) >= - bilinear_term + model.new_var(i).Phi);
            end
            penalty_term = sum(temp.var(:));
            
            model.objective_PADM2 = original_objective + ops.penalty_rho * penalty_term;
            % solve L1-PADM2
            padm2_diag = optimize(model.constraints_PADM2, model.objective_PADM2, ops.ops_MP);
            if padm2_diag.problem ~= 0
                error(['L1-PADM2 of MP is failed to solve in iter ',...
                        num2str(padm_iter),'  ', yalmiperror(padm2_diag.problem)]);
            end
            padm2_obj = value(model.objective_PADM2); 
            padm2_objectives(end+1) = padm2_obj;      

            %% Calculate L1-PADM Gap (for display) and Check Convergence
            denominator = max(abs(padm1_obj), abs(padm2_obj));
            if denominator == 0
                denominator = 1e-6; 
            end
            obj_gap = abs(padm1_obj - padm2_obj)/denominator * 100;
            padm_gaps(end+1) = obj_gap;
            
            % Check Convergence (Primal Stability)
            curr_primal_vec = [value(model.var_x_u(:)); value(model.var_z_u(:)); ...
                               value(model.var_x_l(:)); value(model.var_z_l(:))];
            curr_primal_vec(isnan(curr_primal_vec)) = 0;

            if padm_iter == 1
                 primal_diff = inf;
            else
                 % Relative Error
                 primal_diff = norm(curr_primal_vec - prev_primal_vec, inf) / max(1, norm(prev_primal_vec, inf));
            end
            prev_primal_vec = curr_primal_vec;

            is_stable = primal_diff <= ops.padm_tolerance;

            if ops.verbose >= 1
                fprintf('L1-PADM Iter %d: L1-PADM1=%.4f | L1-PADM2=%.4f | Gap=%.2f%% | PrimalDiff=%.1e\n',...
                        padm_iter, padm1_obj, padm2_obj, obj_gap, primal_diff);
            end

            if ops.verbose >= 2
                set(padm_fig_handles.padm1_curve,...
                    'XData', 1:length(padm1_objectives),...
                    'YData', padm1_objectives);
                set(padm_fig_handles.padm2_curve,...
                    'XData', 1:length(padm2_objectives),...
                    'YData', padm2_objectives);
                set(padm_fig_handles.gap_curve,...
                    'XData', 1:length(padm_gaps),...
                    'YData', padm_gaps);
                drawnow;
            end
            
            % check convergence
            if is_stable
                if ops.verbose >= 1
                    fprintf('L1-PADM achieved primal stability.\n');
                end
                % compute penalty_term
                current_penalty = 0;
                for i = 1:iteration_record.iteration_num-1
                    dual_ineq = value(model.new_var(i).dual_ineq);
                    dual_ineq(isnan(dual_ineq)) = 0;
                    dual_eq = value(model.new_var(i).dual_eq);
                    dual_eq(isnan(dual_eq)) = 0;
                    Phi = value(model.new_var(i).Phi);
                    A_l_vars_val = value(model.A_l_vars);
                    B_l_vars_val = value(model.B_l_vars);
                    E_l_vars_val = value(model.E_l_vars);
                    F_l_vars_val = value(model.F_l_vars);
                    

                    bilinear_term = [dual_ineq', dual_eq'] * ...
                        [([model.A_l, model.B_l] * [A_l_vars_val; B_l_vars_val]); ...
                        ([model.E_l, model.F_l] * [E_l_vars_val; F_l_vars_val])];
                    current_penalty = current_penalty + abs(Phi - bilinear_term);
                end

                % search rho
                if current_penalty > ops.penalty_term_gap
                    % Penalty term is too high, increase rho and restart L1-PADM.
                    ops.penalty_rho = ops.penalty_rho * 10;
                    padm_iter = 0; % Reset L1-PADM counter
                    
                    fprintf('Penalty term is too high (%.4f > %.4f). Increasing rho.\n', current_penalty, ops.penalty_term_gap);
                    fprintf('New rho = %.2e. Restarting L1-PADM.\n', ops.penalty_rho);
                    
                    if ops.penalty_rho > 1e9 
                        error('PowerBiMIP:ConvergenceError', 'Failed to find a suitable rho. Value exceeds threshold.');
                    end
                else
                    % Penalty term is acceptable, L1-PADM has converged.
                    fprintf('Penalty term is acceptable (%.4f <= %.4f). L1-PADM converged.\n', current_penalty, ops.penalty_term_gap);
                    break; % Success, exit the L1-PADM loop.
                end
            end

            padm_iter = padm_iter + 1;
        end

        model.solution.problem = 0; % Indicate successful solve.
        %% Output
        Solution.padm_iter = padm_iter;
        Solution.var = myFun_GetValue(model.var);
        Solution.new_var = myFun_GetValue(model.new_var);
        Solution.solution = model.solution;

        Solution.A_u_vars = value(model.A_u_vars);
        Solution.B_u_vars = value(model.B_u_vars);
        Solution.C_u_vars = value(model.C_u_vars);
        Solution.D_u_vars = value(model.D_u_vars);
        Solution.E_u_vars = value(model.E_u_vars);
        Solution.F_u_vars = value(model.F_u_vars);
        Solution.G_u_vars = value(model.G_u_vars);
        Solution.H_u_vars = value(model.H_u_vars);

        Solution.A_l_vars = value(model.A_l_vars);
        Solution.B_l_vars = value(model.B_l_vars);
        Solution.C_l_vars = value(model.C_l_vars);
        Solution.D_l_vars = value(model.D_l_vars);
        Solution.E_l_vars = value(model.E_l_vars);
        Solution.F_l_vars = value(model.F_l_vars);
        Solution.G_l_vars = value(model.G_l_vars);
        Solution.H_l_vars = value(model.H_l_vars);

        Solution.c1_vars = value(model.c1_vars);
        Solution.c2_vars = value(model.c2_vars);
        Solution.c3_vars = value(model.c3_vars);
        Solution.c4_vars = value(model.c4_vars);
        Solution.c5_vars = value(model.c5_vars);
        Solution.c6_vars = value(model.c6_vars);

        Solution.objective = value(original_objective);
    end
end