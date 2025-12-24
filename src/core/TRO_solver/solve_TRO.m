function [Solution, CCG_record] = solve_TRO(tro_model, ops, u_init)
%SOLVE_TRO Main entry for robust optimization (TRO-LP with RCR).
%
%   [Solution, CCG_record] = SOLVE_TRO(tro_model, ops, u_init)
%
%   Description:
%       This function serves as the unified entry point for robust
%       optimization in PowerBiMIP. It automatically parses the input structure,
%       classifies variables, and delegates to the CCG algorithm.
%
%   Inputs:
%       tro_model - A struct with STRICTLY the following fields:
%           .var_1st          : First-stage variables (sdpvar, struct, or cell)
%           .var_2nd          : Second-stage variables (sdpvar, struct, or cell)
%           .var_uncertain    : Uncertain parameters (sdpvar, struct, or cell)
%           .cons_1st         : First-stage constraints
%           .cons_2nd         : Second-stage constraints (involving x, y, u)
%           .cons_uncertainty : Uncertainty set constraints (on u)
%           .obj_1st          : First-stage objective
%           .obj_2nd          : Second-stage objective
%       ops       - Options struct (created by TROsettings).
%       u_init    - (Optional) Initial value for uncertainty variable u.
%
%   Docs: https://docs.powerbimip.com
%   See also TROSETTINGS, EXTRACT_ROBUST_COEFFS, ALGORITHM_CCG

    % Consistency check: plot requires verbose>=2
    if ops.verbose < 2 && isfield(ops,'plot') && ops.plot.verbose > 0
        warning('PowerBiMIP:Settings','plot.verbose>0 is ignored unless verbose>=2.');
    end

    % Handle optional u_init parameter
    if nargin < 3
        u_init = [];
    end

    % --- Welcome Message and Version Info (one-time) ---
    if ops.verbose >= 1
        log_utils('print_banner', ops.verbose, 'Two-stage robust optimization interface');
        if ops.verbose == 3
            warning('PowerBiMIP:VerboseMode', 'Verbose level 3 prints full solver logs and may clutter the console. If you are not currently debugging, consider setting verbose <= 2 for cleaner output.');
        end
        if isfield(ops, 'custom_params') && ~isempty(fieldnames(ops.custom_params))
            fprintf('User-specified options:\n');
            params = fieldnames(ops.custom_params);
            maxLen = max(cellfun(@length, params));
            for i = 1:length(params)
                pName = params{i};
                pValue = ops.custom_params.(pName);
                if ischar(pValue)
                    pStr = sprintf('''%s''', pValue);
                elseif isnumeric(pValue) && isscalar(pValue)
                    pStr = num2str(pValue);
                else
                    pStr = mat2str(pValue);
                end
                fprintf('  %-*s = %s\n', maxLen + 2, pName, pStr);
            end
            fprintf('--------------------------------------------------------------------------\n');
        end
    end

    
% =========================================================================
    % --- Step 0: Input Check & Parsing ---
    % =========================================================================
    
    % --- Step 0.1: Validate Input Structure ---
    required_fields = {'var_1st'; 'var_2nd'; 'var_uncertain'; ...
                       'cons_1st'; 'cons_2nd'; 'cons_uncertainty'; ...
                       'obj_1st'; 'obj_2nd'};
    given_fields = fieldnames(tro_model);
    
    % Check for missing or extra fields
    missing = setdiff(required_fields, given_fields);
    extra   = setdiff(given_fields, required_fields);
    
    if ~isempty(missing) || ~isempty(extra)
        fprintf(2, 'Error: Invalid tro_model structure.\n');
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
    % 1. Flatten inputs to get all involved sdpvar objects
    raw_var_1st = extract_flat_sdpvar(tro_model.var_1st);
    raw_var_2nd = extract_flat_sdpvar(tro_model.var_2nd);
    var_u       = extract_flat_sdpvar(tro_model.var_uncertain);
    
    % 2. Get global indices of all decision variables involved in the user model
    idx_1st_all = getvariables(raw_var_1st); 
    idx_2nd_all = getvariables(raw_var_2nd);
    idx_u_all   = getvariables(var_u);
    
    % Combine to find unique variables actually used in the input model
    idx_model_all = union(union(idx_1st_all, idx_2nd_all), idx_u_all);
    
    % --- [Environment Cleanliness Check] ---
    num_vars_in_yalmip = yalmip('nvars');
    num_vars_in_model  = length(idx_model_all);
    
    if num_vars_in_yalmip > num_vars_in_model
        error('PowerBiMIP:DirtyEnvironment', ...
            ['YALMIP internal state contains %d variables, but the input model only uses %d.\n' ...
             'You might have "ghost variables" from a previous run.\n' ...
             'Recommendation: Run "yalmip(''clear'')" before defining your model variables.'], ...
             num_vars_in_yalmip, num_vars_in_model);
    end
    % ---------------------------------------

    % 3. Get global indices of ALL integer and binary variables in YALMIP
    all_int_idx = yalmip('intvariables');
    all_bin_idx = yalmip('binvariables');
    all_discrete_idx = union(all_int_idx, all_bin_idx);
    
    % 4. Classify First-Stage Variables
    idx_z_1st = intersect(idx_1st_all, all_discrete_idx);
    idx_x_1st = setdiff(idx_1st_all, all_discrete_idx);
    
    var_z_1st = recover(idx_z_1st); % First-stage Integer/Binary
    var_x_1st = recover(idx_x_1st); % First-stage Continuous
    
    % 5. Classify Second-Stage Variables
    idx_z_2nd = intersect(idx_2nd_all, all_discrete_idx);
    idx_x_2nd = setdiff(idx_2nd_all, all_discrete_idx);
    
    var_z_2nd = recover(idx_z_2nd); % Second-stage Integer/Binary (Usually empty for TRO-LP)
    var_x_2nd = recover(idx_x_2nd); % Second-stage Continuous
    
    % Note: var_u is treated as continuous by default in standard robust optimization,
    % but we keep it as extracted.
    
    % Extract Constraints and Objectives directly
    cons_1st         = tro_model.cons_1st;
    cons_2nd         = tro_model.cons_2nd;
    cons_uncertainty = tro_model.cons_uncertainty;
    obj_1st          = tro_model.obj_1st;
    obj_2nd          = tro_model.obj_2nd;

    % --- Step 0.3: Linearity and Quadratic Check ---
    
    % Check First-Stage Constraints
    if ~isempty(cons_1st)
        if ~all(is(cons_1st, 'linear'))
            error('PowerBiMIP:NonlinearConstraint', ...
                'First-stage constraints contain nonlinear or quadratic terms. Only linear constraints are supported.');
        end
    end
    
    % Check Second-Stage Constraints
    if ~isempty(cons_2nd)
        if ~all(is(cons_2nd, 'linear'))
            error('PowerBiMIP:NonlinearConstraint', ...
                'Second-stage constraints contain nonlinear or quadratic terms. Only linear constraints are supported.');
        end
    end
    
    % Check Uncertainty Set Constraints
    if ~isempty(cons_uncertainty)
        if ~all(is(cons_uncertainty, 'linear'))
            error('PowerBiMIP:NonlinearConstraint', ...
                'Uncertainty set constraints contain nonlinear or quadratic terms. Only linear constraints are supported.');
        end
    end
    
    % Check Objectives
    deg_1 = degree(obj_1st);
    if deg_1 == 2
        error('PowerBiMIP:QuadraticObjective', 'Quadratic objective in First Stage: Feature coming soon!');
    elseif deg_1 > 2
        error('PowerBiMIP:NonlinearObjective', 'Nonlinear objective in First Stage detected (Degree: %d). Not supported.', deg_1);
    else
        warning('The 1st-stage objective function is a constant. Please verify if this is as expected.');
    end

    deg_2 = degree(obj_2nd);
    if deg_2 == 2
        error('PowerBiMIP:QuadraticObjective', 'Quadratic objective in Second Stage: Feature coming soon!');
    elseif deg_2 > 2
        error('PowerBiMIP:NonlinearObjective', 'Nonlinear objective in Second Stage detected (Degree: %d). Not supported.', deg_2);
    else
        warning('The 2nd-stage objective function is a constant. Please verify if this is as expected.');
    end
    
    % =========================================================================
    % End of Step 0
    % =========================================================================

    % --- Step 1: Extract Robust Coefficients ---
    % This call is expected to follow the style of extract_coefficients_and_variables.
    robust_model = extract_robust_coeffs(var_x_1st, var_z_1st, var_x_2nd, ...
        var_z_2nd, var_u, cons_1st, cons_2nd, cons_uncertainty, obj_1st, obj_2nd, u_init, ops);

    % Store original YALMIP vars for mapping back solutions
    robust_model.var.var_1st = tro_model.var_1st;
    robust_model.var.var_2st = tro_model.var_2nd;
    robust_model.var.var_uncertain = tro_model.var_uncertain;
    
    % --- Step 2: Run CCG Algorithm Controller ---
    CCG_record = algorithm_CCG(robust_model, ops, u_init);

    % --- Step 3: Extract and Format Final Solution ---
    Solution = myFun_GetValue(tro_model);
end

% -------------------------------------------------------------------------
% Helper Function: Recursively extract sdpvars from structs/cells
% -------------------------------------------------------------------------
function flat_vars = extract_flat_sdpvar(input_obj)
    flat_vars = [];
    
    if isa(input_obj, 'sdpvar') || isa(input_obj, 'ndsdpvar')
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
        % Ignore numeric constants
    else
        error('Huh?');
    end
end
