function mp_result = CCG_master_problem(model, ops, iteration_record)
%CCG_MASTER_PROBLEM Solves the master problem for the C&CG algorithm (TRO-LP with RCR).
%
%   Description:
%       This function builds and solves the master problem (MP) of the
%       Column-and-Constraint Generation (C&CG) algorithm for two-stage robust
%       optimization with linear programming recourse (TRO-LP), assuming
%       relatively complete response (RCR).
%
%       - In the first iteration, it builds a base model with only first-stage
%         constraints, introducing an auxiliary variable eta and objective
%         function c^T y + eta.
%       - In subsequent iterations, it incrementally adds cuts for each
%         identified worst-case scenario u^l, including objective constraints
%         (eta >= d^T x^l) and structural constraints (G x^l >= h - E y - M u^l).
%
%   Inputs:
%       model            - struct: The standardized robust model structure
%                          extracted by extract_robust_coeffs (containing
%                          first-stage/second-stage coefficients, uncertainty set,
%                          variables, statistics).
%       ops              - struct: A struct containing solver options (from
%                          RobustCCGsettings), including ops_MP, verbose, solver, etc.
%       iteration_record - struct: A struct containing the history of the
%                          C&CG algorithm's progress (iteration_num,
%                          worst_case_u_history, scenario_set, etc.).
%
%   Output:
%       mp_result - struct: A struct containing the solution of the master problem:
%                   - y_star: First-stage optimal decision variables y* (vector)
%                   - eta_star: Auxiliary variable eta* (scalar)
%                   - objective: MP objective value c^T y* + eta*
%                   - first_stage_obj: First-stage objective value c^T y* (for UB calculation)
%                   - mp_solution: Complete MP solution struct (with variable mapping)
%                   - solution: YALMIP solution status (.problem field, 0 means success)

    if iteration_record.iteration_num == 1
        %% First Iteration: Build Base Model
        
        %% Build First-Stage Constraints
        constraints = [];
        
        % First-stage inequality constraints: A1_yc * y_cont + A1_yi * y_int <= b1
        if isempty(model.b1)
            constraints = constraints + [];
        else
            constraints = constraints + ...
                ([model.A1_yc, model.A1_yi] * ...
                [model.A1_yc_vars; model.A1_yi_vars] <= ...
                model.b1);
        end
        
        % First-stage equality constraints: E1_yc * y_cont + E1_yi * y_int == f1
        if isempty(model.f1)
            constraints = constraints + [];
        else
            constraints = constraints + ...
                ([model.E1_yc, model.E1_yi] * ...
                [model.E1_yc_vars; model.E1_yi_vars] == ...
                model.f1);
        end
        
        %% Check if initial scenario u_init is provided
        u_init = iteration_record.u_init;
        
        if ~isempty(u_init)
            %% Case 1: u_init is provided - Add initial scenario with second-stage variables
            
            %% Define New Variables for Initial Scenario
            % Introduce auxiliary variable eta
            model.eta = sdpvar(1, 1,'full');
            
            model.new_var(1).var_x_cont = sdpvar(size(model.var_x_cont,1),size(model.var_x_cont,2),'full');
            model.new_var(1).var_x_int = binvar(size(model.var_x_int,1),size(model.var_x_int,2),'full');
            model.new_var(1).c2_xc_vars = model.new_var(1).var_x_cont(model.relative_pos.c2_xc_vars);
            model.new_var(1).c2_xi_vars =  model.new_var(1).var_x_int(model.relative_pos.c2_xi_vars);
            model.new_var(1).A2_xc_vars =  model.new_var(1).var_x_cont(model.relative_pos.A2_xc_vars);
            model.new_var(1).A2_xi_vars =  model.new_var(1).var_x_int(model.relative_pos.A2_xi_vars);
            model.new_var(1).E2_xc_vars =  model.new_var(1).var_x_cont(model.relative_pos.E2_xc_vars);
            model.new_var(1).E2_xi_vars =  model.new_var(1).var_x_int(model.relative_pos.E2_xi_vars);
            
            %% Add Objective Constraint: eta >= d^T x^0
            obj_constraint = [model.c2_xc', model.c2_xi'] * ...
                [model.new_var(1).c2_xc_vars; model.new_var(1).c2_xi_vars];
            constraints = constraints + (model.eta >= obj_constraint);
            
            %% Add Structural Constraints: G x^0 >= h - E y - M u_init
            % Inequality constraints: A2_xc * x_0_cont + A2_xi * x_0_int 
            %                       + A2_yc * y_cont + A2_yi * y_int     <= 
            %                         b2  - A2_u * u_init
            if isempty(model.b2)
                constraints = constraints + [];
            else
                % Compute RHS: b2 - A2_u * u_init
                rhs_ineq = model.b2;
                if ~isempty(model.A2_u) && ~isempty(model.A2_u_vars_init)
                    if length(model.A2_u_vars_init) == size(model.A2_u, 2)
                        rhs_ineq = rhs_ineq - model.A2_u * model.A2_u_vars_init;
                    else
                        error('PowerBiMIP:CCGMaster', ...
                            'Dimension mismatch in u_init for A2_u. Using direct multiplication.');
                    end
                end
                
                % Build constraint: A2_xc * x_0_cont + A2_xi * x_0_int + 
                %                   A2_yc * y_cont + A2_yi * y_int <= rhs_ineq
                constraints = constraints + ...
                    ([model.A2_xc, model.A2_xi, model.A2_yc, model.A2_yi] * ...
                    [model.new_var(1).A2_xc_vars; model.new_var(1).A2_xi_vars; model.A2_yc_vars; model.A2_yi_vars] <= ...
                    rhs_ineq);
            end
            
            % Equality constraints: E2_xc * x_0_cont + E2_xi * x_0_int == 
            %                     f2 - E2_yc * y_cont - E2_yi * y_int - E2_u * u_init
            if isempty(model.f2)
                constraints = constraints + [];
            else
                % Compute RHS: f2 - E2_u * u_init
                rhs_eq = model.f2;
                if ~isempty(model.E2_u) && ~isempty(model.E2_u_vars_init)
                    if length(model.E2_u_vars_init) == size(model.E2_u, 2)
                        rhs_eq = rhs_eq - model.E2_u * model.E2_u_vars_init;
                    else
                        error('PowerBiMIP:CCGMaster', ...
                            'Dimension mismatch in u_init for E2_u. Using direct multiplication.');
                    end
                end
                
                % Build constraint: E2_xc * x_0_cont + E2_xi * x_0_int + 
                %                   E2_yc * y_cont + E2_yi * y_int == rhs_eq
                constraints = constraints + ...
                    ([model.E2_xc, model.E2_xi, model.E2_yc, model.E2_yi] * ...
                    [model.new_var(1).E2_xc_vars; model.new_var(1).E2_xi_vars; model.E2_yc_vars; model.E2_yi_vars] == ...
                    rhs_eq);
            end
            
            %% Build Objective Function
            % First-stage objective: c1_yc^T * y_cont + c1_yi^T * y_int
            objective_first_stage = [model.c1_yc', model.c1_yi'] * ...
                [model.c1_yc_vars; model.c1_yi_vars];
            
            % Total objective: min c^T y + eta
            objective = objective_first_stage + model.eta;
            
        else
            %% Case 2: u_init is empty - No eta to avoid unbounded problem
            
            %% Build Objective Function (only first-stage, no eta)
            objective_first_stage = [model.c1_yc', model.c1_yi'] * ...
                [model.c1_yc_vars; model.c1_yi_vars];
            
            % Total objective: min c^T y (no eta)
            objective = objective_first_stage;
            % No eta variable needed
        end
        
        %% Solve
        solution = optimize(constraints, objective, ops.ops_MP);
        % solution = optimize(constraints, 0, ops.ops_MP);

        %% Extract Solution
        % Extract all variable values using myFun_GetValue
        Solution_MP = myFun_GetValue(model);
        
        % Extract y* values as a struct containing all y-related variable solutions
        y_star = struct();
        y_star_cont = Solution_MP.var_y_cont;
        y_star_int = Solution_MP.var_y_int;
        
        % Store y-related variable solutions for direct use in subproblem
        y_star.A2_yc_vars = Solution_MP.A2_yc_vars;
        y_star.A2_yi_vars = Solution_MP.A2_yi_vars;
        y_star.E2_yc_vars = Solution_MP.E2_yc_vars;
        y_star.E2_yi_vars = Solution_MP.E2_yi_vars;
        
        % Also store combined y* vector for backward compatibility
        y_star.combined = [y_star_cont(:); y_star_int(:)];
        
        % Extract eta* (if exists)
        if isfield(Solution_MP, 'eta')
            eta_star = Solution_MP.eta;
        else
            eta_star = [];
        end
        
        % Extract objective values
        mp_objective = value(objective);
        first_stage_obj = value(objective_first_stage);
        
        %% Build Output Structure
        mp_result.y_star = y_star;
        mp_result.eta_star = eta_star;
        mp_result.objective = mp_objective;
        mp_result.first_stage_obj = first_stage_obj;
        mp_result.solution = solution;
        
        % Build mp_solution for variable mapping
        mp_solution.var = struct();
        mp_solution.var.y_cont = Solution_MP.var_y_cont;
        mp_solution.var.y_int = Solution_MP.var_y_int;
        if isfield(Solution_MP, 'eta')
            mp_solution.var.eta = Solution_MP.eta;
        end
        mp_solution.objective = mp_objective;
        mp_solution.solution = solution;
        mp_result.mp_solution = mp_solution;
    else
        %% Subsequent Iterations: Add Cuts for Each Identified Scenario
        
        %% Reuse First-Stage Constraints and Auxiliary Variable
        constraints = [];
        
        % First-stage inequality constraints
        if isempty(model.b1)
            constraints = constraints + [];
        else
            constraints = constraints + ...
                ([model.A1_yc, model.A1_yi] * ...
                [model.A1_yc_vars; model.A1_yi_vars] <= ...
                model.b1);
        end
        
        % First-stage equality constraints
        if isempty(model.f1)
            constraints = constraints + [];
        else
            constraints = constraints + ...
                ([model.E1_yc, model.E1_yi] * ...
                [model.E1_yc_vars; model.E1_yi_vars] == ...
                model.f1);
        end
        
        %% Auxiliary Variable eta
        model.eta = sdpvar(1, 1,'full');
        
        %% Define New Variables for Each Identified Scenario
        num_scenarios = iteration_record.iteration_num - 1;
        
        % Determine starting index: if u_init exists, start from 2 (since new_var(1) is for u_init)
        if isfield(iteration_record, 'u_init') && ~isempty(iteration_record.u_init)
            start_idx = 2;  % Skip index 1, which is reserved for u_init
        else
            start_idx = 1;  % No u_init, start from 1
        end
        
        for l = 1:num_scenarios
            % Map l to actual index in new_var
            % If u_init exists: var_idx = l + 1 (l=1 -> var_idx=2, l=2 -> var_idx=3, ...)
            % If u_init doesn't exist: var_idx = l (l=1 -> var_idx=1, l=2 -> var_idx=2, ...)
            var_idx = start_idx + l - 1;
            
            % Get worst-case scenario u^l (as numerical values)
            if isfield(iteration_record, 'worst_case_u_history') && ...
                    length(iteration_record.worst_case_u_history) >= var_idx && ...
                    ~isempty(iteration_record.worst_case_u_history{var_idx})
                u_l = iteration_record.worst_case_u_history{var_idx};
            elseif isfield(iteration_record, 'scenario_set') && ...
                    length(iteration_record.scenario_set) >= l && ...
                    ~isempty(iteration_record.scenario_set{l})
                u_l = iteration_record.scenario_set{l};
            else
                warning('PowerBiMIP:CCGMaster', ...
                    'Scenario u^%d not found in iteration_record (index %d). Skipping cut.', l, var_idx);
                continue;
            end
            
            % Ensure u_l is a column vector
            if size(u_l, 2) > size(u_l, 1)
                u_l = u_l';
            end

            %% Copy Second-Stage Variables x^l
            % Create new variables x^l with the same dimensions as original x
            model.new_var(var_idx).var_x_cont = sdpvar(size(model.var_x_cont,1),size(model.var_x_cont,2), 'full');
            model.new_var(var_idx).var_x_int = binvar(size(model.var_x_int,1),size(model.var_x_int,2), 'full');

            model.new_var(var_idx).A2_xc_vars =  model.new_var(var_idx).var_x_cont(model.relative_pos.A2_xc_vars);
            model.new_var(var_idx).A2_xi_vars =  model.new_var(var_idx).var_x_int(model.relative_pos.A2_xi_vars);
            model.new_var(var_idx).E2_xc_vars =  model.new_var(var_idx).var_x_cont(model.relative_pos.E2_xc_vars);
            model.new_var(var_idx).E2_xi_vars =  model.new_var(var_idx).var_x_int(model.relative_pos.E2_xi_vars);
            model.new_var(var_idx).c2_xc_vars =  model.new_var(var_idx).var_x_cont(model.relative_pos.c2_xc_vars);
            model.new_var(var_idx).c2_xi_vars =  model.new_var(var_idx).var_x_int(model.relative_pos.c2_xi_vars);
            % model.new_var(var_idx).c2_xi_vars = 

            %% Add Objective Constraint: eta >= d^T x^l
            obj_constraint = [model.c2_xc', model.c2_xi'] * ...
                [model.new_var(var_idx).c2_xc_vars(:); model.new_var(var_idx).c2_xi_vars(:)];
            constraints = constraints + (model.eta >= obj_constraint);
            
            %% Add Structural Constraints: G x^l >= h - E y - M u^l
            % Note: u^l is numerical, so M * u^l becomes a numerical RHS term
            
            % Inequality constraints: A2_xc * x_l_cont + A2_xi * x_l_int <= 
            %                         b2 - A2_yc * y_cont - A2_yi * y_int - A2_u * u_l
            if isempty(model.b2)
                constraints = constraints + [];
            else
                % Compute RHS: b2 - A2_u * u_l (u^l is numerical)
                rhs_ineq = model.b2;
                if ~isempty(model.A2_u) && ~isempty(u_l)
                    % Map u_l to the correct indices for A2_u
                    % Need to map the full u_l to the specific variables used in A2_u
                    % The indices are stored in model.relative_pos.A2_u_vars
                    if isfield(model, 'relative_pos') && isfield(model.relative_pos, 'A2_u_vars') ...
                            && ~isempty(model.relative_pos.A2_u_vars)
                        % Extract the relevant part of u_l
                        u_l_A2 = u_l(model.relative_pos.A2_u_vars);
                        rhs_ineq = rhs_ineq - model.A2_u * u_l_A2;
                    else
                        % Fallback if relative_pos is not available (should not happen if extract_robust_coeffs is correct)
                        if length(u_l) == size(model.A2_u, 2)
                            rhs_ineq = rhs_ineq - model.A2_u * u_l;
                        else
                            error('PowerBiMIP:CCGMaster', ...
                                'Dimension mismatch in u^%d for A2_u. relative_pos missing or invalid.', l);
                        end
                    end
                end
                
                % Build constraint: A2_xc * x_l_cont + A2_xi * x_l_int + 
                %                   A2_yc * y_cont + A2_yi * y_int <= rhs_ineq
                constraints = constraints + ...
                    ([model.A2_xc, model.A2_xi, model.A2_yc, model.A2_yi] * ...
                    [model.new_var(var_idx).A2_xc_vars(:); model.new_var(var_idx).A2_xi_vars(:); model.A2_yc_vars; model.A2_yi_vars] <= ...
                    rhs_ineq);
            end
            
            % Equality constraints: E2_xc * x_l_cont + E2_xi * x_l_int == 
            %                     f2 - E2_yc * y_cont - E2_yi * y_int - E2_u * u_l
            if isempty(model.f2)
                constraints = constraints + [];
            else
                % Compute RHS: f2 - E2_u * u_l
                rhs_eq = model.f2;
                if ~isempty(model.E2_u) && ~isempty(u_l)
                    % Map u_l to the correct indices for E2_u
                    if isfield(model, 'relative_pos') && isfield(model.relative_pos, 'E2_u_vars') ...
                            && ~isempty(model.relative_pos.E2_u_vars)
                        % Extract the relevant part of u_l
                        u_l_E2 = u_l(model.relative_pos.E2_u_vars);
                        rhs_eq = rhs_eq - model.E2_u * u_l_E2;
                    else
                        if length(u_l) == size(model.E2_u, 2)
                            rhs_eq = rhs_eq - model.E2_u * u_l;
                        else
                            error('PowerBiMIP:CCGMaster', ...
                                'Dimension mismatch in u^%d for E2_u. relative_pos missing or invalid.', l);
                        end
                    end
                end
                
                % Build constraint: E2_xc * x_l_cont + E2_xi * x_l_int + 
                %                   E2_yc * y_cont + E2_yi * y_int == rhs_eq
                constraints = constraints + ...
                    ([model.E2_xc, model.E2_xi, model.E2_yc, model.E2_yi] * ...
                    [model.new_var(var_idx).E2_xc_vars(:); model.new_var(var_idx).E2_xi_vars(:); model.E2_yc_vars; model.E2_yi_vars] == ...
                    rhs_eq);
            end
        end
        
        %% Build Objective Function (same as first iteration)
        objective_first_stage = [model.c1_yc', model.c1_yi'] * ...
            [model.c1_yc_vars; model.c1_yi_vars];
        objective = objective_first_stage + model.eta;
        
        %% Solve
        solution = optimize(constraints, objective, ops.ops_MP);
        
        %% Extract Solution
        % Extract all variable values using myFun_GetValue
        Solution_MP = myFun_GetValue(model);
        
        % Extract y* values as a struct containing all y-related variable solutions
        y_star = struct();
        y_star_cont = Solution_MP.var_y_cont;
        y_star_int = Solution_MP.var_y_int;
        
        % Store y-related variable solutions for direct use in subproblem
        y_star.A2_yc_vars = Solution_MP.A2_yc_vars;
        y_star.A2_yi_vars = Solution_MP.A2_yi_vars;
        y_star.E2_yc_vars = Solution_MP.E2_yc_vars;
        y_star.E2_yi_vars = Solution_MP.E2_yi_vars;
        
        % Also store combined y* vector for backward compatibility
        y_star.combined = [y_star_cont(:); y_star_int(:)];
        
        % Extract eta*
        eta_star = Solution_MP.eta;
        
        % Extract objective values
        mp_objective = value(objective);
        first_stage_obj = value(objective_first_stage);
        
        % Extract x^l values (optional, for debugging)
        % Use the same index mapping as when creating variables
        x_l_values = cell(num_scenarios, 1);
        if isfield(Solution_MP, 'new_var')
            % Determine starting index (same logic as when creating variables)
            if isfield(iteration_record, 'u_init') && ~isempty(iteration_record.u_init)
                start_idx = 2;  % Skip index 1, which is reserved for u_init
            else
                start_idx = 1;  % No u_init, start from 1
            end
            
            for l = 1:num_scenarios
                var_idx = start_idx + l - 1;
                if length(Solution_MP.new_var) >= var_idx
                    if isfield(Solution_MP.new_var(var_idx), 'x_cont')
                        x_l_values{l}.cont = Solution_MP.new_var(var_idx).x_cont;
                    end
                    if isfield(Solution_MP.new_var(var_idx), 'x_int')
                        x_l_values{l}.int = Solution_MP.new_var(var_idx).x_int;
                    end
                end
            end
        end
        
        %% Build Output Structure
        mp_result.y_star = y_star;
        mp_result.eta_star = eta_star;
        mp_result.objective = mp_objective;
        mp_result.first_stage_obj = first_stage_obj;
        mp_result.solution = solution;
        
        % Build mp_solution for variable mapping
        mp_solution.var = struct();
        mp_solution.var.y_cont = Solution_MP.var_y_cont;
        mp_solution.var.y_int = Solution_MP.var_y_int;
        mp_solution.var.eta = Solution_MP.eta;
        mp_solution.x_l_values = x_l_values; % Store x^l values
        mp_solution.objective = mp_objective;
        mp_solution.solution = solution;
        mp_result.mp_solution = mp_solution;
    end
end
