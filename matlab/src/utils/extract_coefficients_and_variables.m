function model = extract_coefficients_and_variables(var_x_u, var_z_u, var_x_l, var_z_l, cons_upper, cons_lower, obj_upper, obj_lower, ops)
%EXTRACT_COEFFICIENTS_AND_VARIABLES Extracts coefficient matrices and variable vectors from a general BiMIP model.
%
%   Description:
%       This function takes the YALMIP-based components of a user-defined
%       bilevel program and reformulates them into a standardized matrix-based
%       structure (Ax <= b, Ex == f). It systematically parses both the
%       upper and lower-level problems, identifies the coefficients
%       associated with each variable block (e.g., A_u, B_u, C_u, D_u), and
%       compiles detailed statistics about the model's structure.
%
%   Inputs:
%       var_x_u    - Upper-level continuous variables (sdpvar).
%       var_z_u    - Upper-level integer variables (sdpvar).
%       var_x_l    - Lower-level continuous variables (sdpvar).
%       var_z_l    - Lower-level integer variables (sdpvar).
%       cons_upper - Upper-level constraints (YALMIP constraint object).
%       cons_lower - Lower-level constraints (YALMIP constraint object).
%       obj_upper  - Upper-level objective function (YALMIP expression).
%       obj_lower  - Lower-level objective function (YALMIP expression).
%
%   Output:
%       model - A struct containing the extracted standard-form BiMIP matrices,
%               vectors, and problem statistics.

    % --- Step 1: Extract LP/QP models from YALMIP objects ---
    % Use a YALMIP backend function to get matrix representations for each level.
    model_details_upper = extract_lp_qp_model(cons_upper, obj_upper);
    model_details_lower = extract_lp_qp_model(cons_lower, obj_lower);
    
    % Initialize the model struct and store original variable sets.
    model = struct();
    model.var_x_u = var_x_u;
    model.var_z_u = var_z_u;
    model.var_x_l = var_x_l;
    model.var_z_l = var_z_l;
    
    % --- Step 2: Extract Coefficient Matrices with Variable Filtering ---
    % This section maps the raw matrices from YALMIP to the structured
    % BiMIP format (A_u, B_u, C_u, etc.) by associating coefficients
    % with the correct variable blocks.
    
    % Inequality matrices (A*x <= b)
    [model.A_u, model.A_u_vars] = extract_coefficients(var_x_u, model_details_upper.primal, model_details_upper.A);
    [model.B_u, model.B_u_vars] = extract_coefficients(var_z_u, model_details_upper.primal, model_details_upper.A);
    [model.C_u, model.C_u_vars] = extract_coefficients(var_x_l, model_details_upper.primal, model_details_upper.A);
    [model.D_u, model.D_u_vars] = extract_coefficients(var_z_l, model_details_upper.primal, model_details_upper.A);
    
    [model.A_l, model.A_l_vars] = extract_coefficients(var_x_u, model_details_lower.primal, model_details_lower.A);
    [model.B_l, model.B_l_vars] = extract_coefficients(var_z_u, model_details_lower.primal, model_details_lower.A);
    [model.C_l, model.C_l_vars] = extract_coefficients(var_x_l, model_details_lower.primal, model_details_lower.A);
    [model.D_l, model.D_l_vars] = extract_coefficients(var_z_l, model_details_lower.primal, model_details_lower.A);
    
    % Equality matrices (E*x == f)
    [model.E_u, model.E_u_vars] = extract_coefficients(var_x_u, model_details_upper.primal, model_details_upper.E);
    [model.F_u, model.F_u_vars] = extract_coefficients(var_z_u, model_details_upper.primal, model_details_upper.E);
    [model.G_u, model.G_u_vars] = extract_coefficients(var_x_l, model_details_upper.primal, model_details_upper.E);
    [model.H_u, model.H_u_vars] = extract_coefficients(var_z_l, model_details_upper.primal, model_details_upper.E);
    
    [model.E_l, model.E_l_vars] = extract_coefficients(var_x_u, model_details_lower.primal, model_details_lower.E);
    [model.F_l, model.F_l_vars] = extract_coefficients(var_z_u, model_details_lower.primal, model_details_lower.E);
    [model.G_l, model.G_l_vars] = extract_coefficients(var_x_l, model_details_lower.primal, model_details_lower.E);
    [model.H_l, model.H_l_vars] = extract_coefficients(var_z_l, model_details_lower.primal, model_details_lower.E);
    
    % --- Step 3: Extract Objective Function Vectors ---
    % Extract objective coefficients (c vectors), handling transpose for correct dimensions.
    [c1_temp, model.c1_vars] = extract_coefficients(var_x_u, model_details_upper.primal, model_details_upper.c');
    model.c1 = c1_temp(:);
    [c2_temp, model.c2_vars] = extract_coefficients(var_z_u, model_details_upper.primal, model_details_upper.c');
    model.c2 = c2_temp(:);
    [c3_temp, model.c3_vars] = extract_coefficients(var_x_l, model_details_upper.primal, model_details_upper.c');
    model.c3 = c3_temp(:);
    [c4_temp, model.c4_vars] = extract_coefficients(var_z_l, model_details_upper.primal, model_details_upper.c');
    model.c4 = c4_temp(:);
    
    [c5_temp, model.c5_vars] = extract_coefficients(var_x_l, model_details_lower.primal, model_details_lower.c');
    model.c5 = c5_temp(:);
    [c6_temp, model.c6_vars] = extract_coefficients(var_z_l, model_details_lower.primal, model_details_lower.c');
    model.c6 = c6_temp(:);
    
    % --- Step 4: Extract Right-Hand Side (RHS) Vectors ---
    model.b_u = model_details_upper.b;
    model.b_l = model_details_lower.b;
    model.f_u = model_details_upper.f;
    model.f_l = model_details_lower.f;
    
    % --- Step 5: Classify and Count Variables ---
    % Consolidate all variable vectors for classification.
    all_vars = [var_x_u(:); var_z_u(:); var_x_l(:); var_z_l(:)];
    integer_vars = [var_z_u(:); var_z_l(:)];

    % Iterate through integer variables to identify binary ones.
    bin_count = 0;
    for i = 1:length(integer_vars)
        if is(integer_vars(i), 'binary')
            bin_count = bin_count + 1;
        end
    end
    
    % Store variable counts in the model struct.
    int_count = length(integer_vars);
    cont_count = length(all_vars) - int_count;
    model.cont_vars = cont_count;
    model.int_vars = int_count;
    model.bin_vars = bin_count;
    
    % --- Step 6: Collect Model Statistics ---
    % Upper-level constraint statistics
    model.upper_ineq_rows = length(model.b_u);
    model.upper_eq_rows = length(model.f_u);
    model.upper_total_rows = model.upper_ineq_rows + model.upper_eq_rows;
    model.upper_nonzeros = nnz(model.A_u) + nnz(model.B_u) + nnz(model.C_u) + nnz(model.D_u) +...
                     nnz(model.E_u) + nnz(model.F_u) + nnz(model.G_u) + nnz(model.H_u);
    
    % Lower-level constraint statistics
    model.lower_ineq_rows = length(model.b_l);
    model.lower_eq_rows = length(model.f_l);
    model.lower_total_rows = model.lower_ineq_rows + model.lower_eq_rows;
    model.lower_nonzeros = nnz(model.A_l) + nnz(model.B_l) + nnz(model.C_l) + nnz(model.D_l) +...
                     nnz(model.E_l) + nnz(model.F_l) + nnz(model.G_l) + nnz(model.H_l);
                 
    % --- Step 7: Finalize and Collect Coefficient Statistics ---
    % Store original RHS vector lengths for reference.
    model.length_b_u = length(model.b_u);
    model.length_b_l = length(model.b_l);
    model.length_f_u = length(model.f_u);
    model.length_f_l = length(model.f_l);
    
    % Range of matrix coefficients (absolute values of non-zeros).
    all_matrix_nz = sparse([abs(nonzeros([model.A_u, model.B_u, model.C_u, model.D_u]));...
                     abs(nonzeros([model.E_u, model.F_u, model.G_u, model.H_u]));...
                     abs(nonzeros([model.A_l, model.B_l, model.C_l, model.D_l]));...
                     abs(nonzeros([model.E_l, model.F_l, model.G_l, model.H_l]))]);
    if nnz(all_matrix_nz) > 0
        model.matrix_min = full(min(all_matrix_nz(all_matrix_nz > 0)));
        model.matrix_max = full(max(all_matrix_nz));
    else
        model.matrix_min = 0;
        model.matrix_max = 0;
    end
    
    % Range of objective coefficients (absolute values of non-zeros).
    all_obj = abs([model.c1(:); model.c2(:); model.c3(:); model.c4(:); model.c5(:); model.c6(:)]);
    all_obj = nonzeros(all_obj); % Exclude zero values.
    if ~isempty(all_obj)
        model.obj_min = full(min(all_obj));
        model.obj_max = full(max(all_obj));
    else
        model.obj_min = 0;
        model.obj_max = 0;
    end
    
    % Range of RHS values (absolute values of non-zeros).
    all_rhs = abs([model.b_u; model.f_u; model.b_l; model.f_l]); 
    all_rhs = nonzeros(all_rhs); % Exclude zero values.
    if ~isempty(all_rhs)
        model.rhs_min = full(min(all_rhs));
        model.rhs_max = full(max(all_rhs));
    else
        model.rhs_min = 0;
        model.rhs_max = 0;
    end
    
    % =====================================================================
    % --- Step 8: Identify Linking Variables ---
    % =====================================================================
    model.linking = struct();

    idx_linking_vars = [];
    if isfield(model, 'A_l_vars') && ~isempty(model.A_l_vars)
        idx_linking_vars = [idx_linking_vars; reshape(getvariables(model.A_l_vars(:)), [], 1)];
    end
    if isfield(model, 'B_l_vars') && ~isempty(model.B_l_vars)
        idx_linking_vars = [idx_linking_vars; reshape(getvariables(model.B_l_vars(:)), [], 1)];
    end
    if isfield(model, 'E_l_vars') && ~isempty(model.E_l_vars)
        idx_linking_vars = [idx_linking_vars; reshape(getvariables(model.E_l_vars(:)), [], 1)];
    end
    if isfield(model, 'F_l_vars') && ~isempty(model.F_l_vars)
        idx_linking_vars = [idx_linking_vars; reshape(getvariables(model.F_l_vars(:)), [], 1)];
    end
    
    idx_linking_vars = unique(idx_linking_vars);
    
    idx_A_u_vars = getvariables(model.A_u_vars);
    idx_B_u_vars = getvariables(model.B_u_vars);
    idx_E_u_vars = getvariables(model.E_u_vars);
    idx_F_u_vars = getvariables(model.F_u_vars);
    idx_c1_vars = getvariables(model.c1_vars);
    idx_c2_vars = getvariables(model.c2_vars);
    
    % --- 识别关联变量 (Linking Variables) ---
    model.linking.A_u_vars_link = recover(intersect(idx_A_u_vars, idx_linking_vars));
    model.linking.B_u_vars_link = recover(intersect(idx_B_u_vars, idx_linking_vars));
    model.linking.E_u_vars_link = recover(intersect(idx_E_u_vars, idx_linking_vars));
    model.linking.F_u_vars_link = recover(intersect(idx_F_u_vars, idx_linking_vars));
    model.linking.c1_vars_link = recover(intersect(idx_c1_vars, idx_linking_vars));
    model.linking.c2_vars_link = recover(intersect(idx_c2_vars, idx_linking_vars));
    
    % --- 识别非关联变量 (Non-linking Variables) ---
    % 注意：这里需要对比的是"该类变量的总索引"与"该类变量中被识别为link的索引"
    model.linking.A_u_vars_nolink = recover(setdiff(idx_A_u_vars, idx_linking_vars));
    model.linking.B_u_vars_nolink = recover(setdiff(idx_B_u_vars, idx_linking_vars));
    model.linking.E_u_vars_nolink = recover(setdiff(idx_E_u_vars, idx_linking_vars));
    model.linking.F_u_vars_nolink = recover(setdiff(idx_F_u_vars, idx_linking_vars));
    model.linking.c1_vars_nolink = recover(setdiff(idx_c1_vars, idx_linking_vars));
    model.linking.c2_vars_nolink = recover(setdiff(idx_c2_vars, idx_linking_vars));

    % =====================================================================
    % --- Step 9: Extract Coefficients for Linked and Non-linked Variables ---
    % =====================================================================
    % 提取 A 对应的系数
    [model.linking.A_u_link, ~] = extract_coefficients(model.linking.A_u_vars_link, model.A_u_vars, model.A_u);
    [model.linking.A_u_nolink, ~] = extract_coefficients(model.linking.A_u_vars_nolink, model.A_u_vars, model.A_u);

    % 提取 B 对应的系数
    [model.linking.B_u_link, ~] = extract_coefficients(model.linking.B_u_vars_link, model.B_u_vars, model.B_u);
    [model.linking.B_u_nolink, ~] = extract_coefficients(model.linking.B_u_vars_nolink, model.B_u_vars, model.B_u);

    % 提取 E 对应的系数
    [model.linking.E_u_link, ~] = extract_coefficients(model.linking.E_u_vars_link, model.E_u_vars, model.E_u);
    [model.linking.E_u_nolink, ~] = extract_coefficients(model.linking.E_u_vars_nolink, model.E_u_vars, model.E_u);

    % 提取 F 对应的系数
    [model.linking.F_u_link, ~] = extract_coefficients(model.linking.F_u_vars_link, model.F_u_vars, model.F_u);
    [model.linking.F_u_nolink, ~] = extract_coefficients(model.linking.F_u_vars_nolink, model.F_u_vars, model.F_u);

    % 提取 c1 对应的系数
    [c1_link_temp, ~] = extract_coefficients(model.linking.c1_vars_link, model.c1_vars, model.c1');
    model.linking.c1_link = c1_link_temp(:);
    [c1_nolink_temp, ~] = extract_coefficients(model.linking.c1_vars_nolink, model.c1_vars, model.c1');
    model.linking.c1_nolink = c1_nolink_temp(:);

    % 提取 c2 对应的系数
    [c2_link_temp, ~] = extract_coefficients(model.linking.c2_vars_link, model.c2_vars, model.c2');
    model.linking.c2_link = c2_link_temp(:);
    [c2_nolink_temp, ~] = extract_coefficients(model.linking.c2_vars_nolink, model.c2_vars, model.c2');
    model.linking.c2_nolink = c2_nolink_temp(:);
end

%% Helper Function - Extract Coefficients with Variable Filtering
function [coeff, vars] = extract_coefficients(var_list, primal_vars, matrix)
% This function extracts a sub-matrix by selecting specific columns from a
% larger matrix based on a variable list. The number of rows remains unchanged.

    if isempty(var_list) || isempty(primal_vars) || isempty(matrix)
        coeff = [];
        vars = [];
        return;
    end
    
    % Get variable indices and find their locations in the primal variable list.
    var_indices = getvariables(var_list);
    primal_indices = getvariables(primal_vars);
    [~, loc] = ismember(var_indices, primal_indices);
    
    % Filter out variables from var_list that are not present in primal_vars.
    valid_locs = loc ~= 0;
    vars_index = var_indices(valid_locs);
    vars = recover(vars_index);
    valid_loc = loc(valid_locs);
    
    % Extract the corresponding columns from the matrix.
    if isempty(valid_loc)
        coeff = [];
    else
        coeff = matrix(:, valid_loc);
        coeff = sparse(coeff);  % Ensure the output matrix is sparse.
    end
end