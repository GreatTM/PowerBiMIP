function model_final = transform_coupled_to_uncoupled(coupled_info, model, ops)
%TRANSFORM_COUPLED_TO_UNCOUPLED Transforms a coupled model to an uncoupled one.
%
%   Description:
%       This function transforms an optimistic bilevel model with coupled
%       constraints into an equivalent optimistic model without coupled
%       constraints. The transformation is achieved by:
%       1. Introducing non-negative slack variables for each coupled constraint.
%       2. Moving the original coupled constraints to the lower-level problem,
%          relaxed by these slack variables.
%       3. Adding the slack variables to the upper-level objective function,
%          penalized by a large coefficient 'kappa'.
%
%   Input:
%       coupled_info
%       model - struct: A standard PowerBiMIP model with coupled constraints.
%       ops
%
%   Output:
%       model_final - struct: An equivalent standard PowerBiMIP model that is
%                     guaranteed to be uncoupled.

    % --- Step 1: Identify Coupled Constraints ---
    m_ineq_c = coupled_info.num_ineq; 
    m_eq_c = coupled_info.num_eq;

    if ops.verbose >= 1
        fprintf('Identified %d coupled inequalities and %d coupled equalities to transform.\n', m_ineq_c, m_eq_c);
    end
    idx_ineq_c = coupled_info.ineq_idx; idx_ineq_nc = ~idx_ineq_c;
    idx_eq_c = coupled_info.eq_idx;   idx_eq_nc = ~idx_eq_c;
    
    % --- Step 2: Create New Slack Variables ---
    % Slack variables for inequality constraints (>= 0).
    epsilon_ineq = sdpvar(m_ineq_c, 1, 'full');
    eps_eq_pos = sdpvar(m_eq_c, 1, 'full');
    eps_eq_neg = sdpvar(m_eq_c, 1, 'full');
    new_slack_vars = [epsilon_ineq; eps_eq_pos; eps_eq_neg];
    
    % --- Step 3: Reformulate the Model Components in YALMIP ---
    model_p.c3_vars = [model.c3_vars; new_slack_vars];
    penalty_coeffs = ops.kappa * ones(length(new_slack_vars), 1);
    model_p.c3 = [model.c3; penalty_coeffs];
    
    % 3.2 Define New Constraint Sets 
    %  Extract sub-matrices for non-coupled upper-level constraints.
    if ~isempty(model.A_u); model_p.A_u = model.A_u(idx_ineq_nc,:); else; model_p.A_u = []; end
    if ~isempty(model.B_u); model_p.B_u = model.B_u(idx_ineq_nc,:); else; model_p.B_u = []; end
    if ~isempty(model.C_u); model_p.C_u = model.C_u(idx_ineq_nc,:); else; model_p.C_u = []; end
    if ~isempty(model.D_u); model_p.D_u = model.D_u(idx_ineq_nc,:); else; model_p.D_u = []; end
    if ~isempty(model.b_u); model_p.b_u = model.b_u(idx_ineq_nc);   else; model_p.b_u = []; end
    if ~isempty(model.E_u); model_p.E_u = model.E_u(idx_eq_nc,:); else; model_p.E_u = []; end
    if ~isempty(model.F_u); model_p.F_u = model.F_u(idx_eq_nc,:); else; model_p.F_u = []; end
    if ~isempty(model.G_u); model_p.G_u = model.G_u(idx_eq_nc,:); else; model_p.G_u = []; end
    if ~isempty(model.H_u); model_p.H_u = model.H_u(idx_eq_nc,:); else; model_p.H_u = []; end
    if ~isempty(model.f_u); model_p.f_u = model.f_u(idx_eq_nc);   else; model_p.f_u = []; end
    
    % Extract sub-matrices for the original coupled constraints.
    if ~isempty(model.A_u); A_u_c = model.A_u(idx_ineq_c,:); else; A_u_c = []; end
    if ~isempty(model.B_u); B_u_c = model.B_u(idx_ineq_c,:); else; B_u_c = []; end
    if ~isempty(model.C_u); C_u_c = model.C_u(idx_ineq_c,:); else; C_u_c = []; end
    if ~isempty(model.D_u); D_u_c = model.D_u(idx_ineq_c,:); else; D_u_c = []; end
    if ~isempty(model.b_u); b_u_c = model.b_u(idx_ineq_c);   else; b_u_c = []; end
    if ~isempty(model.E_u); E_u_c = model.E_u(idx_eq_c,:); else; E_u_c = []; end
    if ~isempty(model.F_u); F_u_c = model.F_u(idx_eq_c,:); else; F_u_c = []; end
    if ~isempty(model.G_u); G_u_c = model.G_u(idx_eq_c,:); else; G_u_c = []; end
    if ~isempty(model.H_u); H_u_c = model.H_u(idx_eq_c,:); else; H_u_c = []; end
    if ~isempty(model.f_u); f_u_c = model.f_u(idx_eq_c);   else; f_u_c = []; end
    
    var_x_u = model.var_x_u;
    var_z_u = model.var_z_u;
    var_x_l = [reshape(model.var_x_l, [], 1); new_slack_vars]; % new lower-level vars
    var_z_l = model.var_z_l;
    cons_upper = [];
    % ineq
    if isempty(model_p.b_u)
        cons_upper = cons_upper + [];
    else
        cons_upper = cons_upper + ...
            ([model_p.A_u, model_p.B_u, ...
            model_p.C_u, model_p.D_u] * ...
            [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
            model_p.b_u);
    end

    % eq
    if isempty(model_p.f_u)
        cons_upper = cons_upper + [];
    else
        cons_upper = cons_upper + ...
            ([model_p.E_u, model_p.F_u, ...
            model_p.G_u, model_p.H_u] * ...
            [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
            model_p.f_u);
    end

    cons_lower = [];
    % ineq
    if isempty(model.b_l)
        cons_lower = cons_lower + [];
    else
        cons_lower = cons_lower + ...
            ([model.A_l, model.B_l, ...
            model.C_l, model.D_l] * ...
            [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
            model.b_l);
    end
    % eq
    if isempty(model.f_l)
        cons_lower = cons_lower + [];
    else
        cons_lower = cons_lower + ...
            ([model.E_l, model.F_l, ...
            model.G_l, model.H_l] * ...
            [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
            model.f_l);
    end
    % ineq
    if isempty(b_u_c)
        cons_lower = cons_lower + [];
    else
        cons_lower = cons_lower + ...
            ([A_u_c, B_u_c, ...
            C_u_c, D_u_c] * ...
            [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
            b_u_c + eye(m_ineq_c) * epsilon_ineq);
    end
    % eq
    if isempty(f_u_c)
        cons_lower = cons_lower + [];
    else
        cons_lower = cons_lower + ...
            ([E_u_c, F_u_c, ...
            G_u_c, H_u_c] * ...
            [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
            f_u_c + eye(m_eq_c) * eps_eq_pos - eye(m_eq_c) * eps_eq_neg);
    end
    % non-negtive
    cons_lower = cons_lower + ...
        (new_slack_vars >= 0);

    obj_upper = [model.c1', model.c2', ...
            model_p.c3', model.c4'] * ...
            [model.c1_vars; model.c2_vars; model_p.c3_vars; model.c4_vars];

    obj_lower = [model.c5', model.c6'] * ...
        [model.c5_vars; model.c6_vars];

    model_final = extract_coefficients_and_variables(var_x_u, ...
        var_z_u, var_x_l, var_z_l, cons_upper, cons_lower, obj_upper, obj_lower, ops);
    model_final.var = model.var;
end