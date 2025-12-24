function [Solution, BiMIP_record] = solve_BiMIP(bimip_model, ops)
%SOLVE_BIMIP Solves a bilevel mixed-integer program (BiMIP).
%
%   [Solution, BiMIP_record] = SOLVE_BIMIP(bimip_model, ops)
%
%   Main entry point for PowerBiMIP. It automatically parses the structure,
%   classifies variables (continuous vs integer), checks for linearity,
%   and invokes the core solver.
%
%   Inputs:
%       bimip_model  - A struct with STRICTLY the following fields:
%           .var_upper   : Upper-level variables (sdpvar, struct, or cell)
%           .var_lower   : Lower-level variables (sdpvar, struct, or cell)
%           .cons_upper  : Upper-level constraints
%           .cons_lower  : Lower-level constraints
%           .obj_upper   : Upper-level objective
%           .obj_lower   : Lower-level objective
%       ops          - Options struct (created by BiMIPsettings or default).
%
%   Docs: https://docs.powerbimip.com
%   See also BIMIPSETTINGS.

    % Consistency check: plot requires verbose>=2
    if ops.verbose < 2 && isfield(ops,'plot') && ops.plot.verbose > 0
        warning('PowerBiMIP:Settings','plot.verbose>0 is ignored unless verbose>=2.');
    end

    % --- Welcome Message and Version Info ---
    % Only print welcome message if verbose >= 1 (to avoid clutter when called from subproblems)
    if ops.verbose >= 1
        log_utils('print_banner', ops.verbose, 'Bilevel optimization interface');
        if ops.verbose == 3
            warning('PowerBiMIP:VerboseMode', 'Verbose level 3 prints full solver logs and may clutter the console. If you are not currently debugging, consider setting verbose <= 2 for cleaner output.');
        end

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
    end

    % =========================================================================
    % --- Step 0: Input Check: Linearity and Quadratic Validation ---
    % =========================================================================
    
    % --- Step 0.1: Validate Input Structure ---
    required_fields = {'var_upper'; 'var_lower'; 'cons_upper'; 'cons_lower'; 'obj_upper'; 'obj_lower'};
    given_fields = fieldnames(bimip_model);
    
    % Check for missing or extra fields
    missing = setdiff(required_fields, given_fields);
    extra   = setdiff(given_fields, required_fields);
    
    if ~isempty(missing) || ~isempty(extra)
        fprintf(2, 'Error: Invalid bimip_model structure.\n');
        if ~isempty(missing)
            fprintf(2, '  Missing fields: %s\n', strjoin(missing, ', '));
        end
        if ~isempty(extra)
            fprintf(2, '  Unknown fields: %s\n', strjoin(extra, ', '));
        end
        error('PowerBiMIP:InputFormat', ...
            ['The input structure does not match the specification.\n' ...
             'Please strictly follow the format defined in the Quick Start guide.\n' ...
             'Docs: https://docs.powerbimip.com']);
    end

    % --- Step 0.2: Extract and Classify Variables ---
    % Using 'is' on a vector returns a scalar in YALMIP, so we cannot use it 
    % to mask elements. Instead, we extract all variable indices and filter 
    % them against YALMIP's global integer/binary registry.
    
    % 1. Flatten inputs to get all involved sdpvar objects
    raw_var_upper = extract_flat_sdpvar(bimip_model.var_upper);
    raw_var_lower = extract_flat_sdpvar(bimip_model.var_lower);
    
    % 2. Get global indices of all decision variables involved in the user model
    idx_upper_all = getvariables(raw_var_upper); 
    idx_lower_all = getvariables(raw_var_lower);
    
    % combine to find unique variables actually used in the input model
    idx_model_all = union(idx_upper_all, idx_lower_all);
    
    % --- [New Feature] Environment Cleanliness Check ---
    % Check if YALMIP has more variables defined than what is passed in the model.
    % This usually happens if the user forgot yalmip('clear').
    num_vars_in_yalmip = yalmip('nvars');
    num_vars_in_model  = length(idx_model_all);
    
    if num_vars_in_yalmip > num_vars_in_model
        error('PowerBiMIP:DirtyEnvironment', ...
            ['YALMIP internal state contains %d variables, but the input model only uses %d.\n' ...
             'You might have "ghost variables" from a previous run.\n' ...
             'Recommendation: Run "yalmip(''clear'')" before defining your model variables.'], ...
             num_vars_in_yalmip, num_vars_in_model);
    end
    % ---------------------------------------------------

    % 3. Get global indices of ALL integer and binary variables in YALMIP
    all_int_idx = yalmip('intvariables');
    all_bin_idx = yalmip('binvariables');
    all_discrete_idx = union(all_int_idx, all_bin_idx);
    
    % 4. Classify Upper-Level Variables
    % Intersect: Variables in Upper Level that are Discrete
    idx_z_u = intersect(idx_upper_all, all_discrete_idx);
    % Setdiff: Variables in Upper Level that are NOT Discrete (Continuous)
    idx_x_u = setdiff(idx_upper_all, all_discrete_idx);
    
    % Reconstruct sdpvar objects from indices
    var_z_u = recover(idx_z_u); % Upper Integer/Binary
    var_x_u = recover(idx_x_u); % Upper Continuous
    
    % 5. Classify Lower-Level Variables
    idx_z_l = intersect(idx_lower_all, all_discrete_idx);
    idx_x_l = setdiff(idx_lower_all, all_discrete_idx);
    
    % Reconstruct sdpvar objects
    var_z_l = recover(idx_z_l); % Lower Integer/Binary
    var_x_l = recover(idx_x_l); % Lower Continuous
    
    % Extract Constraints and Objectives directly
    cons_upper = bimip_model.cons_upper;
    cons_lower = bimip_model.cons_lower;
    obj_upper  = bimip_model.obj_upper;
    obj_lower  = bimip_model.obj_lower;

    % Consistency check: plot requires verbose>=2
    if ops.verbose < 2 && isfield(ops,'plot') && ops.plot.verbose > 0
        warning('PowerBiMIP:Settings','plot.verbose>0 is ignored unless verbose>=2.');
    end
    
    % --- Welcome Message ---
    if ops.verbose >= 1
        log_utils('print_banner', ops.verbose, 'Bilevel optimization interface');
        if isfield(ops, 'custom_params') && ~isempty(fieldnames(ops.custom_params))
            % ... (Optional: Print custom params logic) ...
        end
        fprintf('Starting disciplined bilevel programming process...\n');
    end
    
    % --- Step 0.3: Linearity and Quadratic Check ---
    % Check Upper-Level Constraints
    if ~isempty(cons_upper)
        if ~all(is(cons_upper, 'linear'))
            error('PowerBiMIP:NonlinearConstraint', ...
                'Upper-level constraints contain nonlinear terms. Only linear constraints are supported.');
        end
    end
    
    % Check Lower-Level Constraints
    if ~isempty(cons_lower)
        if ~all(is(cons_lower, 'linear'))
            error('PowerBiMIP:NonlinearConstraint', ...
                'Lower-level constraints contain nonlinear terms. Only linear constraints are supported.');
        end
    end
    
    % Check Objectives
    deg_u = degree(obj_upper);
    if deg_u ~= 1
        if deg_u == 2
                error('PowerBiMIP:QuadraticObjective', 'Quadratic objective in Upper Level: Feature coming soon!');
        elseif deg_u > 2
                error('PowerBiMIP:NonlinearObjective', 'Nonlinear objective in Upper Level detected (Degree: %d). Not supported.', deg_u);
        else
                warning('The upper-level objective function is a constant. Please verify if this is as expected.');
        end
    end

    deg_l = degree(obj_lower);
    if deg_l ~= 1
        if deg_l == 2
            error('PowerBiMIP:QuadraticObjective', 'Quadratic objective in Lower Level: Feature coming soon!');
        elseif deg_l > 2
            error('PowerBiMIP:NonlinearObjective', 'Nonlinear objective in Lower Level detected (Degree: %d). Not supported.', deg_l);
        else
            warning('The lower-level objective function is a constant. Please verify if this is as expected.');
        end
    end

    % =========================================================================
    % End of Step 0
    % =========================================================================

    % --- Step 1: Extract General Matrix Form ---
    model = extract_coefficients_and_variables(var_x_u, ...
        var_z_u, var_x_l, var_z_l, cons_upper, cons_lower, obj_upper, obj_lower, ops);
    
    model.var.var_upper = bimip_model.var_upper;
    model.var.var_lower = bimip_model.var_lower;

    % --- Step 2: Classify and preprocess the Model ---
    [model_processed, ops_processed] = preprocess_bilevel_model(model, ops);

    % Only print detailed statistics if verbose >= 2
    if ops.verbose >= 1
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
    end

    % --- Step 3: Solve the Model ---
    % Invoke the solver dispatcher to select and run the appropriate algorithm.
    BiMIP_record = solver_algorithm(model_processed, ops_processed);

    % --- Step 4: Extract and Format the Final Solution ---
    Solution = myFun_GetValue(bimip_model);
end


% -------------------------------------------------------------------------
% Helper Function: Recursively extract sdpvars from structs/cells
% -------------------------------------------------------------------------
function flat_vars = extract_flat_sdpvar(input_obj)
    flat_vars = [];
    
    if isa(input_obj, 'sdpvar')
        % Base case: It's an sdpvar (scalar, vector, or matrix)
        flat_vars = input_obj(:); % Force column vector
        
    elseif isstruct(input_obj)
        % Recursive case: It's a struct
        fields = fieldnames(input_obj);
        for i = 1:length(fields)
            field_content = input_obj.(fields{i});
            flat_vars = [flat_vars; extract_flat_sdpvar(field_content)];
        end
        
    elseif iscell(input_obj)
        % Recursive case: It's a cell array
        for i = 1:numel(input_obj)
            flat_vars = [flat_vars; extract_flat_sdpvar(input_obj{i})];
        end
        
    elseif isnumeric(input_obj)
        % Ignore numeric constants (empty variables) logic, 
        % or treat as error depending on strictness. 
        % Here we largely ignore or assume user didn't put constants in var list.
    else
        % Unknown type (e.g. strings inside var struct), ignore or warn
    end
end