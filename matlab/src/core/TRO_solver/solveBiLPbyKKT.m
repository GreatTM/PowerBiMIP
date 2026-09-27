function Solution = solveBiLPbyKKT(model, ops)
%SOLVEBILPBYKKT Solves a BiLP model using the KKT reformulation.
%
%   Description:
%       This function solves a Bilevel Linear Programming (BiLP) problem by
%       replacing the lower-level problem with its KKT conditions, resulting
%       in a single-level Mixed-Integer Linear Programming (MIP) problem
%       (due to complementarity constraints usually handled via SOS1 or Big-M).
%
%   Inputs:
%       model - struct: The standard PowerBiMIP model structure.
%       ops   - struct: A struct containing solver options.
%
%   Output:
%       Solution - struct: A struct containing the solution of the problem.

    %% Constraints building
    model.cons = [];
    
    % --- Upper Level Constraints ---
    % inequality
    if isempty(model.b_u)
        model.cons = model.cons + [];
    else
        model.cons = model.cons + ...
            ([model.A_u, model.B_u, ...
            model.C_u, model.D_u] * ...
            [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= ...
            model.b_u);
    end

    % equality
    if isempty(model.f_u)
        model.cons = model.cons + [];
    else
        model.cons = model.cons + ...
            ([model.E_u, model.F_u, ...
            model.G_u, model.H_u] * ...
            [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == ...
            model.f_u);
    end

    % --- Lower Level Problem Setup for KKT ---
    ll_constraints = [];
    
    % inequality
    if isempty(model.b_l)
        ll_constraints = ll_constraints + [];
    else
        ll_constraints = ll_constraints + ...
            ([model.A_l, model.B_l, ...
            model.C_l, model.D_l] * ...
            [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
            model.b_l);
    end
    
    % equality
    if isempty(model.f_l)
        ll_constraints = ll_constraints + [];
    else
        ll_constraints = ll_constraints + ...
            ([model.E_l, model.F_l, ...
            model.G_l, model.H_l] * ...
            [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
            model.f_l);
    end

    % Objective of Lower Level
    ll_objective = [model.c5', model.c6'] * [model.c5_vars; model.c6_vars];

    % --- Generate KKT Conditions ---
    % The parametric variables are the upper level variables involved in the lower level.
    % Based on standard form: A_l, B_l are coefficients for upper level variables.
    parametric_vars = [model.A_l_vars; model.B_l_vars; ...
                       model.E_l_vars; model.F_l_vars];

    [kkt_conds, ~] = kkt(ll_constraints, ll_objective, parametric_vars, sdpsettings('kkt.dualbounds',0,'verbose',0));
    
    % Add KKT conditions to the main model constraints
    model.cons = model.cons + kkt_conds;
    
    % (Note: Primal feasibility of LL is included in kkt_conds)

    %% Objective building (Upper Level Objective)
    model.obj = [model.c1', model.c2', ...
        model.c3', model.c4'] * ...
        [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];

    %% Solving
    model.solution = optimize(model.cons, model.obj, ops.ops_MP);

    %% Output
    Solution = myFun_GetValue(model);
end
