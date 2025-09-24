function [Solution, BiMIP_record] = solve_BiMIP(original_var, var_x_u, ...
    var_z_u, var_x_l, var_z_l, cons_upper, cons_lower, obj_upper, obj_lower, ops)
%SOLVE_BIMIP Solves a bilevel mixed-integer program (BiMIP).
%
%   [Solution, BiMIP_record] = SOLVE_BIMIP(...)
%
%   This function serves as the main entry point for the PowerBiMIP toolkit.
%   It accepts a user-defined bilevel model (e.g., mixed-integer linear or
%   quadratic) formulated using YALMIP. The toolkit automatically validates
%   the input and reformulates it into the standard BiMIP representation
%   before invoking the core solver.
%
%   Inputs:
%       original_var - All decision variables (YALMIP var objects) in the original model.
%       var_x_u      - Upper-level continuous variables (sdpvar).
%       var_z_u      - Upper-level integer variables (intvar/binvar).
%       var_x_l      - Lower-level continuous variables (sdpvar).
%       var_z_l      - Lower-level integer variables (intvar/binvar).
%       cons_upper   - Upper-level constraints (YALMIP constraint object, mixed-integer linear/quadratic only).
%       cons_lower   - Lower-level constraints (YALMIP constraint object, mixed-integer linear/quadratic only).
%       obj_upper    - Upper-level objective function (YALMIP expression, mixed-integer linear/quadratic only).
%       obj_lower    - Lower-level objective function (YALMIP expression, mixed-integer linear/quadratic only).
%       ops          - A struct containing solver options and settings.
%
%   Outputs:
%       Solution     - A struct containing the final optimal solution.
%           .var     - A struct with variable names and their optimal values.
%           .obj     - The final objective value of the upper-level problem.
%       BiMIP_record - A struct containing detailed iteration history and
%                      solver diagnostics.
%
%   See also EXTRACT_COEFFICIENTS_AND_VARIABLES, PREPROCESS_BILEVEL_MODEL, RD_ALGORITHM.

    % --- Welcome Message and Version Info ---
    fprintf('Welcome to PowerBiMIP V%s | © 2025 Yemin Wu, Southeast University\n', powerbimip_version());
    fprintf('Open-source, efficient tools for power and energy system bilevel mixed-integer programming.\n');
    fprintf('GitHub: https://github.com/GreatTM/PowerBiMIP\n');
    fprintf('Docs:   https://docs.powerbimip.com\n');
    fprintf('--------------------------------------------------------------------------\n');

    % --- Display Non-Default User-Specified Options ---
    if isfield(ops, 'custom_params') && ~isempty(fieldnames(ops.custom_params))
        fprintf('User-specified options:\n');
        params = fieldnames(ops.custom_params);
        max_len = max(cellfun(@length, params));

        for i = 1:length(params)
            pname = params{i};
            pvalue = ops.custom_params.(pname);

            % Format the parameter value for display
            if ischar(pvalue)
                pstr = sprintf('''%s''', pvalue);
            elseif isnumeric(pvalue) && isscalar(pvalue)
                pstr = num2str(pvalue);
            else
                pstr = mat2str(pvalue); % Fallback for matrices/other types
            end
            fprintf('  %-*s = %s\n', max_len + 2, pname, pstr);
        end
        fprintf('--------------------------------------------------------------------------\n');
    end

    fprintf('Starting disciplined bilevel programming process...\n');
    % --- Step 0: Input Check: (Mixed-Integer) Linear/Quadric?
    % Comming soon...
    
    % --- Step 1: Extract General Matrix Form ---
    model = extract_coefficients_and_variables(var_x_u, ...
        var_z_u, var_x_l, var_z_l, cons_upper, cons_lower, obj_upper, obj_lower);
    
    % Store original YALMIP sdpvar objects for final result mapping
    model.var = original_var;

    % --- Step 2: Classify and preprocess the Model ---
    [model_processed, ops_processed] = preprocess_bilevel_model(model, ops);

    fprintf('Disciplined bilevel programming process completed.\n');
    % Coefficients Statistics
    fprintf('Problem Statistics:\n');
    fprintf('  Upper-Level Constraints: %d (%d ineq, %d eq), %d non-zeros\n', ...
        model_processed.upper_total_rows, model_processed.upper_ineq_rows, model_processed.upper_eq_rows, model_processed.upper_nonzeros);
    fprintf('  Lower-Level Constraints: %d (%d ineq, %d eq), %d non-zeros\n', ...
        model_processed.lower_total_rows, model_processed.lower_ineq_rows, model_processed.lower_eq_rows, model_processed.lower_nonzeros);
    fprintf('  Variables (Total): %d continuous, %d integer (%d binary)\n', ...
        model_processed.cont_vars, model_processed.int_vars + model_processed.bin_vars, model_processed.bin_vars);
    fprintf('Coefficient Ranges:\n');
    fprintf('  Matrix Coefficients: [%.1e, %.1e]\n', model_processed.matrix_min, model_processed.matrix_max);
    fprintf('  Objective Coefficients: [%.1e, %.1e]\n', model_processed.obj_min, model_processed.obj_max);
    fprintf('  RHS Values:          [%.1e, %.1e]\n', model_processed.rhs_min, model_processed.rhs_max);
    fprintf('--------------------------------------------------------------------------\n');

    % --- Step 3: Solve the Model ---
    % Invoke the solver dispatcher to select and run the appropriate algorithm.
    BiMIP_record = solver_algorithm(model_processed, ops_processed);

    % --- Step 4: Extract and Format the Final Solution ---
    Solution.var = BiMIP_record.optimal_solution.var;
    Solution.obj = BiMIP_record.UB(end);
end