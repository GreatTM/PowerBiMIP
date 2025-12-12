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
        if ~isempty(model.b1)
            lhs_ineq = 0;
            if ~isempty(model.A1_yc) && ~isempty(model.A1_yc_vars)
                lhs_ineq = lhs_ineq + model.A1_yc * model.A1_yc_vars;
            end
            if ~isempty(model.A1_yi) && ~isempty(model.A1_yi_vars)
                lhs_ineq = lhs_ineq + model.A1_yi * model.A1_yi_vars;
            end
            if ~isempty(lhs_ineq)
                constraints = constraints + (lhs_ineq <= model.b1);
            end
        end
        
        % First-stage equality constraints: E1_yc * y_cont + E1_yi * y_int == f1
        if ~isempty(model.f1)
            lhs_eq = 0;
            if ~isempty(model.E1_yc) && ~isempty(model.E1_yc_vars)
                lhs_eq = lhs_eq + model.E1_yc * model.E1_yc_vars;
            end
            if ~isempty(model.E1_yi) && ~isempty(model.E1_yi_vars)
                lhs_eq = lhs_eq + model.E1_yi * model.E1_yi_vars;
            end
            if ~isempty(lhs_eq)
                constraints = constraints + (lhs_eq == model.f1);
            end
        end
        
        %% Check if initial scenario u_init is provided
        u_init = [];
        if isfield(iteration_record, 'u_init')
            u_init = iteration_record.u_init;
        end
        
        if ~isempty(u_init)
            %% Case 1: u_init is provided - Add initial scenario with second-stage variables
            
            % Ensure u_init is a column vector
            if size(u_init, 2) > size(u_init, 1)
                u_init = u_init';
            end
            
            %% Introduce Auxiliary Variable eta
            eta = sdpvar(1, 1);
            
            %% Copy Second-Stage Variables x^0 for initial scenario
            x_0_cont = [];
            x_0_int = [];
            
            if ~isempty(model.var_x_cont)
                x_0_cont = sdpvar(size(model.var_x_cont, 1), size(model.var_x_cont, 2), 'full');
            end
            if ~isempty(model.var_x_int)
                x_0_int = intvar(size(model.var_x_int, 1), size(model.var_x_int, 2), 'full');
            end
            
            %% Add Objective Constraint: eta >= d^T x^0
            obj_constraint = 0;
            if ~isempty(model.c2_xc) && ~isempty(x_0_cont)
                obj_constraint = obj_constraint + model.c2_xc' * x_0_cont(:);
            end
            if ~isempty(model.c2_xi) && ~isempty(x_0_int)
                obj_constraint = obj_constraint + model.c2_xi' * x_0_int(:);
            end
            if ~isempty(obj_constraint)
                constraints = constraints + (eta >= obj_constraint);
            end
            
            %% Add Structural Constraints: G x^0 >= h - E y - M u_init
            % Inequality constraints: A2_xc * x_0_cont + A2_xi * x_0_int >= 
            %                         b2 - A2_yc * y_cont - A2_yi * y_int - A2_u * u_init
            if ~isempty(model.b2)
                % Compute RHS: b2 - A2_u * u_init
                rhs_ineq = model.b2;
                if ~isempty(model.A2_u) && ~isempty(u_init)
                    if length(u_init) == size(model.A2_u, 2)
                        rhs_ineq = rhs_ineq - model.A2_u * u_init;
                    else
                        warning('PowerBiMIP:CCGMaster', ...
                            'Dimension mismatch in u_init for A2_u. Using direct multiplication.');
                        if size(model.A2_u, 2) == length(u_init)
                            rhs_ineq = rhs_ineq - model.A2_u * u_init;
                        end
                    end
                end
                
                % Build constraint: A2_xc * x_0_cont + A2_xi * x_0_int + 
                %                   A2_yc * y_cont + A2_yi * y_int >= rhs_ineq
                lhs_ineq = 0;
                if ~isempty(model.A2_xc) && ~isempty(x_0_cont)
                    lhs_ineq = lhs_ineq + model.A2_xc * x_0_cont(:);
                end
                if ~isempty(model.A2_xi) && ~isempty(x_0_int)
                    lhs_ineq = lhs_ineq + model.A2_xi * x_0_int(:);
                end
                if ~isempty(model.A2_yc) && ~isempty(model.A2_yc_vars)
                    lhs_ineq = lhs_ineq + model.A2_yc * model.A2_yc_vars;
                end
                if ~isempty(model.A2_yi) && ~isempty(model.A2_yi_vars)
                    lhs_ineq = lhs_ineq + model.A2_yi * model.A2_yi_vars;
                end
                
                if ~isempty(lhs_ineq)
                    constraints = constraints + (lhs_ineq >= rhs_ineq);
                end
            end
            
            % Equality constraints: E2_xc * x_0_cont + E2_xi * x_0_int == 
            %                     f2 - E2_yc * y_cont - E2_yi * y_int - E2_u * u_init
            if ~isempty(model.f2)
                % Compute RHS: f2 - E2_u * u_init
                rhs_eq = model.f2;
                if ~isempty(model.E2_u) && ~isempty(u_init)
                    if length(u_init) == size(model.E2_u, 2)
                        rhs_eq = rhs_eq - model.E2_u * u_init;
                    else
                        warning('PowerBiMIP:CCGMaster', ...
                            'Dimension mismatch in u_init for E2_u. Using direct multiplication.');
                        if size(model.E2_u, 2) == length(u_init)
                            rhs_eq = rhs_eq - model.E2_u * u_init;
                        end
                    end
                end
                
                % Build constraint: E2_xc * x_0_cont + E2_xi * x_0_int + 
                %                   E2_yc * y_cont + E2_yi * y_int == rhs_eq
                lhs_eq = 0;
                if ~isempty(model.E2_xc) && ~isempty(x_0_cont)
                    lhs_eq = lhs_eq + model.E2_xc * x_0_cont(:);
                end
                if ~isempty(model.E2_xi) && ~isempty(x_0_int)
                    lhs_eq = lhs_eq + model.E2_xi * x_0_int(:);
                end
                if ~isempty(model.E2_yc) && ~isempty(model.E2_yc_vars)
                    lhs_eq = lhs_eq + model.E2_yc * model.E2_yc_vars;
                end
                if ~isempty(model.E2_yi) && ~isempty(model.E2_yi_vars)
                    lhs_eq = lhs_eq + model.E2_yi * model.E2_yi_vars;
                end
                
                if ~isempty(lhs_eq)
                    constraints = constraints + (lhs_eq == rhs_eq);
                end
            end
            
            %% Build Objective Function
            % First-stage objective: c1_yc^T * y_cont + c1_yi^T * y_int
            objective_first_stage = 0;
            if ~isempty(model.c1_yc) && ~isempty(model.c1_yc_vars)
                objective_first_stage = objective_first_stage + model.c1_yc' * model.c1_yc_vars;
            end
            if ~isempty(model.c1_yi) && ~isempty(model.c1_yi_vars)
                objective_first_stage = objective_first_stage + model.c1_yi' * model.c1_yi_vars;
            end
            
            % Total objective: min c^T y + eta
            objective = objective_first_stage + eta;
            
        else
            %% Case 2: u_init is empty - No eta to avoid unbounded problem
            
            %% Build Objective Function (only first-stage, no eta)
            objective_first_stage = 0;
            if ~isempty(model.c1_yc) && ~isempty(model.c1_yc_vars)
                objective_first_stage = objective_first_stage + model.c1_yc' * model.c1_yc_vars;
            end
            if ~isempty(model.c1_yi) && ~isempty(model.c1_yi_vars)
                objective_first_stage = objective_first_stage + model.c1_yi' * model.c1_yi_vars;
            end
            
            % Total objective: min c^T y (no eta)
            objective = objective_first_stage;
            eta = []; % No eta variable
        end
        
        %% Solve
        solution = optimize(constraints, objective, ops.ops_MP);
        
        %% Extract Solution
        % Extract y* values as a struct containing all y-related variable solutions
        y_star = struct();
        y_star_cont = [];
        y_star_int = [];
        if ~isempty(model.var_y_cont)
            y_star_cont = value(model.var_y_cont);
        end
        if ~isempty(model.var_y_int)
            y_star_int = value(model.var_y_int);
        end
        
        % Store y-related variable solutions for direct use in subproblem
        if ~isempty(model.A2_yc_vars)
            y_star.A2_yc_vars = value(model.A2_yc_vars);
        end
        if ~isempty(model.A2_yi_vars)
            y_star.A2_yi_vars = value(model.A2_yi_vars);
        end
        if ~isempty(model.E2_yc_vars)
            y_star.E2_yc_vars = value(model.E2_yc_vars);
        end
        if ~isempty(model.E2_yi_vars)
            y_star.E2_yi_vars = value(model.E2_yi_vars);
        end
        
        % Also store combined y* vector for backward compatibility
        y_star.combined = [y_star_cont(:); y_star_int(:)];
        
        % Extract eta* (if exists)
        if ~isempty(eta)
            eta_star = value(eta);
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
        if ~isempty(model.var_y_cont)
            mp_solution.var.y_cont = y_star_cont;
        end
        if ~isempty(model.var_y_int)
            mp_solution.var.y_int = y_star_int;
        end
        if ~isempty(eta)
            mp_solution.var.eta = eta_star;
        end
        mp_solution.objective = mp_objective;
        mp_solution.solution = solution;
        mp_result.mp_solution = mp_solution;
        
    else
        %% Subsequent Iterations: Add Cuts for Each Identified Scenario
        
        %% Reuse First-Stage Constraints and Auxiliary Variable
        constraints = [];
        
        % First-stage inequality constraints
        if ~isempty(model.b1)
            lhs_ineq = 0;
            if ~isempty(model.A1_yc) && ~isempty(model.A1_yc_vars)
                lhs_ineq = lhs_ineq + model.A1_yc * model.A1_yc_vars;
            end
            if ~isempty(model.A1_yi) && ~isempty(model.A1_yi_vars)
                lhs_ineq = lhs_ineq + model.A1_yi * model.A1_yi_vars;
            end
            if ~isempty(lhs_ineq)
                constraints = constraints + (lhs_ineq <= model.b1);
            end
        end
        
        % First-stage equality constraints
        if ~isempty(model.f1)
            lhs_eq = 0;
            if ~isempty(model.E1_yc) && ~isempty(model.E1_yc_vars)
                lhs_eq = lhs_eq + model.E1_yc * model.E1_yc_vars;
            end
            if ~isempty(model.E1_yi) && ~isempty(model.E1_yi_vars)
                lhs_eq = lhs_eq + model.E1_yi * model.E1_yi_vars;
            end
            if ~isempty(lhs_eq)
                constraints = constraints + (lhs_eq == model.f1);
            end
        end
        
        %% Auxiliary Variable eta
        eta = sdpvar(1, 1);
        
        %% Add Cuts for Each Identified Scenario
        num_scenarios = iteration_record.iteration_num - 1;
        x_l_vars = cell(num_scenarios, 1); % Store x^l variables for each scenario
        
        for l = 1:num_scenarios
            % Get worst-case scenario u^l (as numerical values)
            if isfield(iteration_record, 'worst_case_u_history') && ...
                    length(iteration_record.worst_case_u_history) >= l && ...
                    ~isempty(iteration_record.worst_case_u_history{l})
                u_l = iteration_record.worst_case_u_history{l};
            elseif isfield(iteration_record, 'scenario_set') && ...
                    length(iteration_record.scenario_set) >= l && ...
                    ~isempty(iteration_record.scenario_set{l})
                u_l = iteration_record.scenario_set{l};
            else
                warning('PowerBiMIP:CCGMaster', ...
                    'Scenario u^%d not found in iteration_record. Skipping cut.', l);
                continue;
            end
            
            % Ensure u_l is a column vector
            if size(u_l, 2) > size(u_l, 1)
                u_l = u_l';
            end
            
            %% Copy Second-Stage Variables x^l
            % Create new variables x^l with the same dimensions as original x
            x_l_cont = [];
            x_l_int = [];
            
            if ~isempty(model.var_x_cont)
                x_l_cont = sdpvar(size(model.var_x_cont, 1), size(model.var_x_cont, 2), 'full');
            end
            if ~isempty(model.var_x_int)
                x_l_int = intvar(size(model.var_x_int, 1), size(model.var_x_int, 2), 'full');
            end
            
            x_l_vars{l}.cont = x_l_cont;
            x_l_vars{l}.int = x_l_int;
            
            %% Add Objective Constraint: eta >= d^T x^l
            obj_constraint = 0;
            if ~isempty(model.c2_xc) && ~isempty(x_l_cont)
                obj_constraint = obj_constraint + model.c2_xc' * x_l_cont(:);
            end
            if ~isempty(model.c2_xi) && ~isempty(x_l_int)
                obj_constraint = obj_constraint + model.c2_xi' * x_l_int(:);
            end
            if ~isempty(obj_constraint)
                constraints = constraints + (eta >= obj_constraint);
            end
            
            %% Add Structural Constraints: G x^l >= h - E y - M u^l
            % Note: u^l is numerical, so M * u^l becomes a numerical RHS term
            
            % Inequality constraints: A2_xc * x_l_cont + A2_xi * x_l_int >= 
            %                         b2 - A2_yc * y_cont - A2_yi * y_int - A2_u * u_l
            if ~isempty(model.b2)
                % Compute RHS: b2 - A2_u * u_l (u^l is numerical)
                rhs_ineq = model.b2;
                if ~isempty(model.A2_u) && ~isempty(u_l)
                    % Map u_l to the correct indices for A2_u
                    % A2_u corresponds to model.A2_u_vars, need to map u_l accordingly
                    if length(u_l) == size(model.A2_u, 2)
                        rhs_ineq = rhs_ineq - model.A2_u * u_l;
                    else
                        % Try to map u_l to A2_u_vars indices
                        % This is a simplified mapping; may need refinement
                        warning('PowerBiMIP:CCGMaster', ...
                            'Dimension mismatch in u^%d for A2_u. Using direct multiplication.', l);
                        if size(model.A2_u, 2) == length(u_l)
                            rhs_ineq = rhs_ineq - model.A2_u * u_l;
                        end
                    end
                end
                
                % Build constraint: A2_xc * x_l_cont + A2_xi * x_l_int + 
                %                   A2_yc * y_cont + A2_yi * y_int >= rhs_ineq
                lhs_ineq = 0;
                if ~isempty(model.A2_xc) && ~isempty(x_l_cont)
                    lhs_ineq = lhs_ineq + model.A2_xc * x_l_cont(:);
                end
                if ~isempty(model.A2_xi) && ~isempty(x_l_int)
                    lhs_ineq = lhs_ineq + model.A2_xi * x_l_int(:);
                end
                if ~isempty(model.A2_yc) && ~isempty(model.A2_yc_vars)
                    lhs_ineq = lhs_ineq + model.A2_yc * model.A2_yc_vars;
                end
                if ~isempty(model.A2_yi) && ~isempty(model.A2_yi_vars)
                    lhs_ineq = lhs_ineq + model.A2_yi * model.A2_yi_vars;
                end
                
                if ~isempty(lhs_ineq)
                    constraints = constraints + (lhs_ineq >= rhs_ineq);
                end
            end
            
            % Equality constraints: E2_xc * x_l_cont + E2_xi * x_l_int == 
            %                     f2 - E2_yc * y_cont - E2_yi * y_int - E2_u * u_l
            if ~isempty(model.f2)
                % Compute RHS: f2 - E2_u * u_l
                rhs_eq = model.f2;
                if ~isempty(model.E2_u) && ~isempty(u_l)
                    if length(u_l) == size(model.E2_u, 2)
                        rhs_eq = rhs_eq - model.E2_u * u_l;
                    else
                        warning('PowerBiMIP:CCGMaster', ...
                            'Dimension mismatch in u^%d for E2_u. Using direct multiplication.', l);
                        if size(model.E2_u, 2) == length(u_l)
                            rhs_eq = rhs_eq - model.E2_u * u_l;
                        end
                    end
                end
                
                % Build constraint: E2_xc * x_l_cont + E2_xi * x_l_int + 
                %                   E2_yc * y_cont + E2_yi * y_int == rhs_eq
                lhs_eq = 0;
                if ~isempty(model.E2_xc) && ~isempty(x_l_cont)
                    lhs_eq = lhs_eq + model.E2_xc * x_l_cont(:);
                end
                if ~isempty(model.E2_xi) && ~isempty(x_l_int)
                    lhs_eq = lhs_eq + model.E2_xi * x_l_int(:);
                end
                if ~isempty(model.E2_yc) && ~isempty(model.E2_yc_vars)
                    lhs_eq = lhs_eq + model.E2_yc * model.E2_yc_vars;
                end
                if ~isempty(model.E2_yi) && ~isempty(model.E2_yi_vars)
                    lhs_eq = lhs_eq + model.E2_yi * model.E2_yi_vars;
                end
                
                if ~isempty(lhs_eq)
                    constraints = constraints + (lhs_eq == rhs_eq);
                end
            end
        end
        
        %% Build Objective Function (same as first iteration)
        objective_first_stage = 0;
        if ~isempty(model.c1_yc) && ~isempty(model.c1_yc_vars)
            objective_first_stage = objective_first_stage + model.c1_yc' * model.c1_yc_vars;
        end
        if ~isempty(model.c1_yi) && ~isempty(model.c1_yi_vars)
            objective_first_stage = objective_first_stage + model.c1_yi' * model.c1_yi_vars;
        end
        objective = objective_first_stage + eta;
        
        %% Solve
        solution = optimize(constraints, objective, ops.ops_MP);
        
        %% Extract Solution
        % Extract y* values as a struct containing all y-related variable solutions
        y_star = struct();
        y_star_cont = [];
        y_star_int = [];
        if ~isempty(model.var_y_cont)
            y_star_cont = value(model.var_y_cont);
        end
        if ~isempty(model.var_y_int)
            y_star_int = value(model.var_y_int);
        end
        
        % Store y-related variable solutions for direct use in subproblem
        if ~isempty(model.A2_yc_vars)
            y_star.A2_yc_vars = value(model.A2_yc_vars);
        end
        if ~isempty(model.A2_yi_vars)
            y_star.A2_yi_vars = value(model.A2_yi_vars);
        end
        if ~isempty(model.E2_yc_vars)
            y_star.E2_yc_vars = value(model.E2_yc_vars);
        end
        if ~isempty(model.E2_yi_vars)
            y_star.E2_yi_vars = value(model.E2_yi_vars);
        end
        
        % Also store combined y* vector for backward compatibility
        y_star.combined = [y_star_cont(:); y_star_int(:)];
        
        % Extract eta*
        eta_star = value(eta);
        
        % Extract objective values
        mp_objective = value(objective);
        first_stage_obj = value(objective_first_stage);
        
        % Extract x^l values (optional, for debugging)
        x_l_values = cell(num_scenarios, 1);
        for l = 1:num_scenarios
            if ~isempty(x_l_vars{l}.cont)
                x_l_values{l}.cont = value(x_l_vars{l}.cont);
            end
            if ~isempty(x_l_vars{l}.int)
                x_l_values{l}.int = value(x_l_vars{l}.int);
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
        if ~isempty(model.var_y_cont)
            mp_solution.var.y_cont = y_star_cont;
        end
        if ~isempty(model.var_y_int)
            mp_solution.var.y_int = y_star_int;
        end
        mp_solution.var.eta = eta_star;
        mp_solution.x_l_values = x_l_values; % Store x^l values
        mp_solution.objective = mp_objective;
        mp_solution.solution = solution;
        mp_result.mp_solution = mp_solution;
    end
end

