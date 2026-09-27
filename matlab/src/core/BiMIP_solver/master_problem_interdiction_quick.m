function [Solution] = master_problem_interdiction_quick(model, ops, iteration_record)
%MASTER_PROBLEM_INTERDICTION_QUICK Quick C&CG master for interdiction models.
%
% This quick master uses a penalty alternating scheme for the
% dual-times-upper RHS bilinear terms.

fixed_points = collect_fixed_lower_integer_points(iteration_record);
if isempty(fixed_points)
    Solution = solve_relaxed_master(model, ops);
    Solution.master_type = 'interdiction_ccg_quick_relaxed';
    Solution.penalized_objective = Solution.objective;
    Solution.quick_residual = 0;
    Solution.quick_history = empty_quick_history();
    Solution.quick_alternations = 0;
    Solution.quick_fixed_point_count = 0;
    Solution.padm_log_chars = 0;
    return;
end

Solution = solve_penalty_alternating_master(model, ops, iteration_record, fixed_points);
Solution.quick_fixed_point_count = numel(fixed_points);
end

function Solution = solve_penalty_alternating_master(model, ops, iteration_record, fixed_points)
max_alt = get_option(ops, 'interdiction_quick_max_alternations', 20);
tol = get_option(ops, 'interdiction_quick_tolerance', 1e-4);
residual_tol = get_option(ops, 'interdiction_quick_residual_tolerance', 1e-4);
rho = get_option(ops, 'interdiction_quick_penalty_rho', 50);
rho_growth = get_option(ops, 'interdiction_quick_penalty_growth', 2);
rho_max = get_option(ops, 'interdiction_quick_penalty_max', 1e6);
bigM = get_interdiction_bigM(model, ops);

start_points = initial_upper_points(model, ops, iteration_record);
best_solution = [];
start_summary = empty_start_summary();
padm_log_chars = 0;

for start_idx = 1:numel(start_points)
    trial = solve_alternating_from_start(model, ops, fixed_points, start_points{start_idx}, ...
        bigM, rho, rho_growth, rho_max, max_alt, tol, residual_tol);
    padm_log_chars = padm_log_chars + trial.padm_log_chars;
    candidate = collect_master_solution(model, trial.last_solution.solution, ...
        trial.last_solution.core_objective);
    candidate.eta = trial.last_solution.eta;
    candidate.master_type = 'interdiction_ccg_quick_penalty_alternating';
    candidate.penalized_objective = trial.last_solution.penalized_objective;
    candidate.quick_residual = trial.last_solution.residual;
    candidate.quick_alternations = numel(trial.quick_history);
    candidate.quick_history = trial.quick_history;
    candidate.quick_start_index = start_idx;
    candidate.quick_start_count = numel(start_points);
    candidate.padm_log_chars = trial.padm_log_chars;

    start_summary(end+1) = make_start_summary_entry(start_idx, candidate); %#ok<AGROW>
    if is_better_quick_solution(candidate, best_solution, residual_tol)
        best_solution = candidate;
    end
end

Solution = best_solution;
Solution.quick_backend = 'penalty_alternating';
Solution.quick_status = 'penalty_alternating';
Solution.quick_start_summary = start_summary;
Solution.padm_log_chars = padm_log_chars;
end

function trial = solve_alternating_from_start(model, ops, fixed_points, initial_upper, ...
    bigM, initial_rho, rho_growth, rho_max, max_alt, tol, residual_tol)
current_upper = initial_upper;
rho = initial_rho;
dual_starts = max(1, round(get_option(ops, 'interdiction_quick_dual_starts', 1)));
dual_tiebreak_weight = get_option(ops, 'interdiction_quick_dual_tiebreak_weight', 0);
random_seed = round(get_option(ops, 'interdiction_quick_random_seed', 1));
last_core = inf;
last_residual = inf;
quick_history = empty_quick_history();
padm_log_chars = 0;

for alt = 1:max_alt
    best_step_a = [];
    best_step_b = [];
    for dual_idx = 1:dual_starts
        perturb_seed = random_seed + 100000 * alt + dual_idx;
        step_a = solve_fixed_upper_step(model, ops, fixed_points, current_upper, ...
            bigM, rho, perturb_seed, dual_tiebreak_weight);
        step_b = solve_fixed_dual_step(model, ops, fixed_points, step_a, rho);
        if isempty(best_step_b) || step_b.core_objective < best_step_b.core_objective - 1e-8
            best_step_a = step_a;
            best_step_b = step_b;
        end
    end
    step_a = best_step_a;
    step_b = best_step_b;

    new_upper = upper_values_from_model(model);
    padm_step_b = step_b;
    escape = empty_neighbor_escape();
    padm_upper_diff = relative_upper_diff(current_upper, new_upper);
    if should_run_neighbor_search(ops, step_a, step_b, padm_upper_diff, tol)
        escape = solve_neighbor_escape_step(model, ops, new_upper, step_b, rho, tol);
        if escape.improved
            step_b = escape.step;
            new_upper = escape.upper;
        end
    end

    upper_diff = relative_upper_diff(current_upper, new_upper);
    core_diff = relative_value_diff(last_core, step_b.core_objective);

    quick_history(end+1) = make_history_entry(alt, rho, step_a, padm_step_b, ...
        step_b, escape, upper_diff, core_diff); %#ok<AGROW>
    padm_log_chars = padm_log_chars + print_padm_progress(ops, alt, step_a, ...
        step_b, upper_diff);

    current_upper = new_upper;
    last_solution = step_b;

    if step_b.residual <= residual_tol && upper_diff <= tol && core_diff <= tol
        padm_log_chars = padm_log_chars + print_padm_converged(ops);
        break;
    end

    if step_b.residual > residual_tol && isfinite(last_residual) && ...
            step_b.residual >= 0.9 * last_residual && rho < rho_max
        rho = min(rho * rho_growth, rho_max);
    end

    last_core = step_b.core_objective;
    last_residual = step_b.residual;
end

trial.last_solution = last_solution;
trial.quick_history = quick_history;
trial.padm_log_chars = padm_log_chars;
end

function step = solve_fixed_upper_step(model, ops, fixed_points, current_upper, bigM, rho, perturb_seed, tiebreak_weight)
constraints = [];
eta = sdpvar(1, 1, 'full');
alpha_ineq = numeric_upper_term([model.A_l, model.B_l], ...
    [current_upper.A_l_vars; current_upper.B_l_vars], model.length_b_l);
beta_eq = numeric_upper_term([model.E_l, model.F_l], ...
    [current_upper.E_l_vars; current_upper.F_l_vars], model.length_f_l);

residual_expr = 0;
dual_tiebreak_expr = 0;
step.dual_ineq = cell(numel(fixed_points), 1);
step.dual_eq = cell(numel(fixed_points), 1);
step.p_ineq = cell(numel(fixed_points), 1);
step.q_eq = cell(numel(fixed_points), 1);

previous_rng = rng;
cleanup = onCleanup(@() rng(previous_rng));
rng(perturb_seed, 'twister');

for k = 1:numel(fixed_points)
    dual_ineq = sdpvar(model.length_b_l, 1, 'full');
    dual_eq = sdpvar(model.length_f_l, 1, 'full');
    p_ineq = sdpvar(model.length_b_l, 1, 'full');
    q_eq = sdpvar(model.length_f_l, 1, 'full');
    residual_p = sdpvar(model.length_b_l, 1, 'full');
    residual_q = sdpvar(model.length_f_l, 1, 'full');

    constraints = constraints + dual_feasibility_constraints(model, dual_ineq, dual_eq);
    constraints = constraints + dual_bound_constraints(dual_ineq, dual_eq, bigM);

    if model.length_b_l > 0
        constraints = constraints + (residual_p >= 0) + ...
            (residual_p >= p_ineq - dual_ineq .* alpha_ineq) + ...
            (residual_p >= -p_ineq + dual_ineq .* alpha_ineq);
    end
    if model.length_f_l > 0
        constraints = constraints + (residual_q >= 0) + ...
            (residual_q >= q_eq - dual_eq .* beta_eq) + ...
            (residual_q >= -q_eq + dual_eq .* beta_eq);
    end

    constraints = constraints + interdiction_cut(model, fixed_points(k), ...
        dual_ineq, dual_eq, p_ineq, q_eq, eta);
    residual_expr = residual_expr + sum(residual_p) + sum(residual_q);
    dual_tiebreak_expr = dual_tiebreak_expr + ...
        random_linear_expr(dual_ineq) + random_linear_expr(dual_eq);

    step.dual_ineq{k} = dual_ineq;
    step.dual_eq{k} = dual_eq;
    step.p_ineq{k} = p_ineq;
    step.q_eq{k} = q_eq;
end

core_expr = upper_objective_numeric(model, current_upper) + eta;
penalized_expr = core_expr + rho * residual_expr;
solve_expr = penalized_expr + tiebreak_weight * dual_tiebreak_expr;
diag = optimize(constraints, solve_expr, ops.ops_MP);
if diag.problem ~= 0
    error('PowerBiMIP:InterdictionQuick', ...
        'Fixed-upper penalty step failed: %s', yalmiperror(diag.problem));
end

for k = 1:numel(fixed_points)
    step.dual_ineq{k} = clean_numeric(value(step.dual_ineq{k}));
    step.dual_eq{k} = clean_numeric(value(step.dual_eq{k}));
    step.p_ineq{k} = clean_numeric(value(step.p_ineq{k}));
    step.q_eq{k} = clean_numeric(value(step.q_eq{k}));
end
step.solution = diag;
step.core_objective = value(core_expr);
step.penalized_objective = value(penalized_expr);
step.residual = value(residual_expr);
step.eta = value(eta);
step.rho = rho;
end

function step = solve_fixed_dual_step(model, ops, fixed_points, dual_step, rho)
constraints = build_upper_constraints(model);
eta = sdpvar(1, 1, 'full');
alpha_ineq = linear_upper_expr([model.A_l, model.B_l], ...
    [model.A_l_vars; model.B_l_vars], model.length_b_l);
beta_eq = linear_upper_expr([model.E_l, model.F_l], ...
    [model.E_l_vars; model.F_l_vars], model.length_f_l);

residual_expr = 0;
step.p_ineq = cell(numel(fixed_points), 1);
step.q_eq = cell(numel(fixed_points), 1);

for k = 1:numel(fixed_points)
    dual_ineq = dual_step.dual_ineq{k};
    dual_eq = dual_step.dual_eq{k};
    p_ineq = sdpvar(model.length_b_l, 1, 'full');
    q_eq = sdpvar(model.length_f_l, 1, 'full');
    residual_p = sdpvar(model.length_b_l, 1, 'full');
    residual_q = sdpvar(model.length_f_l, 1, 'full');

    if model.length_b_l > 0
        constraints = constraints + (residual_p >= 0) + ...
            (residual_p >= p_ineq - dual_ineq .* alpha_ineq) + ...
            (residual_p >= -p_ineq + dual_ineq .* alpha_ineq);
    end
    if model.length_f_l > 0
        constraints = constraints + (residual_q >= 0) + ...
            (residual_q >= q_eq - dual_eq .* beta_eq) + ...
            (residual_q >= -q_eq + dual_eq .* beta_eq);
    end

    constraints = constraints + interdiction_cut(model, fixed_points(k), ...
        dual_ineq, dual_eq, p_ineq, q_eq, eta);
    residual_expr = residual_expr + sum(residual_p) + sum(residual_q);

    step.p_ineq{k} = p_ineq;
    step.q_eq{k} = q_eq;
end

core_expr = upper_objective_expr(model) + eta;
penalized_expr = core_expr + rho * residual_expr;
diag = optimize(constraints, penalized_expr, ops.ops_MP);
if diag.problem ~= 0
    error('PowerBiMIP:InterdictionQuick', ...
        'Fixed-dual upper penalty step failed: %s', yalmiperror(diag.problem));
end

for k = 1:numel(fixed_points)
    step.p_ineq{k} = clean_numeric(value(step.p_ineq{k}));
    step.q_eq{k} = clean_numeric(value(step.q_eq{k}));
end
step.solution = diag;
step.core_objective = value(core_expr);
step.penalized_objective = value(penalized_expr);
step.residual = value(residual_expr);
step.eta = value(eta);
step.rho = rho;
end

function tf = should_run_neighbor_search(ops, step_a, step_b, upper_diff, tol)
mode = get_option(ops, 'interdiction_quick_neighbor_search', 'stagnation');
if isempty(mode)
    mode = 'off';
end
mode = lower(char(mode));
if any(strcmp(mode, {'off', 'none', 'false', '0'}))
    tf = false;
    return;
end
if any(strcmp(mode, {'always', 'on', 'true', '1'}))
    tf = true;
    return;
end

step_improvement = step_a.core_objective - step_b.core_objective;
improvement_tol = tol * max(1, abs(step_a.core_objective));
tf = upper_diff <= tol && step_improvement <= improvement_tol;
end

function escape = solve_neighbor_escape_step(model, ops, incumbent_upper, incumbent_step, rho, tol)
escape = empty_neighbor_escape();
escape.upper = incumbent_upper;
escape.step = incumbent_step;
escape.from_objective = incumbent_step.core_objective;
escape.to_objective = incumbent_step.core_objective;

upper_vars = upper_start_vars(model);
current_values = upper_start_values_from_point(model, incumbent_upper);
if isempty(upper_vars) || isempty(current_values) || numel(current_values) ~= numel(upper_vars)
    return;
end
if any(abs(current_values - round(current_values)) > 1e-6)
    return;
end

current_values = double(round(current_values(:)));
one_idx = find(current_values > 0.5);
zero_idx = find(current_values <= 0.5);
if isempty(one_idx) || isempty(zero_idx)
    return;
end

incumbent_eval = evaluate_fixed_upper_response(model, ops, current_values);
if ~incumbent_eval.success
    assign_upper_values(model, incumbent_upper);
    return;
end

best_eval = incumbent_eval;
max_candidates = get_option(ops, 'interdiction_quick_neighbor_search_max_candidates', inf);
candidate_count = 0;

for i = 1:numel(one_idx)
    for j = 1:numel(zero_idx)
        if candidate_count >= max_candidates
            break;
        end
        candidate_values = current_values;
        candidate_values(one_idx(i)) = 0;
        candidate_values(zero_idx(j)) = 1;
        candidate_count = candidate_count + 1;
        escape.candidate_count = candidate_count;

        candidate_eval = evaluate_fixed_upper_response(model, ops, candidate_values);
        if candidate_eval.success && candidate_eval.objective < best_eval.objective - tol
            best_eval = candidate_eval;
        end
    end
    if candidate_count >= max_candidates
        break;
    end
end

if best_eval.objective < incumbent_eval.objective - tol
    best_eval = evaluate_fixed_upper_response(model, ops, best_eval.upper_start_values);
    escape.improved = true;
    escape.upper = best_eval.upper;
    escape.step = evaluated_response_to_step(best_eval, rho);
    escape.to_objective = escape.step.core_objective;
else
    assign_upper_values(model, incumbent_upper);
end
end

function escape = empty_neighbor_escape()
escape = struct('improved', false, 'from_objective', nan, ...
    'to_objective', nan, 'candidate_count', 0, 'upper', [], 'step', []);
end

function eval_result = evaluate_fixed_upper_response(model, ops, upper_values)
eval_result.success = false;
eval_result.objective = inf;
eval_result.upper = [];
eval_result.upper_start_values = upper_values(:);
eval_result.solution = [];
eval_result.eta = nan;

upper_vars = upper_start_vars(model);
constraints = build_upper_constraints(model) + (upper_vars(:) == upper_values(:));
constraints = constraints + build_lower_constraints(model);
lower_objective = [model.c5', model.c6'] * [model.c5_vars; model.c6_vars];

solver_options = ops.ops_MP;
if isfield(ops, 'ops_SP1') && ~isempty(ops.ops_SP1)
    solver_options = ops.ops_SP1;
end
diag = optimize(constraints, lower_objective, solver_options);
eval_result.solution = diag;
if diag.problem ~= 0
    return;
end

eval_result.upper = upper_values_from_model(model);
eval_result.objective = value(upper_objective_expr(model) + lower_upper_objective_expr(model));
eval_result.eta = eval_result.objective - upper_objective_numeric(model, eval_result.upper);
eval_result.success = true;
end

function step = evaluated_response_to_step(eval_result, rho)
step.solution = eval_result.solution;
step.core_objective = eval_result.objective;
step.penalized_objective = eval_result.objective;
step.residual = 0;
step.eta = eval_result.eta;
step.rho = rho;
step.p_ineq = {};
step.q_eq = {};
end

function values = upper_start_values_from_point(model, point)
upper_vars = upper_start_vars(model);
values = [];
if isempty(upper_vars) || ~isfield(point, 'vector') || numel(point.vector) < numel(upper_vars)
    return;
end
values = clean_numeric(point.vector(1:numel(upper_vars)));
end

function assign_upper_values(model, point)
local_assign(model.A_u_vars, point.A_u_vars);
local_assign(model.B_u_vars, point.B_u_vars);
local_assign(model.E_u_vars, point.E_u_vars);
local_assign(model.F_u_vars, point.F_u_vars);
local_assign(model.A_l_vars, point.A_l_vars);
local_assign(model.B_l_vars, point.B_l_vars);
local_assign(model.E_l_vars, point.E_l_vars);
local_assign(model.F_l_vars, point.F_l_vars);
local_assign(model.c1_vars, point.c1_vars);
local_assign(model.c2_vars, point.c2_vars);
end

function local_assign(vars, values)
if ~isempty(vars) && ~isempty(values)
    assign(vars, values);
end
end

function constraints = dual_feasibility_constraints(model, dual_ineq, dual_eq)
constraints = [];
constraint_ineq = 0;
constraint_eq = 0;
if ~isempty(model.C_l)
    constraint_ineq = dual_ineq' * model.C_l;
end
if ~isempty(model.G_l)
    constraint_eq = dual_eq' * model.G_l;
end
if ~isempty(model.c5)
    constraints = constraints + (constraint_ineq + constraint_eq == model.c5');
end
end

function constraints = dual_bound_constraints(dual_ineq, dual_eq, bigM)
constraints = [];
if ~isempty(dual_ineq)
    constraints = constraints + (dual_ineq <= 0) + (dual_ineq >= -bigM.ineq);
end
if ~isempty(dual_eq)
    constraints = constraints + (dual_eq <= bigM.eq) + (dual_eq >= -bigM.eq);
end
end

function constraints = interdiction_cut(model, fixed_z, dual_ineq, dual_eq, p_ineq, q_eq, eta)
const_ineq = model.b_l - model.D_l * fixed_z.D_l_vars;
const_eq = model.f_l - model.H_l * fixed_z.H_l_vars;
dual_cut_value = dot_or_zero(dual_ineq, const_ineq) + ...
    dot_or_zero(dual_eq, const_eq) + dot_or_zero(model.c6, fixed_z.c6_vars) - ...
    sum(p_ineq) - sum(q_eq);
constraints = (eta >= -dual_cut_value);
end

function [current, init_solution] = initial_upper_point(model, ops, iteration_record)
profile = get_option(ops, 'interdiction_quick_initial_upper', 'previous_mp');
if iteration_record.iteration_num > 1 && ...
        any(strcmpi(profile, {'previous_mp', 'random', 'random_upper'}))
    [current, init_solution] = previous_upper_point(iteration_record);
    if ~isempty(current)
        return;
    end
end

if any(strcmpi(profile, {'random', 'random_upper'}))
    seed = round(get_option(ops, 'interdiction_quick_random_seed', 1));
    current = random_upper_point(model, ops, seed);
    if isempty(current)
        error('PowerBiMIP:InterdictionQuickInitialUpper', ...
            'Could not generate a random feasible upper point for interdiction quick mode.');
    end
    init_solution = [];
    return;
end

if any(strcmpi(profile, {'fixed_index', 'line', 'fixed_line', 'specified'}))
    line_index = round(get_option(ops, 'interdiction_quick_initial_upper_index', []));
    current = indexed_upper_point(model, ops, line_index);
    init_solution = [];
    return;
end

init_solution = solve_relaxed_master(model, ops);
current = upper_values_from_model(model);
end

function [point, prev] = previous_upper_point(iteration_record)
point = [];
prev = [];
if iteration_record.iteration_num <= 1 || ...
        numel(iteration_record.master_problem_solution) < iteration_record.iteration_num - 1
    return;
end
prev = iteration_record.master_problem_solution{iteration_record.iteration_num - 1};
if ~isempty(prev) && has_upper_solution_fields(prev)
    point = upper_values_from_solution(prev);
end
end

function points = initial_upper_points(model, ops, iteration_record)
[base_point, ~] = initial_upper_point(model, ops, iteration_record);
points = {base_point};

num_starts = max(1, round(get_option(ops, 'interdiction_quick_num_starts', 1)));
seed = round(get_option(ops, 'interdiction_quick_random_seed', 1));
for start_idx = 2:num_starts
    candidate = random_upper_point(model, ops, seed + start_idx - 1);
    if isempty(candidate)
        continue;
    end
    if ~contains_upper_point(points, candidate, 1e-8)
        points{end+1} = candidate; %#ok<AGROW>
    end
end
end

function point = random_upper_point(model, ops, seed)
upper_vars = upper_start_vars(model);
if isempty(upper_vars)
    point = [];
    return;
end

previous_rng = rng;
cleanup = onCleanup(@() rng(previous_rng));
rng(seed, 'twister');

constraints = build_upper_constraints(model);
weights = randn(numel(upper_vars), 1);
diag = optimize(constraints, weights' * upper_vars(:), ops.ops_MP);
if diag.problem ~= 0
    point = [];
    return;
end

point = upper_values_from_model(model);
end

function point = indexed_upper_point(model, ops, index)
upper_vars = upper_start_vars(model);
if isempty(upper_vars)
    point = [];
    return;
end
if isempty(index) || ~isscalar(index) || index < 1 || index > numel(upper_vars)
    error('PowerBiMIP:InterdictionQuickInitialUpper', ...
        'interdiction_quick_initial_upper_index must be an integer in [1, %d].', ...
        numel(upper_vars));
end

constraints = build_upper_constraints(model) + (upper_vars(index) == 1);
diag = optimize(constraints, 0, ops.ops_MP);
if diag.problem ~= 0
    error('PowerBiMIP:InterdictionQuickInitialUpper', ...
        'Could not generate fixed-index upper point %d: %s', ...
        index, yalmiperror(diag.problem));
end

point = upper_values_from_model(model);
end

function vars = upper_start_vars(model)
vars = [];
if isfield(model, 'var_x_u') && ~isempty(model.var_x_u)
    vars = [vars; model.var_x_u(:)];
end
if isfield(model, 'var_z_u') && ~isempty(model.var_z_u)
    vars = [vars; model.var_z_u(:)];
end
if isempty(vars)
    return;
end
[~, first_idx] = unique(getvariables(vars), 'stable');
vars = vars(first_idx);
end

function tf = contains_upper_point(points, candidate, tol)
tf = false;
candidate_vec = candidate.vector(:);
for idx = 1:numel(points)
    current_vec = points{idx}.vector(:);
    if numel(current_vec) ~= numel(candidate_vec)
        continue;
    end
    if norm(current_vec - candidate_vec, inf) <= tol
        tf = true;
        return;
    end
end
end

function Solution = solve_relaxed_master(model, ops)
constraints = build_upper_constraints(model);
constraints = constraints + build_lower_constraints(model);
objective = upper_objective_expr(model) + lower_upper_objective_expr(model);
diag = optimize(constraints, objective, ops.ops_MP);
Solution = collect_master_solution(model, diag, value(objective));
Solution.master_type = 'interdiction_ccg_quick_relaxed';
end

function constraints = build_upper_constraints(model)
constraints = [];
if ~isempty(model.b_u)
    constraints = constraints + ...
        ([model.A_u, model.B_u, model.C_u, model.D_u] * ...
        [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
        model.b_u);
end
if ~isempty(model.f_u)
    constraints = constraints + ...
        ([model.E_u, model.F_u, model.G_u, model.H_u] * ...
        [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
        model.f_u);
end
end

function constraints = build_lower_constraints(model)
constraints = [];
if ~isempty(model.b_l)
    constraints = constraints + ...
        ([model.A_l, model.B_l, model.C_l, model.D_l] * ...
        [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
        model.b_l);
end
if ~isempty(model.f_l)
    constraints = constraints + ...
        ([model.E_l, model.F_l, model.G_l, model.H_l] * ...
        [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
        model.f_l);
end
end

function expr = upper_objective_expr(model)
expr = 0;
if ~isempty(model.c1_vars)
    expr = expr + model.c1' * model.c1_vars;
end
if ~isempty(model.c2_vars)
    expr = expr + model.c2' * model.c2_vars;
end
end

function expr = lower_upper_objective_expr(model)
expr = 0;
if ~isempty(model.c3_vars)
    expr = expr + model.c3' * model.c3_vars;
end
if ~isempty(model.c4_vars)
    expr = expr + model.c4' * model.c4_vars;
end
end

function value_out = upper_objective_numeric(model, current_upper)
value_out = 0;
if ~isempty(current_upper.c1_vars)
    value_out = value_out + model.c1' * current_upper.c1_vars;
end
if ~isempty(current_upper.c2_vars)
    value_out = value_out + model.c2' * current_upper.c2_vars;
end
end

function Solution = collect_master_solution(model, diag, objective)
Solution.var = myFun_GetValue(model.var);
Solution.solution = diag;

Solution.A_u_vars = clean_numeric(value(model.A_u_vars));
Solution.B_u_vars = clean_numeric(value(model.B_u_vars));
Solution.E_u_vars = clean_numeric(value(model.E_u_vars));
Solution.F_u_vars = clean_numeric(value(model.F_u_vars));

Solution.A_l_vars = clean_numeric(value(model.A_l_vars));
Solution.B_l_vars = clean_numeric(value(model.B_l_vars));
Solution.E_l_vars = clean_numeric(value(model.E_l_vars));
Solution.F_l_vars = clean_numeric(value(model.F_l_vars));

Solution.c1_vars = clean_numeric(value(model.c1_vars));
Solution.c2_vars = clean_numeric(value(model.c2_vars));
Solution.c3_vars = clean_numeric(value(model.c3_vars));
Solution.c4_vars = clean_numeric(value(model.c4_vars));
Solution.objective = objective;
end

function values = upper_values_from_model(model)
values.A_u_vars = clean_numeric(value(model.A_u_vars));
values.B_u_vars = clean_numeric(value(model.B_u_vars));
values.E_u_vars = clean_numeric(value(model.E_u_vars));
values.F_u_vars = clean_numeric(value(model.F_u_vars));
values.A_l_vars = clean_numeric(value(model.A_l_vars));
values.B_l_vars = clean_numeric(value(model.B_l_vars));
values.E_l_vars = clean_numeric(value(model.E_l_vars));
values.F_l_vars = clean_numeric(value(model.F_l_vars));
values.c1_vars = clean_numeric(value(model.c1_vars));
values.c2_vars = clean_numeric(value(model.c2_vars));
values.vector = clean_numeric([value_or_empty(model.var_x_u); value_or_empty(model.var_z_u); ...
    values.A_u_vars(:); values.B_u_vars(:); values.E_u_vars(:); values.F_u_vars(:); ...
    values.A_l_vars(:); values.B_l_vars(:); values.E_l_vars(:); values.F_l_vars(:); ...
    values.c1_vars(:); values.c2_vars(:)]);
end

function values = upper_values_from_solution(sol)
fields = {'A_u_vars','B_u_vars','E_u_vars','F_u_vars', ...
    'A_l_vars','B_l_vars','E_l_vars','F_l_vars','c1_vars','c2_vars'};
for i = 1:numel(fields)
    if isfield(sol, fields{i})
        values.(fields{i}) = clean_numeric(sol.(fields{i}));
    else
        values.(fields{i}) = [];
    end
end
values.vector = [];
for i = 1:numel(fields)
    values.vector = [values.vector; values.(fields{i})(:)];
end
end

function tf = has_upper_solution_fields(sol)
tf = isfield(sol, 'A_l_vars') && isfield(sol, 'B_l_vars') && ...
     isfield(sol, 'E_l_vars') && isfield(sol, 'F_l_vars') && ...
     isfield(sol, 'c1_vars') && isfield(sol, 'c2_vars');
end

function out = numeric_upper_term(coeff, values, row_count)
if isempty(coeff) || isempty(values)
    out = zeros(row_count, 1);
else
    out = coeff * clean_numeric(values(:));
end
end

function out = linear_upper_expr(coeff, vars, row_count)
if isempty(coeff) || isempty(vars)
    out = zeros(row_count, 1);
else
    out = coeff * vars(:);
end
end

function expr = random_linear_expr(vars)
if isempty(vars)
    expr = 0;
else
    expr = randn(numel(vars), 1)' * vars(:);
end
end

function diff = relative_upper_diff(old_values, new_values)
old_vec = clean_numeric(old_values.vector(:));
new_vec = clean_numeric(new_values.vector(:));
n = min(numel(old_vec), numel(new_vec));
if n == 0
    diff = 0;
    return;
end
diff = norm(new_vec(1:n) - old_vec(1:n), inf) / max(1, norm(old_vec(1:n), inf));
end

function diff = relative_value_diff(old_value, new_value)
if ~isfinite(old_value)
    diff = inf;
else
    diff = abs(new_value - old_value) / max(1, abs(old_value));
end
end

function chars = print_padm_progress(ops, iteration, step_a, step_b, upper_diff)
chars = 0;
if ~isfield(ops, 'verbose') || ops.verbose ~= 2
    return;
end
gap_pct = objective_gap_pct(step_a.core_objective, step_b.core_objective);
msgFmt = ['Interdiction PADM Iter %d: SP1=%.4f | SP2=%.4f | ', ...
    'Gap=%.2f%% | UpperDiff=%.1e | Residual=%.1e\n'];
chars = log_utils('printf_count', msgFmt, iteration, ...
    step_a.core_objective, step_b.core_objective, gap_pct, ...
    upper_diff, step_b.residual);
end

function chars = print_padm_converged(ops)
chars = 0;
if ~isfield(ops, 'verbose') || ops.verbose ~= 2
    return;
end
msgFmt = 'Interdiction PADM converged.\n';
chars = log_utils('printf_count', msgFmt);
end

function gap_pct = objective_gap_pct(value_a, value_b)
denominator = max(abs(value_a), abs(value_b));
gap_pct = 100 * abs(value_b - value_a) / max(denominator, 1e-9);
if ~isfinite(gap_pct)
    gap_pct = NaN;
end
end

function entry = make_history_entry(iteration, rho, step_a, padm_step_b, step_b, ...
    escape, upper_diff, core_diff)
entry.iteration = iteration;
entry.rho = rho;
entry.step_a_core_objective = step_a.core_objective;
entry.step_a_penalized_objective = step_a.penalized_objective;
entry.step_a_residual = step_a.residual;
entry.step_a_eta = step_a.eta;
entry.step_b_padm_core_objective = padm_step_b.core_objective;
entry.step_b_padm_penalized_objective = padm_step_b.penalized_objective;
entry.step_b_padm_residual = padm_step_b.residual;
entry.step_b_padm_eta = padm_step_b.eta;
entry.step_b_core_objective = step_b.core_objective;
entry.step_b_penalized_objective = step_b.penalized_objective;
entry.step_b_residual = step_b.residual;
entry.step_b_eta = step_b.eta;
entry.neighbor_escape = escape.improved;
entry.neighbor_escape_from_objective = escape.from_objective;
entry.neighbor_escape_to_objective = escape.to_objective;
entry.neighbor_escape_candidate_count = escape.candidate_count;
entry.core_objective = step_b.core_objective;
entry.penalized_objective = step_b.penalized_objective;
entry.residual = step_b.residual;
entry.eta = step_b.eta;
entry.upper_diff = upper_diff;
entry.core_diff = core_diff;
end

function history = empty_quick_history()
history = struct('iteration', {}, 'rho', {}, ...
    'step_a_core_objective', {}, 'step_a_penalized_objective', {}, ...
    'step_a_residual', {}, 'step_a_eta', {}, ...
    'step_b_padm_core_objective', {}, 'step_b_padm_penalized_objective', {}, ...
    'step_b_padm_residual', {}, 'step_b_padm_eta', {}, ...
    'step_b_core_objective', {}, 'step_b_penalized_objective', {}, ...
    'step_b_residual', {}, 'step_b_eta', {}, ...
    'neighbor_escape', {}, 'neighbor_escape_from_objective', {}, ...
    'neighbor_escape_to_objective', {}, 'neighbor_escape_candidate_count', {}, ...
    'core_objective', {}, 'penalized_objective', {}, ...
    'residual', {}, 'eta', {}, 'upper_diff', {}, 'core_diff', {});
end

function summary = empty_start_summary()
summary = struct('start_index', {}, 'core_objective', {}, ...
    'penalized_objective', {}, 'residual', {}, 'alternations', {});
end

function entry = make_start_summary_entry(start_idx, solution)
entry.start_index = start_idx;
entry.core_objective = solution.objective;
entry.penalized_objective = solution.penalized_objective;
entry.residual = solution.quick_residual;
entry.alternations = solution.quick_alternations;
end

function tf = is_better_quick_solution(candidate, incumbent, residual_tol)
if isempty(incumbent)
    tf = true;
    return;
end

candidate_good = candidate.quick_residual <= max(residual_tol, 1e-8);
incumbent_good = incumbent.quick_residual <= max(residual_tol, 1e-8);

if candidate_good && ~incumbent_good
    tf = true;
elseif ~candidate_good && incumbent_good
    tf = false;
elseif candidate_good && incumbent_good
    tf = candidate.objective < incumbent.objective - 1e-8;
else
    tf = candidate.penalized_objective < incumbent.penalized_objective - 1e-8;
end
end

function value = get_option(ops, field_name, default_value)
if isfield(ops, field_name) && ~isempty(ops.(field_name))
    value = ops.(field_name);
else
    value = default_value;
end
end

function x = clean_numeric(x)
x = double(x);
x = x(:);
x(isnan(x)) = 0;
end

function x = value_or_empty(vars)
if isempty(vars)
    x = [];
else
    x = clean_numeric(value(vars));
end
end

function y = dot_or_zero(a, b)
if isempty(a) || isempty(b)
    y = 0;
else
    y = a(:)' * b(:);
end
end

function points = collect_fixed_lower_integer_points(iteration_record)
points = struct('D_l_vars', {}, 'H_l_vars', {}, 'c6_vars', {});

for i = 1 : iteration_record.iteration_num - 1
    if numel(iteration_record.optimal_solution_hat) < i || isempty(iteration_record.optimal_solution_hat{i})
        continue;
    end
    points(end+1).D_l_vars = iteration_record.optimal_solution_hat{i}.D_l_vars;
    points(end).H_l_vars = iteration_record.optimal_solution_hat{i}.H_l_vars;
    points(end).c6_vars = iteration_record.optimal_solution_hat{i}.c6_vars;
end

points = unique_lower_integer_points(points);
end

function bigM = get_interdiction_bigM(model, ops)
if isfield(ops, 'interdiction_bigM_method') && ~isempty(ops.interdiction_bigM_method)
    if ~isa(ops.interdiction_bigM_method, 'function_handle')
        error('PowerBiMIP:InterdictionBigM', ...
            'interdiction_bigM_method must be a function handle.');
    end
    value = ops.interdiction_bigM_method(model, ops);
elseif isfield(ops, 'interdiction_bigM') && ~isempty(ops.interdiction_bigM)
    value = ops.interdiction_bigM;
elseif isfield(ops, 'interdiction_default_bigM') && ~isempty(ops.interdiction_default_bigM)
    value = ops.interdiction_default_bigM;
else
    value = 1e5;
end

bigM.ineq = expand_bigM_value(value, 'ineq', model.length_b_l);
bigM.eq = expand_bigM_value(value, 'eq', model.length_f_l);
end

function out = expand_bigM_value(value, field_name, target_len)
if isstruct(value)
    if isfield(value, field_name)
        value = value.(field_name);
    elseif isfield(value, 'all')
        value = value.all;
    else
        error('PowerBiMIP:InterdictionBigM', ...
            'interdiction_bigM struct must contain "%s" or "all".', field_name);
    end
end

if isempty(value) && target_len == 0
    out = zeros(0, 1);
    return;
end
if any(~isfinite(value(:))) || any(value(:) <= 0)
    error('PowerBiMIP:InterdictionBigM', ...
        'interdiction_bigM values must be finite and positive.');
end
if isscalar(value)
    out = repmat(value, target_len, 1);
elseif numel(value) == target_len
    out = value(:);
else
    error('PowerBiMIP:InterdictionBigM', ...
        'interdiction_bigM.%s must be scalar or length %d, but got length %d.', ...
        field_name, target_len, numel(value));
end
end

function points_out = unique_lower_integer_points(points_in)
points_out = struct('D_l_vars', {}, 'H_l_vars', {}, 'c6_vars', {});
seen = {};

for i = 1:numel(points_in)
    key = sprintf('%g,', round([points_in(i).D_l_vars(:); points_in(i).H_l_vars(:); points_in(i).c6_vars(:)] * 1e8) / 1e8);
    if any(strcmp(seen, key))
        continue;
    end
    seen{end+1} = key; %#ok<AGROW>
    points_out(end+1) = points_in(i); %#ok<AGROW>
end
end
