function [Solution] = master_problem_interdiction_ccg(model, ops, iteration_record)
%MASTER_PROBLEM_INTERDICTION_CCG Paper-style C&CG master for interdiction models.
%
% This master is used only for interdiction/max-min cases where the upper
% and lower objectives are opposite and the upper constraints are uncoupled.
% It follows the partial single-level idea in Zhao and Zeng (2013): each
% known lower-level integer response defines one recourse LP dual block, and
% binary-upper-by-dual products are linearized with user-provided big-M bounds.

fixed_points = collect_fixed_lower_integer_points(iteration_record);
if isempty(fixed_points)
    % With no known lower-level integer point, fall back to the original first
    % relaxed MP. The next SP1 call will generate the first column.
    Solution = master_problem_strong_duality(model, ops, iteration_record);
    return;
end

if ~isempty(model.var_x_u)
    coupled_to_lower = has_nonzero(model.A_l) || has_nonzero(model.E_l);
    if coupled_to_lower
        error('PowerBiMIP:InterdictionCCG', ...
            ['The paper-style interdiction C&CG master currently supports ' ...
             'binary upper variables in lower-level constraints. Continuous ' ...
             'upper variables are present and coupled to the lower level.']);
    end
end

model.constraints = [];
model.eta = sdpvar(1, 1, 'full');

% Upper-level feasible region.
if ~isempty(model.b_u)
    model.constraints = model.constraints + ...
        ([model.A_u, model.B_u, model.C_u, model.D_u] * ...
        [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
        model.b_u);
end
if ~isempty(model.f_u)
    model.constraints = model.constraints + ...
        ([model.E_u, model.F_u, model.G_u, model.H_u] * ...
        [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
        model.f_u);
end

bigM = get_interdiction_bigM(model, ops);

for k = 1:numel(fixed_points)
    dual_ineq = sdpvar(model.length_b_l, 1, 'full');
    dual_eq = sdpvar(model.length_f_l, 1, 'full');

    fixed_z = fixed_points(k);
    const_ineq = model.b_l - model.D_l * fixed_z.D_l_vars;
    const_eq = model.f_l - model.H_l * fixed_z.H_l_vars;

    % Dual feasibility of the continuous lower-level recourse LP.
    constraint_ineq = 0;
    if ~isempty(model.C_l)
        constraint_ineq = dual_ineq' * model.C_l;
    end
    constraint_eq = 0;
    if ~isempty(model.G_l)
        constraint_eq = dual_eq' * model.G_l;
    end
    model.constraints = model.constraints + (constraint_ineq + constraint_eq == model.c5');

    model.constraints = model.constraints + ...
        (dual_ineq <= 0) + (dual_ineq >= -bigM.ineq);
    model.constraints = model.constraints + ...
        (dual_eq <= bigM.eq) + (dual_eq >= -bigM.eq);

    [prod_ineq, cons_ineq_prod] = linearized_dual_upper_product( ...
        dual_ineq, [model.A_l, model.B_l], [model.A_l_vars; model.B_l_vars], ...
        -bigM.ineq, zeros(model.length_b_l, 1));
    [prod_eq, cons_eq_prod] = linearized_dual_upper_product( ...
        dual_eq, [model.E_l, model.F_l], [model.E_l_vars; model.F_l_vars], ...
        -bigM.eq, bigM.eq);

    model.constraints = model.constraints + cons_ineq_prod + cons_eq_prod;

    dual_obj = dual_ineq' * const_ineq + dual_eq' * const_eq + ...
        model.c6' * fixed_z.c6_vars - prod_ineq - prod_eq;

    % For interdiction c3/c4 = -c5/c6, so the upper lower-level contribution
    % is the negative of the follower's optimal objective for this fixed z.
    model.constraints = model.constraints + (model.eta >= -dual_obj);
end

model.objective = [model.c1', model.c2'] * [model.c1_vars; model.c2_vars] + model.eta;
model.solution = optimize(model.constraints, model.objective, ops.ops_MP);

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
Solution.eta = value(model.eta);
Solution.master_type = 'interdiction_ccg_exact';
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
%GET_INTERDICTION_BIGM Resolve dual bounds for big-M linearization.
% Priority:
%   1) ops.interdiction_bigM_method(model, ops)
%   2) ops.interdiction_bigM
%   3) ops.interdiction_default_bigM

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

function [expr, constraints] = linearized_dual_upper_product(dual_vars, coeff, upper_vars, lb, ub)
expr = 0;
constraints = [];

if isempty(coeff) || isempty(upper_vars) || isempty(dual_vars)
    return;
end

upper_vars = upper_vars(:);
for col = 1:numel(upper_vars)
    if ~is(upper_vars(col), 'binary')
        if any(coeff(:, col))
            if is(upper_vars(col), 'integer')
                error('PowerBiMIP:InterdictionCCG', ...
                    ['Paper-style interdiction C&CG currently supports binary upper ' ...
                     'variables for big-M linearization. General integer upper variables ' ...
                     'need their own finite bounds and are not enabled here.']);
            end
            error('PowerBiMIP:InterdictionCCG', ...
                ['Cannot big-M linearize continuous-by-continuous products. ' ...
                 'The interdiction C&CG master only linearizes binary-by-continuous terms.']);
        end
        continue;
    end

    rows = find(coeff(:, col));
    for rr = rows(:).'
        w = sdpvar(1, 1, 'full');
        lower = lb(rr);
        upper = ub(rr);
        z = upper_vars(col);
        lambda = dual_vars(rr);
        constraints = constraints + ...
            (w <= upper * z) + ...
            (w >= lower * z) + ...
            (w <= lambda - lower * (1 - z)) + ...
            (w >= lambda - upper * (1 - z));
        expr = expr + coeff(rr, col) * w;
    end
end
end

function tf = has_nonzero(matrix)
tf = ~isempty(matrix) && any(abs(matrix(:)) > 1e-12);
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
