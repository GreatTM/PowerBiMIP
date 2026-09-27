function model = extract_robust_coeffs(var_y_cont, var_y_int, var_x_cont, var_x_int, var_u, ...
    cons_1st, cons_2nd, cons_uncertainty, obj_1st, obj_2nd, u_init, ops)
%EXTRACT_ROBUST_COEFFS Extracts coefficient matrices for TRO-LP (RCR assumed).
%
%   Description:
%       Parses YALMIP constraints/objectives of a two-stage robust model
%       (first-stage y, uncertainty u, second-stage x/z) into structured
%       matrices. Follows the style of EXTRACT_COEFFICIENTS_AND_VARIABLES to
%       maintain consistent filtering and statistics.
%
%   Inputs:
%       var_y_cont       - First-stage continuous vars (sdpvar)
%       var_y_int        - First-stage integer vars   (intvar/binvar)
%       var_x_cont       - Second-stage continuous vars (sdpvar)
%       var_x_int        - Second-stage integer vars    (intvar/binvar, usually empty for TRO-LP)
%       var_u            - Uncertain parameters (sdpvar)
%       cons_1st         - First-stage constraints (YALMIP constraint object)
%       cons_2nd         - Second-stage constraints (involving y, u, x/z)
%       cons_uncertainty - Uncertainty set constraints on u
%       obj_1st          - First-stage objective (YALMIP expression)
%       obj_2nd          - Second-stage objective (YALMIP expression)
%       u_init           - (Optional) Initial values for uncertainty variables (numeric vector)
%       ops              - Options structure (for verbose control)
%                          If provided, extracts initial values for A2_u_vars, E2_u_vars,
%                          H_u_vars, F_u_vars based on their positions in var_u.
%
%   Output:
%       model - Struct with coefficient matrices, RHS, objectives, uncertainty
%               description, and statistics for downstream CCG modules.
%               If u_init is provided, also contains:
%               - model.A2_u_vars_init: Initial values for A2_u_vars
%               - model.E2_u_vars_init: Initial values for E2_u_vars
%               - model.H_u_vars_init: Initial values for H_u_vars
%               - model.F_u_vars_init: Initial values for F_u_vars

    % --- Extract LP/QP models ---
    details_1st = extract_lp_qp_model(cons_1st, obj_1st);
    details_2nd = extract_lp_qp_model(cons_2nd, obj_2nd);
    details_unc = extract_lp_qp_model(cons_uncertainty, 0);

    % --- Store original variable groups ---
    model.var_y_cont = var_y_cont;
    model.var_y_int  = var_y_int;
    model.var_x_cont = var_x_cont;
    model.var_x_int  = var_x_int;
    model.var_u      = var_u;

    %% First-stage constraints (inequality: A*y <= b; equality: E*y == f)
    [model.A1_yc, model.A1_yc_vars] = extract_coeff_block(var_y_cont, details_1st.primal, details_1st.A);
    [model.A1_yi, model.A1_yi_vars] = extract_coeff_block(var_y_int,  details_1st.primal, details_1st.A);
    model.b1 = details_1st.b;

    [model.E1_yc, model.E1_yc_vars] = extract_coeff_block(var_y_cont, details_1st.primal, details_1st.E);
    [model.E1_yi, model.E1_yi_vars] = extract_coeff_block(var_y_int,  details_1st.primal, details_1st.E);
    model.f1 = details_1st.f;

    %% Second-stage constraints (may couple y, u, x/z)
    [model.A2_yc, model.A2_yc_vars] = extract_coeff_block(var_y_cont, details_2nd.primal, details_2nd.A);
    [model.A2_yi, model.A2_yi_vars] = extract_coeff_block(var_y_int,  details_2nd.primal, details_2nd.A);
    [model.A2_u,  model.A2_u_vars ] = extract_coeff_block(var_u,      details_2nd.primal, details_2nd.A);
    [model.A2_xc, model.A2_xc_vars] = extract_coeff_block(var_x_cont, details_2nd.primal, details_2nd.A);
    [model.A2_xi, model.A2_xi_vars] = extract_coeff_block(var_x_int,  details_2nd.primal, details_2nd.A);
    model.b2 = details_2nd.b;

    [model.E2_yc, model.E2_yc_vars] = extract_coeff_block(var_y_cont, details_2nd.primal, details_2nd.E);
    [model.E2_yi, model.E2_yi_vars] = extract_coeff_block(var_y_int,  details_2nd.primal, details_2nd.E);
    [model.E2_u,  model.E2_u_vars ] = extract_coeff_block(var_u,      details_2nd.primal, details_2nd.E);
    [model.E2_xc, model.E2_xc_vars] = extract_coeff_block(var_x_cont, details_2nd.primal, details_2nd.E);
    [model.E2_xi, model.E2_xi_vars] = extract_coeff_block(var_x_int,  details_2nd.primal, details_2nd.E);
    model.f2 = details_2nd.f;

    %% Objectives
    % First-stage objective coefficients (c_yc, c_yi)
    [c1_yc_tmp, model.c1_yc_vars] = extract_coeff_block(var_y_cont, details_1st.primal, details_1st.c');
    [c1_yi_tmp, model.c1_yi_vars] = extract_coeff_block(var_y_int,  details_1st.primal, details_1st.c');
    model.c1_yc = c1_yc_tmp(:);
    model.c1_yi = c1_yi_tmp(:);

    % Second-stage objective coefficients (c2 on x/z)
    [c2_xc_tmp, model.c2_xc_vars] = extract_coeff_block(var_x_cont, details_2nd.primal, details_2nd.c');
    [c2_xi_tmp, model.c2_xi_vars] = extract_coeff_block(var_x_int,  details_2nd.primal, details_2nd.c');
    model.c2_xc = c2_xc_tmp(:);
    model.c2_xi = c2_xi_tmp(:);

    %% Uncertainty set (polyhedral Hu <= a; box can be represented similarly)
    [model.H_u, model.H_u_vars] = extract_coeff_block(var_u, details_unc.primal, details_unc.A);
    model.a_u = details_unc.b;
    [model.F_u, model.F_u_vars] = extract_coeff_block(var_u, details_unc.primal, details_unc.E);
    model.g_u = details_unc.f;
    model.uncertainty_box = []; % placeholder if box bounds are provided separately

    %% Variable counts
    all_vars = [var_y_cont(:); var_y_int(:); var_u(:); var_x_cont(:); var_x_int(:)];
    int_vars = [var_y_int(:); var_x_int(:)];
    bin_count = 0;
    for i = 1:length(int_vars)
        if is(int_vars(i), 'binary')
            bin_count = bin_count + 1;
        end
    end
    model.int_vars = length(int_vars);
    model.bin_vars = bin_count;
    model.cont_vars = length(all_vars) - model.int_vars;

    %% Constraint statistics
    model.first_ineq_rows = length(model.b1);
    model.first_eq_rows   = length(model.f1);
    model.second_ineq_rows = length(model.b2);
    model.second_eq_rows   = length(model.f2);
    model.total_rows = model.first_ineq_rows + model.first_eq_rows + ...
                       model.second_ineq_rows + model.second_eq_rows;

    model.first_nonzeros = nnz(model.A1_yc) + nnz(model.A1_yi) + nnz(model.E1_yc) + nnz(model.E1_yi);
    model.second_nonzeros = nnz(model.A2_yc) + nnz(model.A2_yi) + nnz(model.A2_u) + ...
        nnz(model.A2_xc) + nnz(model.A2_xi) + nnz(model.E2_yc) + nnz(model.E2_yi) + ...
        nnz(model.E2_u) + nnz(model.E2_xc) + nnz(model.E2_xi);
    model.unc_nonzeros = nnz(model.H_u) + nnz(model.F_u);
    model.total_nonzeros = model.first_nonzeros + model.second_nonzeros + model.unc_nonzeros;

    %% Range statistics
    all_matrix_nz = sparse([ ...
        abs(nonzeros([model.A1_yc, model.A1_yi])); ...  % First-stage inequality constraints (same row count)
        abs(nonzeros([model.E1_yc, model.E1_yi])); ...  % First-stage equality constraints (same row count)
        abs(nonzeros([model.A2_yc, model.A2_yi, model.A2_u, model.A2_xc, model.A2_xi])); ...  % Second-stage inequality constraints (same row count)
        abs(nonzeros([model.E2_yc, model.E2_yi, model.E2_u, model.E2_xc, model.E2_xi])); ...  % Second-stage equality constraints (same row count)
        abs(nonzeros(model.H_u)); ...  % Uncertainty H_u constraints (independent row count)
        abs(nonzeros(model.F_u)) ...   % Uncertainty F_u constraints (independent row count)
    ]);
    if nnz(all_matrix_nz) > 0
        model.matrix_min = full(min(all_matrix_nz(all_matrix_nz > 0)));
        model.matrix_max = full(max(all_matrix_nz));
    else
        model.matrix_min = 0;
        model.matrix_max = 0;
    end

    all_obj = abs([model.c1_yc(:); model.c1_yi(:); model.c2_xc(:); model.c2_xi(:)]);
    all_obj = nonzeros(all_obj);
    if ~isempty(all_obj)
        model.obj_min = full(min(all_obj));
        model.obj_max = full(max(all_obj));
    else
        model.obj_min = 0;
        model.obj_max = 0;
    end

    all_rhs = abs([model.b1; model.f1; model.b2; model.f2; model.a_u; model.g_u]);
    all_rhs = nonzeros(all_rhs);
    if ~isempty(all_rhs)
        model.rhs_min = full(min(all_rhs));
        model.rhs_max = full(max(all_rhs));
    else
        model.rhs_min = 0;
        model.rhs_max = 0;
    end

    %% Extract initial values for uncertainty variables (if u_init is provided)
    % Ensure u_init is a column vector
    u_init = u_init(:);
    model.A2_u_vars_init = extract_u_init(model.A2_u_vars, var_u, u_init);
    model.E2_u_vars_init = extract_u_init(model.E2_u_vars, var_u, u_init);
    model.H_u_vars_init = extract_u_init(model.H_u_vars, var_u, u_init);
    model.F_u_vars_init = extract_u_init(model.F_u_vars, var_u, u_init);

    if ops.verbose >= 1
        fprintf('Robust model components extracted successfully.\n');
    end

    %% Extract the relative positions of each variable
    model.relative_pos.A1_yc_vars = extract_relative_pos(model.A1_yc_vars, model.var_y_cont);
    model.relative_pos.A1_yi_vars = extract_relative_pos(model.A1_yi_vars, model.var_y_int);

    model.relative_pos.E1_yc_vars = extract_relative_pos(model.E1_yc_vars, model.var_y_cont);
    model.relative_pos.E1_yi_vars = extract_relative_pos(model.E1_yi_vars, model.var_y_int);

    model.relative_pos.A2_yc_vars = extract_relative_pos(model.A2_yc_vars, model.var_y_cont);
    model.relative_pos.A2_yi_vars = extract_relative_pos(model.A2_yi_vars, model.var_y_int);
    model.relative_pos.A2_u_vars  = extract_relative_pos(model.A2_u_vars,  model.var_u);
    model.relative_pos.A2_xc_vars = extract_relative_pos(model.A2_xc_vars, model.var_x_cont);
    model.relative_pos.A2_xi_vars = extract_relative_pos(model.A2_xi_vars, model.var_x_int);

    model.relative_pos.E2_yc_vars = extract_relative_pos(model.E2_yc_vars, model.var_y_cont);
    model.relative_pos.E2_yi_vars = extract_relative_pos(model.E2_yi_vars, model.var_y_int);
    model.relative_pos.E2_u_vars  = extract_relative_pos(model.E2_u_vars,  model.var_u);
    model.relative_pos.E2_xc_vars = extract_relative_pos(model.E2_xc_vars, model.var_x_cont);
    model.relative_pos.E2_xi_vars = extract_relative_pos(model.E2_xi_vars, model.var_x_int);

    model.relative_pos.c1_yc_vars = extract_relative_pos(model.c1_yc_vars, model.var_y_cont);
    model.relative_pos.c1_yi_vars = extract_relative_pos(model.c1_yi_vars, model.var_y_int);
    model.relative_pos.c2_xc_vars = extract_relative_pos(model.c2_xc_vars, model.var_x_cont);
    model.relative_pos.c2_xi_vars = extract_relative_pos(model.c2_xi_vars, model.var_x_int);

    model.relative_pos.H_u_vars   = extract_relative_pos(model.H_u_vars,  model.var_u);
    model.relative_pos.F_u_vars   = extract_relative_pos(model.F_u_vars,  model.var_u);


end

%% Helper: extract coefficients with variable filtering (consistent with existing utils)
function [coeff, vars] = extract_coeff_block(var_list, primal_vars, matrix)
    if isempty(var_list) || isempty(primal_vars) || isempty(matrix)
        coeff = [];
        vars = [];
        return;
    end

    var_indices = getvariables(var_list);
    primal_indices = getvariables(primal_vars);
    [~, loc] = ismember(var_indices, primal_indices);

    valid_locs = loc ~= 0;
    vars_index = var_indices(valid_locs);
    vars = recover(vars_index);
    valid_loc = loc(valid_locs);

    if isempty(valid_loc)
        coeff = [];
    else
        coeff = sparse(matrix(:, valid_loc));
    end
end

%% Helper: extract initial values for uncertainty variables based on their positions in var_u
function u_init_values = extract_u_init(var_u_sub, var_u, u_init)
%EXTRACT_U_INIT_VALUES Extracts initial values for a subset of uncertainty variables.
%
%   Inputs:
%       u_vars        - Subset of uncertainty variables (e.g., A2_u_vars)
%       var_u_indices - Variable indices of var_u (precomputed for efficiency)
%       u_init        - Initial values for all uncertainty variables (numeric vector)
%
%   Output:
%       u_init_values - Initial values corresponding to u_vars, maintaining original shape

    if isempty(var_u_sub) || isempty(var_u) || isempty(u_init)
        u_init_values = []; 
        return;
    end
    
    % Get variable indices for u_vars
    var_u_sub_indices = getvariables(var_u_sub(:));
    var_u_indices = getvariables(var_u(:));
    
    % Find positions of u_vars in var_u
    [~, loc] = ismember(var_u_sub_indices, var_u_indices);
    
    % Extract corresponding values from u_init
    valid_locs = loc ~= 0;
    valid_loc = loc(valid_locs);

    if isempty(valid_loc)
        u_init_values = [];
    else
        u_init_values = u_init(valid_loc);
    end
end

%% Helper: Extract the relative positions of each variable
function relative_pos = extract_relative_pos(var_sub, var)
    var_sub_indices = getvariables(var_sub);
    var_indices = getvariables(var);
    [~, loc] = ismember(var_sub_indices, var_indices);
    valid_locs = loc ~= 0;
    relative_pos = loc(valid_locs);
end