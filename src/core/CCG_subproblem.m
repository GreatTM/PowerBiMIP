function sp_result = CCG_subproblem(model, ops, y_star, ~)
%CCG_SUBPROBLEM Solves the subproblem for the C&CG algorithm (TRO-LP with RCR).
%
%   Description:
%       This function solves the subproblem (SP) of the Column-and-Constraint
%       Generation (C&CG) algorithm for two-stage robust optimization with
%       linear programming recourse (TRO-LP), assuming relatively complete
%       response (RCR). It converts the TRO subproblem (max-min structure)
%       into a BiMIP format and calls solve_BiMIP to find the worst-case
%       scenario u*.
%
%       The subproblem is:
%       Q(y*) = max_{u in U} min_{x >= 0} { d^T x : G x >= h - E y* - M u }
%
%       Converted to BiMIP format:
%       - Upper-level: u (uncertainty variable), constraints: U
%       - Lower-level: x (second-stage recourse), constraints: G x >= h - E y* - M u
%       - Objectives: upper = -d^T x, lower = d^T x (to convert max-min to min-min)
%
%   Inputs:
%       model            - struct: The standardized robust model structure
%                          extracted by extract_robust_coeffs (containing
%                          first-stage/second-stage coefficients, uncertainty set,
%                          variables, statistics).
%       ops              - struct: A struct containing solver options (from
%                          RobustCCGsettings), including mode, verbose, solver, etc.
%       y_star           - double vector: First-stage optimal decision variables y*
%                          (fixed as constants).
%       iteration_record - struct: A struct containing the history of the
%                          C&CG algorithm's progress (optional, for debugging).
%
%   Output:
%       sp_result - struct: A struct containing the solution of the subproblem:
%                   - u_star: Worst-case scenario u* (vector)
%                   - Q_value: SP objective value Q(y*) (scalar)
%                   - x_star: Second-stage optimal decision variables x* (vector, optional)
%                   - sp_solution: Complete SP solution struct (with solve_BiMIP output)
%                   - solution: YALMIP solution status (.problem field, 0 means success)
%
%   See also solve_BiMIP, CCG_master_problem, algorithm_CCG

    %% Step 1: Map Variables for BiMIP Format
    % Upper-level: u (uncertainty variable)
    var_x_u = model.var_u;  % u as upper-level continuous variable
    var_z_u = [];           % No upper-level integer variables
    
    % Lower-level: x (second-stage recourse variable)
    var_x_l = model.var_x_cont;  % x as lower-level continuous variable
    var_z_l = [];                % No lower-level integer variables (TRO-LP)
    
    % Original variables for solve_BiMIP
    % Store as a struct to preserve variable identity for solution extraction
    original_var = struct();
    if ~isempty(var_x_u)
        original_var.var_u = var_x_u;
    end
    if ~isempty(var_x_l)
        original_var.var_x = var_x_l;
    end
    
    %% Step 2: Build Upper-Level Constraints (Uncertainty Set)
    % Uncertainty set constraints: H_u u <= a_u, F_u u == g_u
    cons_upper = [];
    
    % Inequality constraints: H_u u <= a_u
    if ~isempty(model.a_u) && ~isempty(model.H_u) && ~isempty(model.H_u_vars)
        cons_upper = cons_upper + (model.H_u * model.H_u_vars <= model.a_u);
    end
    
    % Equality constraints: F_u u == g_u
    if ~isempty(model.g_u) && ~isempty(model.F_u) && ~isempty(model.F_u_vars)
        cons_upper = cons_upper + (model.F_u * model.F_u_vars == model.g_u);
    end
    
    %% Step 3: Build Lower-Level Constraints (Second-Stage Constraints with Fixed y*)
    % Need to substitute y* into the constraints: G x >= h - E y* - M u
    cons_lower = [];
    
    % y_star is now a struct containing all y-related variable solutions
    % Directly use the pre-computed values from CCG_master_problem
    
    % Inequality constraints: A2_yc * y_cont + A2_yi * y_int + A2_u * u + A2_xc * x <= b2
    % Convert to: A2_u * u + A2_xc * x <= b2 - A2_yc * y_star.A2_yc_vars - A2_yi * y_star.A2_yi_vars
    if ~isempty(model.b2)
        % Compute RHS: b2 - A2_yc * y_star.A2_yc_vars - A2_yi * y_star.A2_yi_vars
        rhs_ineq = model.b2;
        
        % Subtract A2_yc * y_star.A2_yc_vars
        if ~isempty(model.A2_yc) && isfield(y_star, 'A2_yc_vars') && ~isempty(y_star.A2_yc_vars)
            rhs_ineq = rhs_ineq - model.A2_yc * y_star.A2_yc_vars(:);
        end
        
        % Subtract A2_yi * y_star.A2_yi_vars
        if ~isempty(model.A2_yi) && isfield(y_star, 'A2_yi_vars') && ~isempty(y_star.A2_yi_vars)
            rhs_ineq = rhs_ineq - model.A2_yi * y_star.A2_yi_vars(:);
        end
        
        % Build constraint: A2_u * u + A2_xc * x <= rhs_ineq
        lhs_ineq = 0;
        if ~isempty(model.A2_u) && ~isempty(model.A2_u_vars)
            lhs_ineq = lhs_ineq + model.A2_u * model.A2_u_vars;
        end
        if ~isempty(model.A2_xc) && ~isempty(model.A2_xc_vars)
            lhs_ineq = lhs_ineq + model.A2_xc * model.A2_xc_vars;
        end
        if ~isempty(model.A2_xi) && ~isempty(model.A2_xi_vars)
            lhs_ineq = lhs_ineq + model.A2_xi * model.A2_xi_vars;
        end
        
        if ~isempty(lhs_ineq)
            cons_lower = cons_lower + (lhs_ineq <= rhs_ineq);
        end
    end
    
    % Equality constraints: E2_yc * y_cont + E2_yi * y_int + E2_u * u + E2_xc * x == f2
    % Convert to: E2_u * u + E2_xc * x == f2 - E2_yc * y_star.E2_yc_vars - E2_yi * y_star.E2_yi_vars
    if ~isempty(model.f2)
        % Compute RHS: f2 - E2_yc * y_star.E2_yc_vars - E2_yi * y_star.E2_yi_vars
        rhs_eq = model.f2;
        
        % Subtract E2_yc * y_star.E2_yc_vars
        if ~isempty(model.E2_yc) && isfield(y_star, 'E2_yc_vars') && ~isempty(y_star.E2_yc_vars)
            rhs_eq = rhs_eq - model.E2_yc * y_star.E2_yc_vars(:);
        end
        
        % Subtract E2_yi * y_star.E2_yi_vars
        if ~isempty(model.E2_yi) && isfield(y_star, 'E2_yi_vars') && ~isempty(y_star.E2_yi_vars)
            rhs_eq = rhs_eq - model.E2_yi * y_star.E2_yi_vars(:);
        end
        
        % Build constraint: E2_u * u + E2_xc * x == rhs_eq
        lhs_eq = 0;
        if ~isempty(model.E2_u) && ~isempty(model.E2_u_vars)
            lhs_eq = lhs_eq + model.E2_u * model.E2_u_vars;
        end
        if ~isempty(model.E2_xc) && ~isempty(model.E2_xc_vars)
            lhs_eq = lhs_eq + model.E2_xc * model.E2_xc_vars;
        end
        if ~isempty(model.E2_xi) && ~isempty(model.E2_xi_vars)
            lhs_eq = lhs_eq + model.E2_xi * model.E2_xi_vars;
        end
        
        if ~isempty(lhs_eq)
            cons_lower = cons_lower + (lhs_eq == rhs_eq);
        end
    end
    
    %% Step 4: Build Objective Functions
    % Upper-level objective: -d^T x (to convert max to min)
    obj_upper = [];
    if ~isempty(model.c2_xc) && ~isempty(model.c2_xc_vars)
        obj_upper = - (model.c2_xc' * model.c2_xc_vars);
    end
    if ~isempty(model.c2_xi) && ~isempty(model.c2_xi_vars)
        if isempty(obj_upper)
            obj_upper = - (model.c2_xi' * model.c2_xi_vars);
        else
            obj_upper = obj_upper - (model.c2_xi' * model.c2_xi_vars);
        end
    end
    if isempty(obj_upper)
        obj_upper = 0;  % Fallback if no second-stage objective
    end
    
    % Lower-level objective: d^T x (min structure)
    obj_lower = [];
    if ~isempty(model.c2_xc) && ~isempty(model.c2_xc_vars)
        obj_lower = model.c2_xc' * model.c2_xc_vars;
    end
    if ~isempty(model.c2_xi) && ~isempty(model.c2_xi_vars)
        if isempty(obj_lower)
            obj_lower = model.c2_xi' * model.c2_xi_vars;
        else
            obj_lower = obj_lower + (model.c2_xi' * model.c2_xi_vars);
        end
    end
    if isempty(obj_lower)
        obj_lower = 0;  % Fallback if no second-stage objective
    end
    
    %% Step 5: Build BiMIP Options and Call solve_BiMIP
    % Map ops.mode to BiMIP method
    if strcmpi(ops.mode, 'exact_strong_duality')
        bimip_method = 'exact_strong_duality';
    elseif strcmpi(ops.mode, 'exact_KKT')
        bimip_method = 'exact_KKT';
    elseif strcmpi(ops.mode, 'quick')
        bimip_method = 'quick';
    else
        warning('PowerBiMIP:CCGSubproblem', ...
            'Unknown mode "%s", using default "quick".', ops.mode);
        bimip_method = 'quick';
    end
    
    % Build BiMIP options
    % Set verbose to 0 to suppress welcome messages and detailed output when called from C&CG subproblem
    % This prevents output clutter during C&CG iterations
    bimip_ops = BiMIPsettings('perspective', 'optimistic', ...
                              'method', bimip_method, ...
                              'solver', ops.solver, ...
                              'verbose', ops.ops_SP.verbose);  % Suppress output when called as subproblem
    
    % Call solve_BiMIP
    try
        [Solution, BiMIP_record] = solve_BiMIP(original_var, ...
            var_x_u, var_z_u, var_x_l, var_z_l, ...
            cons_upper, cons_lower, obj_upper, obj_lower, bimip_ops);
    catch ME
        warning('PowerBiMIP:CCGSubproblem', ...
            'solve_BiMIP failed: %s', ME.message);
        % Return empty structure
        sp_result.u_star = [];
        sp_result.Q_value = [];
        sp_result.x_star = [];
        sp_result.sp_solution = struct();
        sp_result.solution = struct('problem', -1);
        return;
    end
    
    %% Step 6: Extract Solution
    % Extract u* (upper-level variable) and x* (lower-level variable)
    % Solution.var contains the values of original_var (which is a struct with var_u and var_x)
    % We can extract directly from YALMIP variables or from Solution.var
    
    u_star = [];
    x_star = [];
    
    if ~isempty(var_x_u)
        u_star = value(var_x_u);
        u_star = u_star(:);  % Ensure column vector
    end
    if ~isempty(var_x_l)
        x_star = value(var_x_l);
        x_star = x_star(:);  % Ensure column vector
    end
    
    % Extract Q(y*) (SP objective value)
    % Note: Since we converted max-min to min-min by taking negative,
    % solve_BiMIP returns min_u min_x {-d^T x}, which equals -max_u min_x {d^T x}
    % So we need to take negative to get Q(y*) = max_u min_x {d^T x}
    Q_value = [];
    if isfield(Solution, 'obj') && ~isempty(Solution.obj)
        Q_value = -Solution.obj;  % Take negative to convert back
    elseif isfield(BiMIP_record, 'UB') && ~isempty(BiMIP_record.UB)
        Q_value = -BiMIP_record.UB(end);  % Take negative to convert back
    elseif isfield(BiMIP_record, 'obj_val')
        Q_value = -BiMIP_record.obj_val;  % Take negative to convert back
    end
    
    % Extract solution status
    solution_status = struct('problem', 0);
    if isfield(BiMIP_record, 'optimal_solution') && ...
            isstruct(BiMIP_record.optimal_solution) && ...
            isfield(BiMIP_record.optimal_solution, 'solution')
        solution_status = BiMIP_record.optimal_solution.solution;
    end
    
    %% Step 7: Build Output Structure
    sp_result.u_star = u_star;
    sp_result.Q_value = Q_value;
    sp_result.x_star = x_star;
    sp_result.sp_solution = struct('Solution', Solution, 'BiMIP_record', BiMIP_record);
    sp_result.solution = solution_status;
end

