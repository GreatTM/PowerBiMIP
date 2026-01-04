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

    %% Configuration: Convergence Logic Selection
    % =========================================================
    % true  = 使用新逻辑：目标函数Gap < 阈值，且连续两次满足
    % false = 使用旧逻辑：原始变量PrimalDiff < 阈值
    use_obj_gap_convergence = true; 
    % =========================================================

    %% Initialization: Solve Relaxed Problem (High Point Problem)
    model_init = model;
    model_init.constraints = [];
    
    % Upper Level Constraints
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
    
    % Lower Level (Primal) Constraints
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
    bigM = inf; 
    
    % Inequality dual variables: [-bigM, 0]
    dual_ineq = sdpvar(length(model.b_l), 1, 'full');
    
    % Equality dual variables: [-bigM, bigM]
    dual_eq = sdpvar(length(model.f_l), 1, 'full');
    
    % Initialize Dual values
    curr_dual_ineq = zeros(length(model.b_l), 1);
    curr_dual_eq = zeros(length(model.f_l), 1);
    
    %% PADM Parameters
    rho = ops.penalty_rho;
    padm_outer_iter = 0;
    padm_inner_iter = 0;
    max_total_iter = ops.padm_max_iter;
    rho_max = 1e10;
    
    %% Main L1-PADM Loop
    ul_obj = [model.c1', model.c2', model.c3', model.c4'] * ...
             [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];
    
    ll_primal_obj = model.c5' * model.C_l_vars;
    
    % Define Terms for PADM Objective
    rhs_ineq = 0; rhs_eq = 0;
    if ~isempty(dual_ineq)
        rhs_ineq = model.b_l - [model.A_l, model.B_l] * [model.A_l_vars; model.B_l_vars];
    end
    if ~isempty(dual_eq)
        rhs_eq = model.f_l - [model.E_l, model.F_l] * [model.E_l_vars; model.F_l_vars];
    end
    
    % Symbolic definitions
    dual_ineq_term_def = 0; dual_eq_term_def = 0;
    if ~isempty(dual_ineq), dual_ineq_term_def = dual_ineq' * rhs_ineq; end
    if ~isempty(dual_eq), dual_eq_term_def = dual_eq' * rhs_eq; end
    
    padm_obj = ul_obj + rho * (ll_primal_obj - dual_ineq_term_def - dual_eq_term_def);
    
    padm1_objectives = [];
    padm2_objectives = [];
    padm_gaps = [];        
    padm_log_chars = 0;

    while padm_outer_iter < max_total_iter
        padm_outer_iter = padm_outer_iter + 1;
        
        % Inner loop variables
        inner_converged = false;
        consecutive_conv = 0; % Counter for new logic
        
        while ~inner_converged && padm_inner_iter < max_total_iter
            padm_inner_iter = padm_inner_iter + 1;
            
            % --- Step 1: Subproblem 1 (Fix Primal, Optimize Dual) ---
            model.constraints_sp2 = [];
            
            constraint_ineq = 0;
            if ~isempty(dual_ineq)
                constraint_ineq = dual_ineq' * model.C_l;
                model.constraints_sp2 = model.constraints_sp2 + (dual_ineq >= -bigM) + (dual_ineq <= 0);
            end
            constraint_eq = 0;
            if ~isempty(dual_eq)
                constraint_eq = dual_eq' * model.G_l;
                model.constraints_sp2 = model.constraints_sp2 + (dual_eq >= -bigM) + (dual_eq <= bigM);
            end
            model.constraints_sp2 = model.constraints_sp2 + (constraint_ineq + constraint_eq == model.c5');
            
            % Calculate fixed values
            val_term_ineq = 0;
            if ~isempty(dual_ineq)
                val_rhs_ineq = model.b_l - [model.A_l, model.B_l] * [val_A_l_vars; val_B_l_vars];
                val_term_ineq = dual_ineq' * val_rhs_ineq;
            end
            val_term_eq = 0;
            if ~isempty(dual_eq)
                val_rhs_eq = model.f_l - [model.E_l, model.F_l] * [val_E_l_vars; val_F_l_vars];
                val_term_eq = dual_eq' * val_rhs_eq;
            end
            
            obj_sp2 = -(val_term_ineq + val_term_eq);
            
            optimize(model.constraints_sp2, obj_sp2, ops.ops_MP);
            
            padm1_obj = value(padm_obj);
            padm1_objectives(end+1) = padm1_obj;
            
            curr_dual_ineq = value(dual_ineq); curr_dual_ineq(isnan(curr_dual_ineq)) = 0;
            curr_dual_eq   = value(dual_eq);   curr_dual_eq(isnan(curr_dual_eq)) = 0;
            
            % --- Step 2: Subproblem 2 (Fix Dual, Optimize Primal) ---
            model.constraints_sp1 = [];
            
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
            
            term_dual_ineq = 0;
            if ~isempty(curr_dual_ineq)
                term_dual_ineq = curr_dual_ineq' * (- [model.A_l, model.B_l] * [model.A_l_vars; model.B_l_vars]); 
            end
            term_dual_eq = 0;
            if ~isempty(curr_dual_eq)
                term_dual_eq = curr_dual_eq' * (- [model.E_l, model.F_l] * [model.E_l_vars; model.F_l_vars]);
            end
            
            ll_dual_obj_interaction = term_dual_ineq + term_dual_eq;
            obj_sp1 = ul_obj + rho * (ll_primal_obj - ll_dual_obj_interaction);
            
            sol_sp1 = optimize(model.constraints_sp1, obj_sp1, ops.ops_MP);
            
            padm2_obj = value(padm_obj);
            padm2_objectives(end+1) = padm2_obj;
            
            % Update Primal Values
            curr_primal_vec = [value(model.c1_vars(:)); value(model.c2_vars(:)); ...
                               value(model.c3_vars(:)); value(model.c4_vars(:)); ...
                               value(model.c5_vars(:))]; 
            curr_primal_vec(isnan(curr_primal_vec)) = 0;
            
            % Cache variables
            val_A_l_vars = value(model.A_l_vars); val_A_l_vars(isnan(val_A_l_vars)) = 0;
            val_B_l_vars = value(model.B_l_vars); val_B_l_vars(isnan(val_B_l_vars)) = 0;
            val_E_l_vars = value(model.E_l_vars); val_E_l_vars(isnan(val_E_l_vars)) = 0;
            val_F_l_vars = value(model.F_l_vars); val_F_l_vars(isnan(val_F_l_vars)) = 0;
            
            % --- Convergence Calculations ---
            
            % 1. Calculate Primal Difference
            if all(isinf(prev_primal_vec))
                 primal_diff = inf;
            else
                 primal_diff = norm(curr_primal_vec - prev_primal_vec, inf) / max(1, norm(prev_primal_vec, inf));
            end
            prev_primal_vec = curr_primal_vec;
            
            % 2. Calculate Objective Gap
            obj_val_1 = padm1_objectives(end);
            obj_val_2 = padm2_objectives(end);
            
            diff_obj = abs(obj_val_1 - obj_val_2);
            max_obj = max(abs(obj_val_1), abs(obj_val_2));
            
            if max_obj < 1e-12 
                obj_gap = 0; 
            else
                obj_gap = diff_obj / max_obj;
            end
            padm_gaps(end+1) = obj_gap;
            
            % --- Check Convergence Criteria ---
            if use_obj_gap_convergence
                % === Version A: New Logic (Objective Gap, Consecutive) ===
                if obj_gap < ops.padm_tolerance
                    consecutive_conv = consecutive_conv + 1;
                else
                    consecutive_conv = 0; 
                end
                
                if consecutive_conv >= 2
                    inner_converged = true;
                end
            else
                % === Version B: Original Logic (Primal Difference) ===
                if primal_diff <= ops.padm_tolerance
                    inner_converged = true;
                end
            end
            
            % Log Information
            if ops.verbose >= 1
                % [修改] 增加目标函数值的打印精度到 .8e
                msgFmt = 'PADM Inner Iter %d: Rho=%.1e | PrimalDiff=%.1e | ObjGap=%.1e | Obj1=%.8e | Obj2=%.8e\n';
                if ops.verbose <= 2
                    padm_log_chars = padm_log_chars + log_utils('printf_count', msgFmt, ...
                        padm_inner_iter, rho, primal_diff, obj_gap, obj_val_1, obj_val_2);
                else
                    fprintf(msgFmt, padm_inner_iter, rho, primal_diff, obj_gap, obj_val_1, obj_val_2);
                end
            end
        end % End Inner Loop
        
        % --- Outer Loop Convergence Check (Global Feasibility) ---
        val_ll_primal = value(ll_primal_obj);
        
        val_dual_obj = 0;
        if ~isempty(curr_dual_ineq)
            val_dual_obj = val_dual_obj + curr_dual_ineq' * (model.b_l - [model.A_l, model.B_l] * [val_A_l_vars; val_B_l_vars]);
        end
        if ~isempty(curr_dual_eq)
            val_dual_obj = val_dual_obj + curr_dual_eq' * (model.f_l - [model.E_l, model.F_l] * [val_E_l_vars; val_F_l_vars]);
        end
        
        gap_numerator = abs(val_ll_primal - val_dual_obj);
        gap_denominator = abs(val_ll_primal) + 1e-4; 
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
            if ops.verbose >= 1
                msgFmt = 'PADM Converged: Duality Gap satisfied.\n';
                if ops.verbose <= 2
                    padm_log_chars = padm_log_chars + log_utils('printf_count', msgFmt);
                else
                    fprintf('%s', msgFmt);
                end
            end
            break; 
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
    Solution.solution = sol_sp1;
    Solution.padm_inner_iter = padm_inner_iter;
    Solution.padm_outer_iter = padm_outer_iter;
    Solution.padm1_objectives = padm1_objectives;
    Solution.padm2_objectives = padm2_objectives;
    Solution.padm_gap = padm_gaps;
    
    final_ul_obj = value(ul_obj);
    final_penalty = rho * (val_ll_primal - val_dual_obj);
    Solution.obj = final_ul_obj + final_penalty;
    Solution.new_var = [];
    Solution.padm_log_chars = padm_log_chars;
    
end