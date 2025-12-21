function Solution = solveBiLPbyPADM(model, ops)
%SOLVEBILPBYPADM Solves a BiLP model using Strong Duality and L1-PADM.
%
%   Description:
%       This function solves a BiLP problem by applying the L1-PADM algorithm
%       to decompose the bilinear terms arising from the Strong Duality
%       condition.
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

%   penalty problem reformulation:
%   min c1'x_u + c2'z_u + c3'x_l + c4'z_l + rho * (primal obj - dual obj)
%   s.t. A_u*x_u + B_u*z_u + C_u*x_l + D_u*z_l <= b_u
%        E_u*x_u + F_u*z_u + G_u*x_l + H_u*z_l = f_u
%   primal feasibility:
%        A_l*x_u + B_l*z_u + C_l*x_l <= b_l
%        E_l*x_u + F_l*z_u + G_l*x_l = f_l
%   dual feasibility:
%        dual_ineq <= 0
%        dual_ineq' * C_l + dual_eq' * G_l == c5'
%   where x_u, z_u are the variables of the upper level,
%         x_l are the variables of the lower level,
%         dual_ineq, dual_eq are the dual variables of the lower level inequality and equality constraints,
%         rho is the penalty parameter,

%   L_1 PADM subproblem1 (dual vars fixed):
%   min c1'x_u + c2'z_u + c3'x_l + c4'z_l + rho * (c5' * x_l - ((- A_l*x_u - B_l*z_u)' * dual_ineq_fixed + (- E_l*x_u - F_l*z_u)' * dual_eq_fixed))
%   s.t. A_u*x_u + B_u*z_u + C_u*x_l + D_u*z_l <= b_u
%        E_u*x_u + F_u*z_u + G_u*x_l + H_u*z_l = f_u
%   primal feasibility:
%        A_l*x_u + B_l*z_u + C_l*x_l <= b_l
%        E_l*x_u + F_l*z_u + G_l*x_l = f_l

%   L_1 PADM subproblem2 (primal vars fixed):
%   min -((b_l - A_l*x_u_fixed - B_l*z_u_fixed)' * dual_ineq + (f_l - E_l*x_u_fixed - F_l*z_u_fixed)' * dual_eq)
%   s.t. dual_ineq <= 0
%        dual_ineq' * C_l + dual_eq' * G_l == c5'

    %% Initialization: Solve Relaxed Problem (High Point Problem)
    % Solve the High Point Problem (UL + LL constraints only) to get initial primal values.
    model_init = model;
    model_init.constraints = [];
    
    % Upper Level
    if ~isempty(model.b_u)
        model_init.constraints = model_init.constraints + ...
            ([model.A_u, model.B_u, model.C_u, model.D_u] * ...
            [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= model.b_u);
    end
    if ~isempty(model.f_u)
        model_init.constraints = model_init.constraints + ...
            ([model.E_u, model.F_u, model.G_u, model.H_u] * ...
            [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == model.f_u);
    end
    
    % Lower Level (Primal)
    if ~isempty(model.b_l)
        model_init.constraints = model_init.constraints + ...
            ([model.A_l, model.B_l, model.C_l, model.D_l] * ...
            [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= model.b_l);
    end
    if ~isempty(model.f_l)
        model_init.constraints = model_init.constraints + ...
            ([model.E_l, model.F_l, model.G_l, model.H_l] * ...
            [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == model.f_l);
    end
    
    model_init.objective = [model.c1', model.c2', model.c3', model.c4'] * ...
        [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];
        
    sol_init = optimize(model_init.constraints, model_init.objective, ops.ops_MP);
    
    if sol_init.problem ~= 0
         warning('Relaxed problem failed to solve. Proceeding with zero initialization.');
    end

    % Extract initial Primal Values
    % Initialize prev primal for convergence check
    curr_primal_vec = [value(model.c1_vars(:)); value(model.c2_vars(:)); ...
                       value(model.c3_vars(:)); value(model.c4_vars(:)); ...
                       value(model.c5_vars(:))]; 
    curr_primal_vec(isnan(curr_primal_vec)) = 0;
    prev_primal_vec = curr_primal_vec;
    
    % Extract variables needed for dual objective calculation
    val_A_l_vars = value(model.A_l_vars); val_A_l_vars(isnan(val_A_l_vars)) = 0;
    val_B_l_vars = value(model.B_l_vars); val_B_l_vars(isnan(val_B_l_vars)) = 0;
    val_E_l_vars = value(model.E_l_vars); val_E_l_vars(isnan(val_E_l_vars)) = 0;
    val_F_l_vars = value(model.F_l_vars); val_F_l_vars(isnan(val_F_l_vars)) = 0;
    
    % Define Dual Variables
    bigM = 1e6;  % Big-M constant for dual variable bounds
    
    % Inequality dual variables: [-bigM, 0]
    dual_ineq = sdpvar(length(model.b_l), 1, 'full');
    
    % Equality dual variables: [-bigM, bigM]
    dual_eq = sdpvar(length(model.f_l), 1, 'full');
    
    % Initialize Dual values (will be computed in first SP2)
    curr_dual_ineq = zeros(length(model.b_l), 1);
    curr_dual_eq = zeros(length(model.f_l), 1);
    
    %% PADM Parameters
    rho = ops.penalty_rho;
    padm_outer_iter = 0;
    padm_inner_iter = 0;
    max_total_iter = ops.padm_max_iter;
    rho_max = 1e10;
    
    %% Main L1-PADM Loop
    % Outer loop manages Rho updates
    padm_log_chars = 0;
    while padm_outer_iter < max_total_iter
        padm_outer_iter = padm_outer_iter + 1;
        % Inner loop manages ADM iterations (Partial Minimum)
        inner_converged = false;
        
        while ~inner_converged && padm_inner_iter < max_total_iter
            padm_inner_iter = padm_inner_iter + 1;
            
            % --- Step 1: Subproblem 1 (Fix Primal, Optimize Dual) ---
            % Initialize Constraints
            model.constraints_sp2 = [];
            
            % Dual Feasibility (Independent of Primal)
            constraint_ineq = 0;
            if ~isempty(dual_ineq)
                constraint_ineq = dual_ineq' * model.C_l;
                % Dual inequality bounds: [-bigM, 0]
                model.constraints_sp2 = model.constraints_sp2 + ...
                    (dual_ineq >= -bigM);
                model.constraints_sp2 = model.constraints_sp2 + ...
                    (dual_ineq <= 0);
            end
            constraint_eq = 0;
            if ~isempty(dual_eq)
                constraint_eq = dual_eq' * model.G_l;
                % Dual equality bounds: [-bigM, bigM]
                model.constraints_sp2 = model.constraints_sp2 + ...
                    (dual_eq >= -bigM);
                model.constraints_sp2 = model.constraints_sp2 + ...
                    (dual_eq <= bigM);
            end
            model.constraints_sp2 = model.constraints_sp2 + (constraint_ineq + constraint_eq == model.c5');
            
            % Objective SP2: min -DualObj (Maximize DualObj)
            % DualObj = dual_ineq' * (b_l - A_l*x_u_fixed - B_l*z_u_fixed) + ...
            % Note: rho and c5'*x_l are removed as they are constant or scaling factors.
            
            % Calculate fixed values based on CURRENT primal variables
            val_term_ineq = 0;
            if ~isempty(dual_ineq)
                % Value of (b_l - A_l*x - B_l*z)
                val_rhs_ineq = model.b_l - [model.A_l, model.B_l] * [val_A_l_vars; val_B_l_vars];
                val_term_ineq = dual_ineq' * val_rhs_ineq;
            end
            
            val_term_eq = 0;
            if ~isempty(dual_eq)
                val_rhs_eq = model.f_l - [model.E_l, model.F_l] * [val_E_l_vars; val_F_l_vars];
                val_term_eq = dual_eq' * val_rhs_eq;
            end
            
            obj_sp2 = -(val_term_ineq + val_term_eq);
            
            sol_sp2 = optimize(model.constraints_sp2, obj_sp2, ops.ops_MP);
            
            curr_dual_ineq = value(dual_ineq); curr_dual_ineq(isnan(curr_dual_ineq)) = 0;
            curr_dual_eq   = value(dual_eq);   curr_dual_eq(isnan(curr_dual_eq)) = 0;
            
            % --- Step 2: Subproblem 2 (Fix Dual, Optimize Primal) ---
            % Primal Constraints
            model.constraints_sp1 = [];
            
            % 1. Upper Level Constraints
            if ~isempty(model.b_u)
                model.constraints_sp1 = model.constraints_sp1 + ...
                    ([model.A_u, model.B_u, model.C_u, model.D_u] * ...
                    [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= model.b_u);
            end
            if ~isempty(model.f_u)
                model.constraints_sp1 = model.constraints_sp1 + ...
                    ([model.E_u, model.F_u, model.G_u, model.H_u] * ...
                    [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == model.f_u);
            end
            
            % 2. Lower Level Primal Feasibility
            if ~isempty(model.b_l)
                model.constraints_sp1 = model.constraints_sp1 + ...
                    ([model.A_l, model.B_l, model.C_l] * ...
                    [model.A_l_vars; model.B_l_vars; model.C_l_vars] <= model.b_l);
            end
            if ~isempty(model.f_l)
                model.constraints_sp1 = model.constraints_sp1 + ...
                    ([model.E_l, model.F_l, model.G_l] * ...
                    [model.E_l_vars; model.F_l_vars; model.G_l_vars] == model.f_l);
            end
            
            % Objective SP1: 
            % UL_Obj + rho * (LL_Primal_Obj - LL_Dual_Obj_Interaction)
            % LL_Dual_Obj_Interaction = dual_ineq' * (- A_l*x_u - B_l*z_u) + dual_eq' * (- E_l*x_u - F_l*z_u)
            % Constant terms in DualObj are removed.
            
            ul_obj = [model.c1', model.c2', model.c3', model.c4'] * ...
                     [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];
            
            ll_primal_obj = model.c5' * model.C_l_vars; 
            
            term_dual_ineq = 0;
            if ~isempty(curr_dual_ineq)
                % Expression: (- A_l*x_u - B_l*z_u)' * dual_ineq
                % [A_l, B_l] * [model.A_l_vars; model.B_l_vars]
                term_dual_ineq = curr_dual_ineq' * (- [model.A_l, model.B_l] * [model.A_l_vars; model.B_l_vars]); 
            end
            
            term_dual_eq = 0;
            if ~isempty(curr_dual_eq)
                term_dual_eq = curr_dual_eq' * (- [model.E_l, model.F_l] * [model.E_l_vars; model.F_l_vars]);
            end
            
            ll_dual_obj_interaction = term_dual_ineq + term_dual_eq;
            
            obj_sp1 = ul_obj + rho * (ll_primal_obj - ll_dual_obj_interaction);
            
            sol_sp1 = optimize(model.constraints_sp1, obj_sp1, ops.ops_MP);
            
            % Update Primal Values
            curr_primal_vars = myFun_GetValue(model.var); % Get all primal values struct
            % Vectorize for convergence check
            % Concatenate values of all relevant primal variables
            % Order: c1_vars, c2_vars, c3_vars, c4_vars, c5_vars
            curr_primal_vec = [value(model.c1_vars(:)); value(model.c2_vars(:)); ...
                               value(model.c3_vars(:)); value(model.c4_vars(:)); ...
                               value(model.c5_vars(:))]; 
            curr_primal_vec(isnan(curr_primal_vec)) = 0;
            
            % Cache variables for next SP2 iteration
            val_A_l_vars = value(model.A_l_vars); val_A_l_vars(isnan(val_A_l_vars)) = 0;
            val_B_l_vars = value(model.B_l_vars); val_B_l_vars(isnan(val_B_l_vars)) = 0;
            val_E_l_vars = value(model.E_l_vars); val_E_l_vars(isnan(val_E_l_vars)) = 0;
            val_F_l_vars = value(model.F_l_vars); val_F_l_vars(isnan(val_F_l_vars)) = 0;
            
            % Check Inner Convergence (b. Primal Stability)
            if all(isinf(prev_primal_vec))
                 primal_diff = inf;
            else
                 % Relative Error: ||x_new - x_old|| / max(1, ||x_old||)
                 primal_diff = norm(curr_primal_vec - prev_primal_vec, inf) / max(1, norm(prev_primal_vec, inf));
            end
            prev_primal_vec = curr_primal_vec;
            
            if primal_diff <= ops.padm_tolerance
                inner_converged = true;
            end
            if ops.verbose >= 1
                msgFmt = 'PADM Inner Iter %d: Rho=%.1e | PrimalDiff=%.1e\n';
                if ops.verbose <= 2
                    padm_log_chars = padm_log_chars + log_utils('printf_count', msgFmt, ...
                        padm_inner_iter, rho, primal_diff);
                else
                    fprintf(msgFmt, padm_inner_iter, rho, primal_diff);
                end
            end
        end % End Inner Loop
        
        % --- Convergence Check a: Global Feasibility (Strong Duality Gap) ---
        % Calculate LL Primal Obj value
        val_ll_primal = value(ll_primal_obj);
        
        % Calculate LL Dual Obj value
        val_dual_obj = 0;
        if ~isempty(curr_dual_ineq)
            val_dual_obj = val_dual_obj + curr_dual_ineq' * (model.b_l - [model.A_l, model.B_l] * [val_A_l_vars; val_B_l_vars]);
        end
        if ~isempty(curr_dual_eq)
            val_dual_obj = val_dual_obj + curr_dual_eq' * (model.f_l - [model.E_l, model.F_l] * [val_E_l_vars; val_F_l_vars]);
        end
        
        gap_numerator = abs(val_ll_primal - val_dual_obj);
        gap_denominator = abs(val_ll_primal) + 1e-4; % Prevent division by zero
        duality_gap = gap_numerator / gap_denominator;
        
        if ops.verbose >= 1
            msgFmt = 'PADM Outer Iter %d: Rho=%.1e | Gap=%.1e\n';
            if ops.verbose <= 2
                padm_log_chars = padm_log_chars + log_utils('printf_count', msgFmt, ...
                    padm_outer_iter, rho, duality_gap);
            else
                fprintf(msgFmt, padm_outer_iter, rho, duality_gap);
            end
        end
        
        if duality_gap <= ops.penalty_term_gap
            % Success: Global Convergence
            if ops.verbose >= 1
                msgFmt = 'PADM Converged: Duality Gap satisfied.\n';
                if ops.verbose <= 2
                    padm_log_chars = padm_log_chars + log_utils('printf_count', msgFmt);
                else
                    fprintf('%s', msgFmt);
                end
            end
            break; % Break inner loop, outer loop will also break
        else
            rho = min(rho * 2, rho_max);
            if ops.verbose >= 1
                msgFmt = 'Inner Loop Stabilized. Increasing Rho to %.1e.\n';
                if ops.verbose <= 2
                    padm_log_chars = padm_log_chars + log_utils('printf_count', msgFmt, rho);
                else
                    fprintf(msgFmt, rho);
                end
            end
        end
        
        if rho >= rho_max
             warning('PADM reached max rho without full convergence.');
             break;
        end
        
    end % End Outer Loop
    
    %% Output
    Solution = myFun_GetValue(model);
    Solution.solution = sol_sp1; % Use last primal solution
    Solution.padm_inner_iter = padm_inner_iter;
    Solution.padm_outer_iter = padm_outer_iter;
    Solution.duality_gap = duality_gap;

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
    Solution.c5_vars = value(model.c5_vars);
    Solution.c6_vars = value(model.c6_vars);
    Solution.C_l_vars = value(model.C_l_vars);
    Solution.D_l_vars = value(model.D_l_vars);
    Solution.G_l_vars = value(model.G_l_vars);
    Solution.H_l_vars = value(model.H_l_vars);

    Solution.dual_ineq = value(dual_ineq);
    Solution.dual_eq = value(dual_eq);
    
    % Final Objective: c1'x_u + c2'z_u + c3'x_l + c4'z_l + rho * (primal obj - dual obj)
    % Calculate explicitly to match formula
    final_ul_obj = value(ul_obj);
    final_penalty = rho * (val_ll_primal - val_dual_obj);
    Solution.obj = final_ul_obj + final_penalty;
    Solution.new_var = [];
    Solution.padm_log_chars = padm_log_chars;
end
