function Solution = solveBiLPbyPADM2(model, ops)
    %SOLVEBILPBYPADM Solves a BiLP model using Strong Duality and L1-PADM.
    %
    %   Algorithm based on: 
    %   Kleinert, T., & Schmidt, M. (2021). Computing Feasible Points of 
    %   Bilevel Problems with a Penalty Alternating Direction Method. 
    %   INFORMS Journal on Computing.
    
    %% Configuration: Convergence Logic Selection
    use_obj_gap_convergence = true; 
    
    % %% Initialization 1: Solve High Point Relaxation (Primal Init)
    % % Initialize primal variables (x, y) as per standard ADM practice 
    % % to ensure valid inputs for the first split.
    % model_init = model;
    % model_init.constraints = [];
    % 
    % % Upper Level Constraints
    % if ~isempty(model.b_u)
    %     model_init.constraints = model_init.constraints + ...
    %         ([model.A_u, model.B_u, model.C_u, model.D_u] * ...
    %         [model.A_u_vars; model.B_u_vars; model.C_u_vars; model.D_u_vars] <= model.b_u);
    % end
    % if ~isempty(model.f_u)
    %     model_init.constraints = model_init.constraints + ...
    %         ([model.E_u, model.F_u, model.G_u, model.H_u] * ...
    %         [model.E_u_vars; model.F_u_vars; model.G_u_vars; model.H_u_vars] == model.f_u);
    % end
    % 
    % % Lower Level (Primal) Constraints
    % if ~isempty(model.b_l)
    %     model_init.constraints = model_init.constraints + ...
    %         ([model.A_l, model.B_l, model.C_l, model.D_l] * ...
    %         [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= model.b_l);
    % end
    % if ~isempty(model.f_l)
    %     model_init.constraints = model_init.constraints + ...
    %         ([model.E_l, model.F_l, model.G_l, model.H_l] * ...
    %         [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == model.f_l);
    % end
    % 
    % model_init.objective = [model.c1', model.c2', model.c3', model.c4'] * ...
    %     [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];
    % 
    % sol_init = optimize(model_init.constraints, model_init.objective, ops.ops_MP);
    % 
    % if sol_init.problem ~= 0
    %      warning('Relaxed problem failed to solve. Proceeding with zero initialization.');
    % end
    % 
    % % Extract initial Primal Values
    % curr_primal_vec = [value(model.c1_vars(:)); value(model.c2_vars(:)); ...
    %                    value(model.c3_vars(:)); value(model.c4_vars(:)); ...
    %                    value(model.c5_vars(:))]; 
    % curr_primal_vec(isnan(curr_primal_vec)) = 0;
    % prev_primal_vec = curr_primal_vec;
    % 
    % % Cache variables needed for dual step
    % val_A_l_vars = value(model.A_l_vars); val_A_l_vars(isnan(val_A_l_vars)) = 0;
    % val_B_l_vars = value(model.B_l_vars); val_B_l_vars(isnan(val_B_l_vars)) = 0;
    % val_E_l_vars = value(model.E_l_vars); val_E_l_vars(isnan(val_E_l_vars)) = 0;
    % val_F_l_vars = value(model.F_l_vars); val_F_l_vars(isnan(val_F_l_vars)) = 0;
    prev_primal_vec = inf;
    
    %% Initialization 2: Solve Dual Feasibility (Dual Init)
    % "initialize the lower level's dual variable by the 
    % dual feasible point that we obtain by solving (12) with a zero objective function."
    
    % Define temporary dual variables for initialization
    dual_ineq_init = sdpvar(length(model.b_l), 1, 'full');
    dual_eq_init   = sdpvar(length(model.f_l), 1, 'full');
    
    constraints_dual_init = [];
    
    % Stationarity: dual_ineq' * C_l + dual_eq' * G_l == c5'
    % [修改] 增加判空保护，防止变量为空时维度不匹配
    expr_stationarity = 0;
    if ~isempty(dual_ineq_init)
        expr_stationarity = expr_stationarity + dual_ineq_init' * model.C_l;
    end
    if ~isempty(dual_eq_init)
        expr_stationarity = expr_stationarity + dual_eq_init' * model.G_l;
    end
    
    constraints_dual_init = [constraints_dual_init, expr_stationarity == model.c5'];
    
    % Sign constraints (matching the logic in the main loop: dual_ineq <= 0)
    if ~isempty(dual_ineq_init)
        constraints_dual_init = [constraints_dual_init, dual_ineq_init <= 0];
    end
    
    % Solve with zero objective
    sol_dual_init = optimize(constraints_dual_init, 0, ops.ops_MP);
    
    if sol_dual_init.problem == 0
        curr_dual_ineq = value(dual_ineq_init);
        curr_dual_eq   = value(dual_eq_init);
    else
        warning('Dual initialization failed. Fallback to zeros.');
        curr_dual_ineq = zeros(length(model.b_l), 1);
        curr_dual_eq   = zeros(length(model.f_l), 1);
    end
    % Clean NaNs
    curr_dual_ineq(isnan(curr_dual_ineq)) = 0;
    curr_dual_eq(isnan(curr_dual_eq)) = 0;
    
    % Define actual SDN Dual Variables for the main loop
    bigM = inf; 
    dual_ineq = sdpvar(length(model.b_l), 1, 'full');
    dual_eq = sdpvar(length(model.f_l), 1, 'full');
    
    %% PADM Parameters
    rho = ops.penalty_rho;
    padm_outer_iter = 0;
    padm_inner_iter = 0;
    max_total_iter = ops.padm_max_iter;
    rho_max = 1e10;
    
    %% Main L1-PADM Loop
    % Objective function definitions
    ul_obj = [model.c1', model.c2', model.c3', model.c4'] * ...
             [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars];
    ll_primal_obj = model.c5' * model.C_l_vars;
    
    % Helper for PADM objective value calculation (symbolic)
    rhs_ineq = 0; rhs_eq = 0;
    if ~isempty(dual_ineq)
        rhs_ineq = model.b_l - [model.A_l, model.B_l] * [model.A_l_vars; model.B_l_vars];
    end
    if ~isempty(dual_eq)
        rhs_eq = model.f_l - [model.E_l, model.F_l] * [model.E_l_vars; model.F_l_vars];
    end
    
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
        
        inner_converged = false;
        consecutive_conv = 0; 
        
        while ~inner_converged && padm_inner_iter < max_total_iter
            padm_inner_iter = padm_inner_iter + 1;
            
            % =========================================================
            % STEP 1: Subproblem 1 (Fix Dual, Optimize Primal)
            % This corresponds to Eq (11)/(17) in the paper.
            % We use 'curr_dual_ineq' and 'curr_dual_eq' initialized above.
            % =========================================================
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
            
            % Construct Objective with FIXED duals
            term_dual_ineq = 0;
            if ~isempty(curr_dual_ineq)
                % Duals are fixed constants here
                term_dual_ineq = curr_dual_ineq' * (- [model.A_l, model.B_l] * [model.A_l_vars; model.B_l_vars]); 
            end
            term_dual_eq = 0;
            if ~isempty(curr_dual_eq)
                term_dual_eq = curr_dual_eq' * (- [model.E_l, model.F_l] * [model.E_l_vars; model.F_l_vars]);
            end
            
            ll_dual_obj_interaction = term_dual_ineq + term_dual_eq;
            obj_sp1 = ul_obj + rho * (ll_primal_obj - ll_dual_obj_interaction);
            
            % Solve Primal Subproblem
            sol_sp1 = optimize(model.constraints_sp1, obj_sp1, ops.ops_MP);
            
            padm1_obj = value(padm_obj);
            padm1_objectives(end+1) = padm1_obj;
            
            % Update Cached Primal Values for Step 2
            curr_primal_vec = [value(model.c1_vars(:)); value(model.c2_vars(:)); ...
                               value(model.c3_vars(:)); value(model.c4_vars(:)); ...
                               value(model.c5_vars(:))]; 
            curr_primal_vec(isnan(curr_primal_vec)) = 0;
            
            val_A_l_vars = value(model.A_l_vars); val_A_l_vars(isnan(val_A_l_vars)) = 0;
            val_B_l_vars = value(model.B_l_vars); val_B_l_vars(isnan(val_B_l_vars)) = 0;
            val_E_l_vars = value(model.E_l_vars); val_E_l_vars(isnan(val_E_l_vars)) = 0;
            val_F_l_vars = value(model.F_l_vars); val_F_l_vars(isnan(val_F_l_vars)) = 0;
            
            % =========================================================
            % STEP 2: Subproblem 2 (Fix Primal, Optimize Dual)
            % This corresponds to Eq (12)/(18) in the paper.
            % We use updated 'val_A_l_vars' etc. from Step 1.
            % =========================================================
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
            % Stationarity constraint
            model.constraints_sp2 = model.constraints_sp2 + (constraint_ineq + constraint_eq == model.c5');
            
            % Calculate fixed primal terms
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
            
            % Note: rho does not appear in Eq (12) but the code scales objective implicitly.
            % PADM minimizes (Primal - Dual). With Primal fixed, we maximize Dual, 
            % which equals minimizing -Dual.
            obj_sp2 = -(val_term_ineq + val_term_eq);
            
            % Solve Dual Subproblem
            optimize(model.constraints_sp2, obj_sp2, ops.ops_MP);
            
            padm2_obj = value(padm_obj);
            padm2_objectives(end+1) = padm2_obj;
            
            % Update Cached Dual Values for next Step 1
            curr_dual_ineq = value(dual_ineq); curr_dual_ineq(isnan(curr_dual_ineq)) = 0;
            curr_dual_eq   = value(dual_eq);   curr_dual_eq(isnan(curr_dual_eq)) = 0;
            
            % --- Convergence Calculations ---
            % 1. Calculate Primal Difference
            if all(isinf(prev_primal_vec))
                 primal_diff = inf;
            else
                 primal_diff = norm(curr_primal_vec - prev_primal_vec, inf) / max(1, norm(prev_primal_vec, inf));
            end
            prev_primal_vec = curr_primal_vec;
            
            % 2. Calculate Objective Gap
            % Compare objective after Step 1 and after Step 2
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
                if obj_gap < ops.padm_tolerance
                    consecutive_conv = consecutive_conv + 1;
                else
                    consecutive_conv = 0; 
                end
                
                if consecutive_conv >= 2
                    inner_converged = true;
                end
            else
                if primal_diff <= ops.padm_tolerance
                    inner_converged = true;
                end
            end
            
            % Log Information
            if ops.verbose >= 1
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