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

    solver_start_time = tic;
    if isempty(model.D_l) && isempty(model.H_l)
        %% There are no integer vars in the lower level problem
        %% Solve BiLP directly
        switch lower(ops.method)
            case 'exact_kkt'
                Solution = solveBiLPbyKKT(model, ops);
            case 'exact_strong_duality'
                Solution = solveBiLPbyStrongDuality(model, ops);
            case 'quick'
                Solution = solveBiLPbyPADM2(model, ops);
            otherwise
                error('PowerBiMIP:UnknownMethod', 'Unknown method selected in options.');
        end
    
        total_time = toc(solver_start_time);
    
        %% ---- Fill iteration_record in a unified way ----
        iteration_record.iteration_num = 1;
        iteration_record.UB  = Solution.obj;
        iteration_record.LB  = Solution.obj;
        iteration_record.gap = 0;
    
        iteration_record.optimal_solution.var = Solution.var;
        if isfield(Solution, 'master_type')
            iteration_record.master_type = {Solution.master_type};
        else
            iteration_record.master_type = {lower(ops.method)};
        end
    
        iteration_record.padm_log_chars = 0;
        if isfield(Solution,'padm_log_chars')
            iteration_record.padm_log_chars = Solution.padm_log_chars;
        end
    
        %% ---- Print Solution Summary (same style as R&D) ----
        if ops.verbose >= 1
            gap_modifier = '';   % no estimation here
            final_gap_str = sprintf('%.2f%%%s', iteration_record.gap * 100, gap_modifier);
    
            fprintf('%s\n', repmat('-', 1, 74));
            fprintf('Solution Summary:\n');
            fprintf('  Objective value: %-15.4f\n', iteration_record.UB);
            fprintf('  Best bound:      %-15.4f\n', iteration_record.LB);
            fprintf('  Gap:             %s\n', final_gap_str);
            fprintf('  Iterations:      %d\n', iteration_record.iteration_num);
            fprintf('  Time elapsed:    %.2f seconds\n', total_time);
            fprintf('%s\n', repmat('-', 1, 74));
        end
    
        iteration_record.total_time = total_time;
        return;
    end
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
    iteration_record.iteration_time = zeros(1, ops.max_iterations);
    iteration_record.elapsed_time = zeros(1, ops.max_iterations);
    iteration_record.master_type = cell(1, ops.max_iterations);
    
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
        iter_start_time = tic;

        tol = 1e-6;
        has_upper_coupling = has_upper_coupled_constraints(model, tol);
        has_opposite_objectives = opposite_objective_coefficients( ...
            model.c3, model.c3_vars, model.c5, model.c5_vars, tol) && ...
            opposite_objective_coefficients( ...
            model.c4, model.c4_vars, model.c6, model.c6_vars, tol);
        upper_linking_binary = all_upper_linking_vars_binary_or_absent(model);
        is_interdiction = has_opposite_objectives && ~has_upper_coupling && has_lower_integer_variables(model);
        use_interdiction_route = is_interdiction && ~use_standard_interdiction_flow(ops);
        effective_method = lower(ops.method);
        if use_interdiction_route && strcmpi(effective_method, 'exact_kkt')
            effective_method = 'exact_strong_duality';
        end
        
        %% Master Problem (MP)
        use_interdiction_ccg = use_interdiction_route && isfield(ops, 'interdiction_master') && ...
            strcmpi(ops.interdiction_master, 'paper_ccg');
        if use_interdiction_ccg && strcmpi(effective_method, 'quick')
            iteration_record.master_problem_solution{curr_iter} = ...
                master_problem_interdiction_quick(model, ops, iteration_record);
        elseif use_interdiction_ccg && upper_linking_binary
            iteration_record.master_problem_solution{curr_iter} = ...
                master_problem_interdiction_ccg(model, ops, iteration_record);
        else
            if use_interdiction_ccg && ops.verbose >= 1
                fprintf('  (Interdiction exact C&CG skipped: upper variables in lower RHS are not binary-safe)\n');
            end
            switch effective_method
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
        end
        if isfield(iteration_record.master_problem_solution{curr_iter}, 'master_type')
            iteration_record.master_type{curr_iter} = iteration_record.master_problem_solution{curr_iter}.master_type;
        else
            iteration_record.master_type{curr_iter} = effective_method;
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
        % Interdiction/max-min models with no upper-level coupled constraints
        % often have opposite upper/lower lower-level objective coefficients:
        % c3 = -c5 and c4 = -c6. In that case SP1 already returns the
        % follower's optimal response, and the valid upper bound is the upper
        % objective evaluated at that response. If upper-level constraints
        % contain lower-level variables, SP2 must still be solved because it
        % enforces those coupled upper constraints.
        if use_interdiction_route
            iteration_record.subproblem_2_solution{curr_iter} = iteration_record.subproblem_1_solution{curr_iter};
            upper_fixed_obj = [model.c1', model.c2'] * ...
                [iteration_record.master_problem_solution{curr_iter}.c1_vars; ...
                 iteration_record.master_problem_solution{curr_iter}.c2_vars];
            iteration_record.subproblem_2_solution{curr_iter}.objective = ...
                upper_fixed_obj - iteration_record.subproblem_1_solution{curr_iter}.objective;
        else
            iteration_record.subproblem_2_solution{curr_iter} = subproblem2(model,...
                iteration_record.master_problem_solution{curr_iter},...
                iteration_record.subproblem_1_solution{curr_iter}, ops);
        end
        
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
                % 允许SP2不可行
                warning('Subproblem 2 failed to solve in iter %d\n%s',...
                        curr_iter, yalmiperror(iteration_record.subproblem_2_solution{curr_iter}.solution.problem));
            end
        end
        
        %% Calculate Current Gap
        current_gap = bounded_relative_gap(new_LB, new_UB);
        iteration_record.gap(end+1) = current_gap;
        iteration_record.iteration_time(curr_iter) = toc(iter_start_time);
        iteration_record.elapsed_time(curr_iter) = toc(solver_start_time);

        if use_interdiction_route && isfield(iteration_record.master_problem_solution{curr_iter}, 'quick_backend')
            iteration_record.master_problem_solution{curr_iter}.quick_sp1_objective = ...
                iteration_record.subproblem_1_solution{curr_iter}.objective;
            iteration_record.master_problem_solution{curr_iter}.quick_sp1_upper_bound = ...
                iteration_record.subproblem_2_solution{curr_iter}.objective;
        end

        if use_interdiction_route && is_quick_mode && ops.verbose >= 2 && ...
                isfield(ops, 'plot') && isfield(ops.plot, 'verbose') && ops.plot.verbose >= 2
            plot_interdiction_quick_history(iteration_record.master_problem_solution{curr_iter}, ...
                ops.plot, curr_iter);
        end
        
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
                iteration_record.elapsed_time(curr_iter));
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
            if abs(current_gap) < ops.optimal_gap
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
    total_time = toc(solver_start_time);
    
    % --- Final plot save (only if verbose >= 2) ---
    if ops.verbose >= 2 && ops.plot.verbose > 0
        plotData.iteration = 1:(length(iteration_record.UB)-1);
        plotData.UB = iteration_record.UB(2:end);
        plotData.LB = iteration_record.LB(2:end);
        plotData.gap = iteration_record.gap * 100;
        plotConvergenceCurves(plotData, ops.plot, 'final');
    end

    if is_quick_mode && ops.verbose >= 2 && isfield(ops, 'plot') && ...
            isfield(ops.plot, 'verbose') && ops.plot.verbose > 0
        plot_all_interdiction_quick_histories(iteration_record, ops.plot);
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
    iteration_record.iteration_time = iteration_record.iteration_time(1:iteration_record.iteration_num);
    iteration_record.elapsed_time = iteration_record.elapsed_time(1:iteration_record.iteration_num);
    iteration_record.master_type = iteration_record.master_type(1:iteration_record.iteration_num);
    objectives = cellfun(@(s) s.objective, iteration_record.subproblem_2_solution, 'UniformOutput', false);
    objectives(cellfun(@isempty, objectives)) = {inf};
    objectives = cell2mat(objectives);
    if any(isfinite(objectives))
        [~, idx_flipped] = min(flip(objectives));
        selected_index = numel(objectives) - idx_flipped + 1;
        iteration_record.optimal_solution.var = iteration_record.subproblem_2_solution{selected_index}.var;
    else
        iteration_record.optimal_solution.var = [];
    end
    iteration_record.total_time = total_time;
end

function plot_interdiction_quick_history(master_solution, plot_options, curr_iter)
if ~isstruct(master_solution) || ~isfield(master_solution, 'quick_history') || ...
        isempty(master_solution.quick_history)
    return;
end

save_path = '';
if isfield(plot_options, 'saveFig') && plot_options.saveFig
    save_dir = 'results/figures';
    if isfield(plot_options, 'saveDir') && ~isempty(plot_options.saveDir)
        save_dir = plot_options.saveDir;
    end
    save_path = fullfile(save_dir, sprintf('interdiction_quick_inner_iter_%03d.png', curr_iter));
end

plotInterdictionQuickInnerHistory(master_solution.quick_history, ...
    'Visible', 'on', ...
    'SavePath', save_path, ...
    'Title', sprintf('Interdiction quick inner iteration %d', curr_iter));
drawnow;
end

function plot_all_interdiction_quick_histories(iteration_record, plot_options)
if ~isfield(iteration_record, 'master_problem_solution') || ...
        isempty(iteration_record.master_problem_solution)
    return;
end

for idx = 1:numel(iteration_record.master_problem_solution)
    plot_interdiction_quick_history(iteration_record.master_problem_solution{idx}, ...
        plot_options, idx);
end
end

function tf = has_lower_integer_variables(model)
tf = (isfield(model, 'var_z_l') && ~isempty(model.var_z_l)) || ...
     (isfield(model, 'D_l_vars') && ~isempty(model.D_l_vars)) || ...
     (isfield(model, 'H_l_vars') && ~isempty(model.H_l_vars)) || ...
     (isfield(model, 'c6_vars') && ~isempty(model.c6_vars));
end

function tf = use_standard_interdiction_flow(ops)
tf = isfield(ops, 'force_standard_interdiction') && ...
     ~isempty(ops.force_standard_interdiction) && ...
     logical(ops.force_standard_interdiction);
end

function gap = bounded_relative_gap(lower_bound, upper_bound)
%BOUNDED_RELATIVE_GAP Symmetric bound gap in [0, 1] for valid finite bounds.
if isfinite(lower_bound) && isfinite(upper_bound)
    width = max(0, upper_bound - lower_bound);
    if width <= 1e-9
        gap = 0;
    else
        gap = width / max(abs(lower_bound) + abs(upper_bound), 1e-9);
    end
else
    gap = inf;
end
end

function tf = opposite_objective_coefficients(coeff_a, vars_a, coeff_b, vars_b, tol)
%OPPOSITE_OBJECTIVE_COEFFICIENTS Compare sparse objective vectors by variable id.
% Objective extraction can omit zero-coefficient variables from one side.
% This helper aligns both coefficient vectors on YALMIP's variable ids and
% then checks coeff_a + coeff_b == 0.

ids_a = get_var_ids(vars_a);
ids_b = get_var_ids(vars_b);
ids = union(ids_a, ids_b);

vec_a = zeros(numel(ids), 1);
vec_b = zeros(numel(ids), 1);

for i = 1:numel(ids_a)
    pos = find(ids == ids_a(i), 1);
    vec_a(pos) = vec_a(pos) + coeff_a(i);
end
for i = 1:numel(ids_b)
    pos = find(ids == ids_b(i), 1);
    vec_b(pos) = vec_b(pos) + coeff_b(i);
end

tf = norm(vec_a + vec_b, inf) < tol;
end

function ids = get_var_ids(vars)
if isempty(vars)
    ids = [];
else
    ids = getvariables(vars(:)).';
end
end

function tf = all_upper_linking_vars_binary_or_absent(model)
%ALL_UPPER_LINKING_VARS_BINARY_OR_ABSENT Guard paper C&CG big-M products.
% The interdiction shortcut is valid for binary upper linking variables.

vars = [];
if isfield(model, 'A_l_vars') && ~isempty(model.A_l_vars)
    vars = [vars; model.A_l_vars(:)];
end
if isfield(model, 'B_l_vars') && ~isempty(model.B_l_vars)
    vars = [vars; model.B_l_vars(:)];
end
if isfield(model, 'E_l_vars') && ~isempty(model.E_l_vars)
    vars = [vars; model.E_l_vars(:)];
end
if isfield(model, 'F_l_vars') && ~isempty(model.F_l_vars)
    vars = [vars; model.F_l_vars(:)];
end

if isempty(vars)
    tf = true;
    return;
end

tf = true;
for i = 1:numel(vars)
    if ~is(vars(i), 'binary')
        tf = false;
        return;
    end
end
end

function tf = has_upper_coupled_constraints(model, tol)
%HAS_UPPER_COUPLED_CONSTRAINTS True when upper constraints use lower vars.
% Prefer the original classifier result because preprocessing can transform
% coupled constraints away, while the interdiction shortcut is only safe for
% models that were uncoupled at the upper level to begin with.

if isfield(model, 'original_has_upper_coupled_constraints')
    tf = logical(model.original_has_upper_coupled_constraints);
    return;
end

tf = matrix_has_nonzero(model, 'C_u', tol) || ...
     matrix_has_nonzero(model, 'D_u', tol) || ...
     matrix_has_nonzero(model, 'G_u', tol) || ...
     matrix_has_nonzero(model, 'H_u', tol);
end

function tf = matrix_has_nonzero(model, field_name, tol)
if isfield(model, field_name) && ~isempty(model.(field_name))
    tf = any(abs(model.(field_name)(:)) > tol);
else
    tf = false;
end
end
