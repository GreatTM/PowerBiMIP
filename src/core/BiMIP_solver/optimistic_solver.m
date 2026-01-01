function iteration_record = optimistic_solver(model, ops)
%OPTIMISTIC_SOLVER Solves a BiMIP model using an optimistic R&D-based algorithm.
%
%   Description:
%       This function implements the main loop for the Reformulation & Decomposition
%       (R&D) algorithm to solve the optimistic variant of a BiMIP. It
%       iteratively solves a master problem (MP) to find a lower bound (LB)
%       and two subproblems (SP1, SP2) to find an upper bound (UB), until
%       the gap between the bounds converges.
%
%   Inputs:
%       model - struct: The standardized and preprocessed BiMIP model structure.
%       ops   - struct: A struct containing all solver options.
%
%   Output:
%       iteration_record - A struct containing the complete iteration history,
%                          including solutions to all intermediate problems,
%                          bounds, and the final optimal solution.

    tic;
    if isempty(model.D_l) && isempty(model.H_l)
        %% There are no integer vars in the lower level problem
        %% Let's start the BiLP process
        switch lower(ops.method)
            case 'exact_kkt' % Exact mode
                Solution = solveBiLPbyKKT(model, ops);
            case 'exact_strong_duality' % Exact mode
                Solution = solveBiLPbyStrongDuality(model, ops);
            case 'quick' % Quick mode
                Solution = solveBiLPbyPADM(model, ops);
            otherwise
                error('PowerBiMIP:UnknownMethod', 'Unknown method selected in options.');
        end
        iteration_record.optimal_solution.var = Solution.var;
        iteration_record.UB = Solution.obj;
        iteration_record.padm_log_chars = 0;
        if isfield(Solution,'padm_log_chars')
            iteration_record.padm_log_chars = Solution.padm_log_chars;
        end
    else
        %% Let's start the R&D process
        %% Initialization
        iteration_record.iteration_num = 0;
        iteration_record.LB = -inf;
        iteration_record.UB = inf;
        iteration_record.gap = []; % Store gap history as a decimal value
        iteration_record.master_problem_solution = cell(1, ops.max_iterations);
        iteration_record.subproblem_1_solution = cell(1, ops.max_iterations);
        iteration_record.subproblem_2_solution = cell(1, ops.max_iterations);
        iteration_record.optimal_solution_hat = cell(1, ops.max_iterations);
        
        % --- Setup for 'quick' mode ---
        is_quick_mode = strcmpi(ops.method, 'quick');
        gap_modifier = ''; % Suffix for gap display, e.g., ' (estimated)'
        if is_quick_mode
            gap_modifier = ' (estimated)';
        end
        
        % --- Initialize convergence plot using unified plotting tool ---
        plotData = struct();
        plotData.algorithm = 'R&D';
        plotData.iteration = [];
        plotData.UB = [];
        plotData.LB = [];
        plotData.gap = [];
        
        % Initialize plot if plotting is enabled (verbose >= 2)
        if ops.verbose >= 2 && ops.plot.verbose > 0
            plotHandles = plotConvergenceCurves(plotData, ops.plot, 'init'); % Handle stored internally
            iteration_record.figure_handles = plotHandles;
        end
        
        % --- Print iteration log header ---
        if ops.verbose >= 1
            fprintf('\n%s\n', repmat('-', 1, 95));
            fprintf('%6s | %12s %11s %11s | %11s %11s %11s | %8s\n',...
                'Iter', 'MP Obj', 'SP1 Obj', 'SP2 Obj', 'LB', 'UB', ['Gap' gap_modifier], 'Time(s)');
            fprintf('%s\n', repmat('-', 1, 95));
        end
        %% Main R&D Algorithm Loop
        while true
            %% Termination Condition: Max iterations
            if iteration_record.iteration_num + 1 > ops.max_iterations
                fprintf('\nMaximum iterations (%d) reached.\n', ops.max_iterations);
                break;
            end
            iteration_record.iteration_num = iteration_record.iteration_num + 1;
            curr_iter = iteration_record.iteration_num;
            
            %% Master Problem (MP)
            switch lower(ops.method)
                case 'exact_kkt' % Exact mode
                    iteration_record.master_problem_solution{curr_iter} = ...
                        master_problem_KKT(model, ops, iteration_record);
                case 'exact_strong_duality' % Exact mode
                    iteration_record.master_problem_solution{curr_iter} = ...
                        master_problem_strong_duality(model, ops, iteration_record);
                case 'quick' % Quick mode
                    iteration_record.master_problem_solution{curr_iter} = ...
                        master_problem_quick(model, ops, iteration_record);
                otherwise
                    error('PowerBiMIP:UnknownMethod', 'Unknown method selected in options.');
            end
            if iteration_record.master_problem_solution{curr_iter}.solution.problem ~= 0
                error('PowerBiMIP:SolverError', 'Master problem failed to solve in iter %d:\n%s', ...
                      curr_iter, yalmiperror(iteration_record.master_problem_solution{curr_iter}.solution.problem));
            end
            new_LB = max(iteration_record.LB(end), iteration_record.master_problem_solution{curr_iter}.objective);
            iteration_record.LB(end+1) = new_LB;
            
            %% Subproblem 1 (SP1)
            iteration_record.subproblem_1_solution{curr_iter} = subproblem1(model,...
                iteration_record.master_problem_solution{curr_iter}, ops);
            if iteration_record.subproblem_1_solution{curr_iter}.solution.problem ~= 0 
                error('PowerBiMIP:SolverError', 'Subproblem 1 failed to solve in iter %d:\n%s',...
                    curr_iter, yalmiperror(iteration_record.subproblem_1_solution{curr_iter}.solution.problem));
            end
            iteration_record.optimal_solution_hat{curr_iter}.D_l_vars = iteration_record.subproblem_1_solution{curr_iter}.D_l_vars;
            iteration_record.optimal_solution_hat{curr_iter}.H_l_vars = iteration_record.subproblem_1_solution{curr_iter}.H_l_vars;
            iteration_record.optimal_solution_hat{curr_iter}.c6_vars = iteration_record.subproblem_1_solution{curr_iter}.c6_vars;
    
            %% Subproblem 2 (SP2)
            % % Check for interdiction case: c3 = -c5 and c4 = -c6
            % % Using a small tolerance for floating point comparisons
            % tol = 1e-6;
            % is_interdiction = false;
            % 
            % % Check dimensions first
            % if length(model.c3) == length(model.c5) && length(model.c4) == length(model.c6)
            %     % Check if c3 approx -c5 AND c4 approx -c6
            %     if norm(model.c3 + model.c5) < tol && norm(model.c4 + model.c6) < tol
            %          is_interdiction = true;
            %     end
            % end
            % 
            % if is_interdiction
            %      if ops.verbose >= 1
            %         fprintf('  (Interdiction detected: skipping SP2)\n');
            %      end
            %      % SP2 is not needed, reuse SP1 solution
            %      iteration_record.subproblem_2_solution{curr_iter} = iteration_record.subproblem_1_solution{curr_iter};
            % else
                iteration_record.subproblem_2_solution{curr_iter} = subproblem2(model,...
                    iteration_record.master_problem_solution{curr_iter},...
                    iteration_record.subproblem_1_solution{curr_iter}, ops);
            % end
            
            % Ensure objective is scalar (handle empty or vector cases)
            if isempty(iteration_record.subproblem_2_solution{curr_iter}.objective)
                iteration_record.subproblem_2_solution{curr_iter}.objective = 0;
            elseif numel(iteration_record.subproblem_2_solution{curr_iter}.objective) > 1
                iteration_record.subproblem_2_solution{curr_iter}.objective = sum(iteration_record.subproblem_2_solution{curr_iter}.objective, 'all');
            end

            if iteration_record.subproblem_2_solution{curr_iter}.solution.problem == 0
                new_UB = min(iteration_record.UB(end), iteration_record.subproblem_2_solution{curr_iter}.objective);
                iteration_record.UB(end+1) = new_UB;
                iteration_record.optimal_solution_hat{curr_iter}.D_l_vars = iteration_record.subproblem_2_solution{curr_iter}.D_l_vars;
                iteration_record.optimal_solution_hat{curr_iter}.H_l_vars = iteration_record.subproblem_2_solution{curr_iter}.H_l_vars;
                iteration_record.optimal_solution_hat{curr_iter}.c6_vars = iteration_record.subproblem_2_solution{curr_iter}.c6_vars;
            else
                new_UB = iteration_record.UB(end);
                iteration_record.UB(end+1) = new_UB; 
                if ~is_quick_mode
                    warning('Subproblem 2 failed to solve in iter %d\n%s',...
                            curr_iter, yalmiperror(iteration_record.subproblem_2_solution{curr_iter}.solution.problem));
                end
            end
            
            %% Calculate Current Gap
            if isfinite(new_UB) && abs(new_UB) > 1e-9
                current_gap = (new_UB - new_LB) / abs(new_UB); % Gap as a decimal
            else
                current_gap = inf;
            end
            iteration_record.gap(end+1) = current_gap;
            
            %% PADM block clearing (quick mode only)
            padm_log_chars = 0;
            if isfield(iteration_record.master_problem_solution{curr_iter}, 'padm_log_chars')
                padm_log_chars = iteration_record.master_problem_solution{curr_iter}.padm_log_chars;
            end
            if ops.verbose >= 1 && ops.verbose <= 2 && padm_log_chars > 0
                log_utils('clear_last_n_chars', padm_log_chars);
            end

            %% Display Iteration Log
            if ops.verbose >= 1
                % Pre-format the gap string for display, converting decimal to percentage.
                gap_str_to_print = sprintf('%.2f%%', current_gap * 100);
                
                fprintf('%6d | %12.4f %11.4f %11.4f | %11.2f %11.2f %11s | %8.1f\n',...
                    curr_iter,...
                    iteration_record.master_problem_solution{curr_iter}.objective,...
                    iteration_record.subproblem_1_solution{curr_iter}.objective,...
                    iteration_record.subproblem_2_solution{curr_iter}.objective,...
                    new_LB,...
                    new_UB,...
                    gap_str_to_print,...
                    toc);
            end
            
            %% Update Convergence Plot
            if ops.verbose >= 2 && ops.plot.verbose > 0
                plotData.iteration = 1:(length(iteration_record.UB)-1);
                plotData.UB = iteration_record.UB(2:end);
                plotData.LB = iteration_record.LB(2:end);
                plotData.gap = iteration_record.gap * 100; % Convert to percentage
                plotConvergenceCurves(plotData, ops.plot, 'update');
            end
            
            %% Termination Condition: Convergence
            converged = false;
            % Compare the decimal gap with the decimal tolerance.
            if is_quick_mode
                if current_gap < ops.optimal_gap || new_LB > new_UB
                    converged = true;
                    if ops.verbose >= 1
                        fprintf('Quick mode convergence condition met.\n');
                    end
                end
            else
                if current_gap < ops.optimal_gap
                    converged = true;
                end
            end
            
            if converged
                if ops.verbose >= 1
                    % Convert gaps to percentages for the final message.
                    fprintf('\nConvergence criteria met (gap%s = %.2f%% <= %.2f%%).\n',...
                        gap_modifier, current_gap * 100, ops.optimal_gap * 100);
                end
                break;
            end
        end

        %% Final Solution Summary
        total_time = toc;
        
        % --- Final plot save (only if verbose >= 2) ---
        if ops.verbose >= 2 && ops.plot.verbose > 0
            plotData.iteration = 1:(length(iteration_record.UB)-1);
            plotData.UB = iteration_record.UB(2:end);
            plotData.LB = iteration_record.LB(2:end);
            plotData.gap = iteration_record.gap * 100;
            plotConvergenceCurves(plotData, ops.plot, 'final');
        end
        
        if ops.verbose >= 1
            % Pre-format the final gap string for display, converting decimal to percentage.
            final_gap_str = sprintf('%.2f%%%s', iteration_record.gap(end) * 100, gap_modifier);
    
            fprintf('%s\n', repmat('-', 1, 95));
            fprintf('Solution Summary:\n');
            fprintf('  Objective value: %-15.4f\n', iteration_record.UB(end));
            fprintf('  Best bound:      %-15.4f\n', iteration_record.LB(end));
            fprintf('  Gap:             %s\n', final_gap_str);
            fprintf('  Iterations:      %d\n', iteration_record.iteration_num);
            fprintf('  Time elapsed:    %.2f seconds\n', total_time);
            fprintf('%s\n', repmat('-', 1, 95));
        end
        
        %% Finalize Output Record
        iteration_record.master_problem_solution = iteration_record.master_problem_solution(1:iteration_record.iteration_num);
        iteration_record.subproblem_1_solution = iteration_record.subproblem_1_solution(1:iteration_record.iteration_num);
        iteration_record.subproblem_2_solution = iteration_record.subproblem_2_solution(1:iteration_record.iteration_num);
        iteration_record.optimal_solution_hat = iteration_record.optimal_solution_hat(1:iteration_record.iteration_num);
        objectives = cellfun(@(s) s.objective, iteration_record.subproblem_2_solution, 'UniformOutput', false);
        objectives(cellfun(@isempty, objectives)) = {inf};
        objectives = cell2mat(objectives);
        [~, idx_flipped] = min(flip(objectives));
        selected_index = numel(objectives) - idx_flipped + 1;
        iteration_record.optimal_solution.var = iteration_record.subproblem_2_solution{selected_index}.var;
        iteration_record.total_time = total_time;
    end
end