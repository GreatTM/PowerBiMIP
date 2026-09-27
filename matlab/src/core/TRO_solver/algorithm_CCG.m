function CCG_record = algorithm_CCG(model, ops, u_init)
%ALGORITHM_CCG Implements the main loop controller for C&CG algorithm (TRO-LP with RCR).
%
%   Description:
%       This function implements the main loop for the Column-and-Constraint
%       Generation (C&CG) algorithm to solve two-stage robust optimization
%       problems with linear programming recourse (TRO-LP), assuming relatively
%       complete response (RCR). It iteratively solves a master problem (MP)
%       to find a lower bound (LB) and a subproblem (SP) to find an upper
%       bound (UB), until the relative gap between the bounds converges.
%
%   Inputs:
%       model - struct: The standardized robust model structure extracted by
%                       extract_robust_coeffs (containing first-stage/second-stage
%                       coefficients, uncertainty set, variables, statistics).
%       ops   - struct: A struct containing all solver options (from
%                       TROsettings), including gap_tol, max_iterations,
%                       verbose, mode, solver, etc.
%       u_init - (Optional) Initial value for uncertainty variable u (numeric vector).
%                If provided, the first iteration will include this scenario.
%
%   Output:
%       Robust_record - A struct containing the complete iteration history,
%                       including bounds, worst-case scenarios, convergence trace,
%                       cuts count, runtime, and the final optimal solution.
%
%   See also CCG_master_problem, CCG_subproblem, TROsettings

    tic;
    
    %% Initialization
    iteration_record.iteration_num = 0;
    iteration_record.LB = -inf;
    iteration_record.UB = inf;
    iteration_record.gap = []; % Store gap history as a decimal value
    iteration_record.scenario_set = {}; % Cell array to store worst-case scenarios u*
    iteration_record.master_problem_solution = cell(1, ops.max_iterations);
    iteration_record.subproblem_solution = cell(1, ops.max_iterations);
    iteration_record.worst_case_u_history = cell(1, ops.max_iterations);
    
    % Store initial scenario if provided
    iteration_record.u_init = u_init;
    
    % Initialize worst_case_u_history with u_init if provided
    if ~isempty(u_init)
        iteration_record.worst_case_u_history{1} = u_init;
    end
    
    % Pre-allocate trace arrays
    maxIter = ops.max_iterations;
    trace_lb = zeros(maxIter, 1);
    trace_ub = zeros(maxIter, 1);
    trace_gap = zeros(maxIter, 1);
    trace_time = zeros(maxIter, 1);
    
    % --- Initialize convergence plot using unified plotting tool ---
    plotData = struct();
    plotData.algorithm = 'C&CG';
    plotData.iteration = [];
    plotData.UB = [];
    plotData.LB = [];
    plotData.gap = [];
    
    if ops.verbose >= 2 && ops.plot.verbose > 0
        plotHandles = plotConvergenceCurves(plotData, ops.plot, 'init'); %#ok<NASGU> % Handle stored internally via setappdata
    end
    
    % --- Print iteration log header ---
    if ops.verbose >= 1
        fprintf('\n%s\n', repmat('-', 1, 95));
        fprintf('%6s | %12s %11s | %11s %11s %11s | %8s\n',...
            'Iter', 'MP Obj', 'SP Obj', 'LB', 'UB', 'Gap(%)', 'Time(s)');
        fprintf('%s\n', repmat('-', 1, 95));
    end

    iter_tic = tic;

    %% Main Algorithm Loop
    while true
        %% Termination Condition: Max iterations
        if iteration_record.iteration_num + 1 > ops.max_iterations
            if ops.verbose >= 1
                fprintf('\nMaximum iterations (%d) reached.\n', ops.max_iterations);
            end
            break;
        end
        iteration_record.iteration_num = iteration_record.iteration_num + 1;
        curr_iter = iteration_record.iteration_num;
        
        %% Master Problem (MP)
        % Call CCG_master_problem to solve the master problem
        mp_result = CCG_master_problem(model, ops, iteration_record);
        
        if mp_result.solution.problem ~= 0
            error('PowerBiMIP:SolverError', 'Master problem failed to solve in iter %d:\n%s', ...
                curr_iter, yalmiperror(mp_result.solution.problem));
        end

        iteration_record.master_problem_solution{curr_iter} = mp_result;
        
        % Extract MP solution
        % y_star is now a struct containing all y-related variable solutions
        y_star = mp_result.y_star;
        eta_star = mp_result.eta_star;
        mp_objective = mp_result.objective; % Total MP objective: c^T y* + eta* (or just c^T y* if no eta)
        
        % Extract first-stage objective c^T y* (needed for UB calculation)
        first_stage_obj = 0;
        if isfield(mp_result, 'first_stage_obj')
            first_stage_obj = mp_result.first_stage_obj;
        elseif ~isempty(eta_star) && ~isempty(mp_objective)
            % Fallback: approximate as MP objective minus eta*
            first_stage_obj = mp_objective - eta_star;
        elseif ~isempty(mp_objective)
            % If no eta_star, then mp_objective is just first_stage_obj
            first_stage_obj = mp_objective;
        end
        
        % Update lower bound: LB = c^T y* + eta* (or just c^T y* if no eta)
        new_LB = max(mp_objective, iteration_record.LB(end));
        
        iteration_record.LB(end+1) = new_LB;
        trace_lb(curr_iter) = new_LB;
        
        %% Subproblem (SP)
        % Call CCG_subproblem to solve the subproblem (find worst-case u)
        sp_result = CCG_subproblem(model, ops, y_star, iteration_record);
        if sp_result.solution.problem ~= 0
            error('PowerBiMIP:SolverError', 'Subproblem failed to solve in iter %d:\n%s', ...
                curr_iter, yalmiperror(sp_result.solution.problem));
        end
        iteration_record.subproblem_solution{curr_iter} = sp_result;
        
        % Extract SP solution
        u_star = sp_result.u_star;
        Q_value = sp_result.Q_value; % Q(y*)
        
        candidate_UB = first_stage_obj + Q_value;
        new_UB = min(iteration_record.UB(end), candidate_UB);

        iteration_record.UB(end+1) = new_UB;
        trace_ub(curr_iter) = new_UB;
        
        % Store worst-case scenario
        if ~isempty(u_star)
            iteration_record.scenario_set{curr_iter} = u_star;
            % If u_init was provided, the history index shifts
            if ~isempty(u_init)
                iteration_record.worst_case_u_history{curr_iter + 1} = u_star;
            else
                iteration_record.worst_case_u_history{curr_iter} = u_star;
            end
        end
        
        %% Calculate Current Gap
        % Relative gap: Gap = (UB - LB) / UB
        if isfinite(new_UB) && abs(new_UB) > 1e-9
            current_gap = (new_UB - new_LB) / abs(new_UB);
        elseif abs(new_UB) <= 1e-9 && abs(new_LB) <= 1e-9
            % Both bounds are near zero
            current_gap = 0;
        else
            % Use absolute gap as fallback
            current_gap = abs(new_UB - new_LB);
        end
        iteration_record.gap(end+1) = current_gap;
        trace_gap(curr_iter) = current_gap;
        
        %% Record iteration time
        iter_time = toc(iter_tic);
        trace_time(curr_iter) = iter_time;
        
        %% Print iteration information
        if ops.verbose >= 1
            mp_obj_str = 'N/A';
            if ~isempty(mp_objective)
                mp_obj_str = sprintf('%.4f', mp_objective);
            end
            sp_obj_str = 'N/A';
            if ~isempty(Q_value)
                sp_obj_str = sprintf('%.4f', Q_value);
            end
            gap_pct = current_gap * 100;
            fprintf('%6d | %12s %11s | %11.4f %11.4f %10.4f%% | %8.3f\n',...
                curr_iter, mp_obj_str, sp_obj_str, new_LB, new_UB, gap_pct, iter_time);
        end
        
        %% Update Convergence Plot
        if ops.verbose >= 2 && ops.plot.verbose > 0
            plotData.iteration = 1:curr_iter;
            plotData.UB = trace_ub(1:curr_iter);
            plotData.LB = trace_lb(1:curr_iter);
            plotData.gap = trace_gap(1:curr_iter) * 100; % Convert to percentage
            plotConvergenceCurves(plotData, ops.plot, 'update');
        end
        
        %% Convergence Check
        if current_gap <= ops.gap_tol
            if ops.verbose >= 1
                fprintf('\nConverged! Relative gap (%.4f%%) <= tolerance (%.4f%%).\n',...
                    gap_pct, ops.gap_tol * 100);
            end
            break;
        end
        
        % If not converged, the next iteration will add a new cut
        % CCG_master_problem will automatically add cuts based on iteration_record.iteration_num
    end
    
    %% Finalize Robust_record
    total_runtime = toc;
    
    % Trim trace arrays to actual iteration count
    actual_iter = iteration_record.iteration_num;
    
    % --- Final plot save (only if verbose >= 2) ---
    if ops.verbose >= 2 && ops.plot.verbose > 0
        plotData.iteration = 1:actual_iter;
        plotData.UB = trace_ub(1:actual_iter);
        plotData.LB = trace_lb(1:actual_iter);
        plotData.gap = trace_gap(1:actual_iter) * 100;
        plotConvergenceCurves(plotData, ops.plot, 'final');
    end
    
    CCG_record.master_problem_solution = iteration_record.master_problem_solution;
    CCG_record.subproblem_solution = iteration_record.subproblem_solution;
    CCG_record.convergence_trace.lb = trace_lb(1:actual_iter);
    CCG_record.convergence_trace.ub = trace_ub(1:actual_iter);
    CCG_record.convergence_trace.gap = trace_gap(1:actual_iter);
    CCG_record.convergence_trace.time = trace_time(1:actual_iter);
    CCG_record.convergence_trace.iterations = 1:actual_iter;
    
    % Final solution information
    CCG_record.obj_val = iteration_record.UB;
    CCG_record.UB = iteration_record.UB;
    CCG_record.LB = iteration_record.LB;
    
    % Extract optimal y* from last MP solution
    if actual_iter > 0 && ~isempty(iteration_record.master_problem_solution{actual_iter})
        last_mp = iteration_record.master_problem_solution{actual_iter};
        if isfield(last_mp, 'y_star') && ~isempty(last_mp.y_star)
            CCG_record.y_opt = last_mp.y_star;
        else
            CCG_record.y_opt = [];
        end
        
        % Extract optimal solution structure for variable mapping
        if isfield(last_mp, 'mp_solution') && isstruct(last_mp.mp_solution)
            CCG_record.optimal_solution = last_mp.mp_solution;
        else
            CCG_record.optimal_solution = struct();
        end
    else
        CCG_record.y_opt = [];
        CCG_record.optimal_solution = struct();
    end
    
    % Worst-case scenario history
    % If u_init exists, worst_case_u_history has length actual_iter + 1
    if ~isempty(u_init)
        CCG_record.worst_case_u_history = iteration_record.worst_case_u_history(1:actual_iter + 1);
    else
        CCG_record.worst_case_u_history = iteration_record.worst_case_u_history(1:actual_iter);
    end
    
    % Cuts count (equal to number of iterations, since each iteration adds one cut)
    CCG_record.cuts_count = actual_iter;
    
    % Runtime
    CCG_record.runtime = total_runtime;
    
    % Final convergence message
    if ops.verbose >= 1
        fprintf('\n%s\n', repmat('-', 1, 95));
        fprintf('Final Results:\n');
        fprintf('  Lower Bound (LB): %.6f\n', CCG_record.LB(end));
        fprintf('  Upper Bound (UB): %.6f\n', CCG_record.UB(end));
        if actual_iter > 0
            final_gap = CCG_record.convergence_trace.gap(end);
            fprintf('  Final Gap:       %.4f%%\n', final_gap * 100);
        end
        fprintf('  Total Iterations: %d\n', actual_iter);
        fprintf('  Total Runtime:    %.3f seconds\n', total_runtime);
        fprintf('%s\n', repmat('-', 1, 95));
    end
end
