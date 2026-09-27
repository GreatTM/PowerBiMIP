function [is_coupled, coupled_info] = has_coupled_constraints(model)
%HAS_COUPLED_CONSTRAINTS Checks for and identifies coupled constraints in a bilevel model.
%
%   Syntax:
%       [is_coupled, coupled_info] = has_coupled_constraints(model)
%
%   Description:
%       This function checks if a standard-form bilevel MIP model contains
%       coupled constraints and returns detailed information about them.
%
%       A coupled constraint is defined as an upper-level constraint that
%       includes lower-level decision variables (i.e., a row where the
%       corresponding coefficients in matrices C_u, D_u, G_u, or H_u are
%       not all zero).
%
%   Input:
%       model - struct: The standard PowerBiMIP model structure.
%
%   Output:
%       is_coupled   - double: Returns 1 if coupled constraints exist, 0 otherwise.
%       coupled_info - struct: A struct containing details about the coupled constraints.
%           .ineq_idx     (logical): A logical vector indicating coupled rows
%                                    in the upper-level inequality constraints
%                                    (true means coupled).
%           .eq_idx       (logical): A logical vector indicating coupled rows
%                                    in the upper-level equality constraints
%                                    (true means coupled).
%           .num_ineq     (double):  The number of coupled inequality constraints.
%           .num_eq       (double):  The number of coupled equality constraints.
%           .needs_relaxation (logical): True if coupled upper vars appear in lower constraints.

    % -- Input Validation --
    if ~isstruct(model)
        error('PowerBiMIP:InvalidInput', 'Input must be a struct.');
    end
    
    coupled_info = struct('ineq_idx', [], 'eq_idx', [], 'num_ineq', 0, 'num_eq', 0, 'needs_relaxation', false);
    
    % Tolerance for checking if a coefficient is effectively zero.
    tolerance = 1e-9; 
    
    % --- Check inequality constraints: A_u*x_u + B_u*z_u + C_u*x_l + D_u*z_l <= b_u ---
    m_ineq = model.upper_ineq_rows;
    if m_ineq > 0
        % Check if C_u and D_u exist and are not empty.
        has_Cu = isfield(model, 'C_u') && ~isempty(model.C_u);
        has_Du = isfield(model, 'D_u') && ~isempty(model.D_u);
        
        % Calculate the sum of absolute values of coefficients related to
        % lower-level variables for each row.
        row_sum = zeros(m_ineq, 1);
        if has_Cu
            row_sum = row_sum + sum(abs(model.C_u), 2);
        end
        if has_Du
            row_sum = row_sum + sum(abs(model.D_u), 2);
        end
        
        coupled_info.ineq_idx = (row_sum > tolerance);
        coupled_info.num_ineq = sum(coupled_info.ineq_idx);
    else
        coupled_info.ineq_idx = false(0,1);
    end
    
    % --- Check equality constraints: E_u*x_u + F_u*z_u + G_u*x_l + H_u*z_l == f_u ---
    m_eq = model.upper_eq_rows;
    if m_eq > 0
        % Check if G_u and H_u exist and are not empty.
        has_Gu = isfield(model, 'G_u') && ~isempty(model.G_u);
        has_Hu = isfield(model, 'H_u') && ~isempty(model.H_u);
        
        row_sum = zeros(m_eq, 1);
        if has_Gu
            row_sum = row_sum + sum(abs(model.G_u), 2);
        end
        if has_Hu
            row_sum = row_sum + sum(abs(model.H_u), 2);
        end
        
        coupled_info.eq_idx = (row_sum > tolerance);
        coupled_info.num_eq = sum(coupled_info.eq_idx);
    else
        coupled_info.eq_idx = false(0,1);
    end
    
    % --- Final Determination ---
    if coupled_info.num_ineq > 0 || coupled_info.num_eq > 0
        is_coupled = 1;
        
        % --- Check if upper-level vars in coupled constraints appear in lower-level constraints ---
        % Extract variable indices from coupled upper-level constraints
        upper_vars_in_coupled = [];
        
        % Tolerance to detect non-zero coefficients
        tol = 1e-9;
        
        % --- 1. Process Inequality Constraints (A_u, B_u) ---
        if coupled_info.num_ineq > 0
            idx_rows = coupled_info.ineq_idx; % Logical index of coupled rows
            
            % Check A_u (Continuous upper vars in inequalities)
            if isfield(model, 'A_u') && ~isempty(model.A_u) && isfield(model, 'A_u_vars') && ~isempty(model.A_u_vars)
                % Extract sub-matrix for coupled rows
                sub_Au = model.A_u(idx_rows, :); 
                % Find columns that have non-zero coefficients in these rows
                active_cols = find(sum(abs(sub_Au), 1) > tol);
                % Extract the variables corresponding to these columns
                upper_vars_in_coupled = [upper_vars_in_coupled; reshape(getvariables(model.A_u_vars(active_cols)), [], 1)];
            end
            
            % Check B_u (Binary/Integer upper vars in inequalities)
            if isfield(model, 'B_u') && ~isempty(model.B_u) && isfield(model, 'B_u_vars') && ~isempty(model.B_u_vars)
                sub_Bu = model.B_u(idx_rows, :);
                active_cols = find(sum(abs(sub_Bu), 1) > tol);
                upper_vars_in_coupled = [upper_vars_in_coupled; reshape(getvariables(model.B_u_vars(active_cols)), [], 1)];
            end
        end
        
        % --- 2. Process Equality Constraints (E_u, F_u) ---
        if coupled_info.num_eq > 0
            idx_rows = coupled_info.eq_idx; % Logical index of coupled rows
            
            % Check E_u (Continuous upper vars in equalities)
            if isfield(model, 'E_u') && ~isempty(model.E_u) && isfield(model, 'E_u_vars') && ~isempty(model.E_u_vars)
                sub_Eu = model.E_u(idx_rows, :);
                active_cols = find(sum(abs(sub_Eu), 1) > tol);
                upper_vars_in_coupled = [upper_vars_in_coupled; reshape(getvariables(model.E_u_vars(active_cols)), [], 1)];
            end
            
            % Check F_u (Binary/Integer upper vars in equalities)
            if isfield(model, 'F_u') && ~isempty(model.F_u) && isfield(model, 'F_u_vars') && ~isempty(model.F_u_vars)
                sub_Fu = model.F_u(idx_rows, :);
                active_cols = find(sum(abs(sub_Fu), 1) > tol);
                upper_vars_in_coupled = [upper_vars_in_coupled; reshape(getvariables(model.F_u_vars(active_cols)), [], 1)];
            end
        end
        
        upper_vars_in_coupled = unique(upper_vars_in_coupled);

        % Extract variable indices from lower-level constraints
        lower_vars_from_upper = [];
        if isfield(model, 'A_l_vars') && ~isempty(model.A_l_vars)
            lower_vars_from_upper = [lower_vars_from_upper; reshape(getvariables(model.A_l_vars(:)), [], 1)];
        end
        if isfield(model, 'B_l_vars') && ~isempty(model.B_l_vars)
            lower_vars_from_upper = [lower_vars_from_upper; reshape(getvariables(model.B_l_vars(:)), [], 1)];
        end
        if isfield(model, 'E_l_vars') && ~isempty(model.E_l_vars)
            lower_vars_from_upper = [lower_vars_from_upper; reshape(getvariables(model.E_l_vars(:)), [], 1)];
        end
        if isfield(model, 'F_l_vars') && ~isempty(model.F_l_vars)
            lower_vars_from_upper = [lower_vars_from_upper; reshape(getvariables(model.F_l_vars(:)), [], 1)];
        end
        
        lower_vars_from_upper = unique(lower_vars_from_upper);
        
        % Check if there's any intersection
        common_vars = intersect(upper_vars_in_coupled, lower_vars_from_upper);
        
        if ~isempty(common_vars)
            % Upper vars in coupled constraints also appear in lower constraints
            % Need relaxation (traditional transform_coupled_to_uncoupled)
            coupled_info.needs_relaxation = true;
        else
            % Upper vars in coupled constraints do NOT appear in lower constraints
            % No need for relaxation, can handle directly in SP2
            coupled_info.needs_relaxation = false;
        end
    else
        is_coupled = 0;
    end
end