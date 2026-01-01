function Solution = solveBiLPbyStrongDuality(model, ops)
%SOLVEBILPBYSTRONGDUALITY Solves a BiLP model using Strong Duality reformulation.
%
%   Description:
%       This function solves a Bilevel Linear Programming (BiLP) problem by
%       replacing the lower-level problem with its Primal Feasibility, Dual
%       Feasibility, and Strong Duality equality conditions. This results in a
%       single-level problem with bilinear constraints (unless linearized or
%       solved by a global solver).
%
%   Inputs:
%       model - struct: The standard PowerBiMIP model structure.
%       ops   - struct: A struct containing solver options.
%
%   Output:
%       Solution - struct: A struct containing the solution of the problem.

%   primal problem:
%   min c1'x_u + c2'z_u + c3'x_l + c4'z_l
%   s.t. A_u*x_u + B_u*z_u + C_u*x_l + D_u*z_l <= b_u
%        E_u*x_u + F_u*z_u + G_u*x_l + H_u*z_l = f_u
%        min c5'x_l
%        s.t. A_l*x_u + B_l*z_u + C_l*x_l <= b_l : dual_ineq
%             E_l*x_u + F_l*z_u + G_l*x_l = f_l  : dual_eq

%   single level problem:
%   min c1'x_u + c2'z_u + c3'x_l + c4'z_l
%   s.t. A_u*x_u + B_u*z_u + C_u*x_l + D_u*z_l <= b_u
%        E_u*x_u + F_u*z_u + G_u*x_l + H_u*z_l = f_u
%   primal feasibility:
%        A_l*x_u + B_l*z_u + C_l*x_l <= b_l
%        E_l*x_u + F_l*z_u + G_l*x_l = f_l
%   dual feasibility:
%        dual_ineq <= 0
%        dual_ineq' * C_l + dual_eq' * G_l == c5'
%   strong duality (Primal Obj <= Dual Obj):
%        c5' * x_l <= (b_l - A_l*x_u - B_l*z_u)' * dual_ineq + (f_l - E_l*x_u - F_l*z_u)' * dual_eq
%   where x_u, z_u are the variables of the upper level,
%         x_l are the variables of the lower level,
%         dual_ineq, dual_eq are the dual variables of the lower level inequality and equality constraints,

    %% Define Dual Variables
    bigM = inf;  % Big-M constant for dual variable bounds
    
    % Dual variables for lower-level inequality constraints (size of b_l)
    % Bounded: [-bigM, 0]
    model.var.dual_ineq = sdpvar(length(model.b_l), 1, 'full');
    
    % Dual variables for lower-level equality constraints (size of f_l)
    % Bounded: [-bigM, bigM]
    model.var.dual_eq = sdpvar(length(model.f_l), 1, 'full');

    %% Constraints building
    model.cons = [];

    % --- Upper Level Constraints ---
    if isempty(model.b_u)
        model.cons = model.cons + [];
    else
        model.cons = model.cons + ...
            ([model.A_u, model.B_u, ...
            model.C_u, model.D_u] * ...
            [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
            model.b_u);
    end

    if isempty(model.f_u)
        model.cons = model.cons + [];
    else
        model.cons = model.cons + ...
            ([model.E_u, model.F_u, ...
            model.G_u, model.H_u] * ...
            [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
            model.f_u);
    end

    % --- Lower Level Primal Feasibility ---
    if isempty(model.b_l)
        model.cons = model.cons + [];
    else
        model.cons = model.cons + ...
            ([model.A_l, model.B_l, ...
            model.C_l, model.D_l] * ...
            [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
            model.b_l);
    end

    if isempty(model.f_l)
        model.cons = model.cons + [];
    else
        model.cons = model.cons + ...
            ([model.E_l, model.F_l, ...
            model.G_l, model.H_l] * ...
            [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
            model.f_l);
    end

    % --- Lower Level Dual Feasibility ---
    constraint_ineq = 0;
    constraint_eq = 0;
    
    if ~isempty(model.var.dual_ineq)
        constraint_ineq = model.var.dual_ineq' * model.C_l;
        % Sign constraint: dual_ineq in [-bigM, 0]
        model.cons = model.cons + [model.var.dual_ineq >= -bigM, model.var.dual_ineq <= 0];
    end
    
    if ~isempty(model.var.dual_eq)
        constraint_eq = model.var.dual_eq' * model.G_l;
        % Bound constraint: dual_eq in [-bigM, bigM]
        model.cons = model.cons + [model.var.dual_eq >= -bigM, model.var.dual_eq <= bigM];
    end
    
    model.cons = model.cons + (constraint_ineq + constraint_eq == model.c5');

    % --- Strong Duality Equality ---
    term_ineq = 0;
    if ~isempty(model.var.dual_ineq)
        rhs_ineq = model.b_l - [model.A_l, model.B_l] * [model.A_l_vars; model.B_l_vars];
        term_ineq = model.var.dual_ineq' * rhs_ineq;
    end
    
    term_eq = 0;
    if ~isempty(model.var.dual_eq)
        rhs_eq = model.f_l - [model.E_l, model.F_l] * [model.E_l_vars; model.F_l_vars];
        term_eq = model.var.dual_eq' * rhs_eq;
    end
    
    dual_obj = term_ineq + term_eq;
    primal_obj = model.c5' * model.C_l_vars;
    
    % Strong duality cut
    model.cons = model.cons + (primal_obj <= dual_obj);
    
    % Note: The weak duality (primal_obj >= dual_obj) is theoretically implied by feasibility

    %% Objective building (Upper Level Objective)
    model.obj = [model.c1', model.c2', ...
        model.c3', model.c4'] * ...
        [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];

    %% Solving
    model.solution = optimize(model.cons, model.obj, ops.ops_MP);

    %% Output
    Solution = myFun_GetValue(model);
end
