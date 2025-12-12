function [Solution, Robust_record] = solve_Robust(original_var, var_x_1st, var_z_1st, ...
    var_x_2nd, var_z_2nd, var_u, cons_1st, cons_2nd, cons_uncertainty, obj_1st, obj_2nd, ops, u_init)
%SOLVE_ROBUST Main entry for robust optimization (TRO-LP with RCR).
%
%   [Solution, Robust_record] = SOLVE_ROBUST(...)
%
%   Description:
%       This function serves as the unified entry point for robust
%       optimization in PowerBiMIP. It mirrors the style of solve_BiMIP and
%       delegates preprocessing and algorithm execution to dedicated
%       modules. Current scope: TRO-LP with RCR assumption; subproblem mode
%       is chosen via ops.mode ('exact' uses strong_duality, 'quick' uses
%       quick).
%
%   Inputs:
%       original_var      - All decision variables (YALMIP var objects).
%       var_x_1st         - First-stage continuous variables (sdpvar).
%       var_z_1st         - First-stage integer variables (intvar/binvar).
%       var_x_2nd         - Second-stage continuous recourse variables (sdpvar).
%       var_z_2nd         - Second-stage integer recourse variables (intvar/binvar, usually empty for TRO-LP).
%       var_u             - Uncertain parameters (sdpvar).
%       cons_1st          - First-stage constraints (YALMIP constraint object).
%       cons_2nd          - Second-stage constraints involving y,u,x (YALMIP constraint object).
%       cons_uncertainty  - Uncertainty set constraints (YALMIP constraint object on u).
%       obj_1st           - First-stage objective (YALMIP expression).
%       obj_2nd           - Second-stage objective (YALMIP expression).
%       ops               - Options struct (created by RobustCCGsettings).
%       u_init            - (Optional) Initial value for uncertainty variable u (numeric vector).
%                           If provided, the first iteration will include this scenario with
%                           second-stage variables and constraints. If empty or not provided,
%                           the first iteration will not include eta to avoid unbounded problem.
%
%   Outputs:
%       Solution      - Struct with optimal variable values and objective (UB).
%       Robust_record - Struct with iteration trace, worst-case scenarios, cuts stats, runtime, etc.
%
%   See also RobustCCGsettings, extract_robust_coeffs, algorithm_CCG

    % --- Welcome Message and Version Info ---
    if exist('powerbimip_version', 'file') == 2
        fprintf('Welcome to PowerBiMIP V%s | © 2025 Yemin Wu, Southeast University\n', powerbimip_version());
    else
        fprintf('Welcome to PowerBiMIP (version info unavailable)\n');
    end
    fprintf('Robust Optimization (TRO-LP, RCR assumed) via Column-and-Constraint Generation.\n');
    fprintf('GitHub: https://github.com/GreatTM/PowerBiMIP\n');
    fprintf('Docs:   https://docs.powerbimip.com\n');
    fprintf('--------------------------------------------------------------------------\n');

    % --- Display Non-Default User-Specified Options ---
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

    % --- Step 1: Extract Robust Coefficients ---
    % This call is expected to follow the style of extract_coefficients_and_variables.
    robust_model = extract_robust_coeffs(var_x_1st, var_z_1st, var_x_2nd, ...
        var_z_2nd, var_u, cons_1st, cons_2nd, cons_uncertainty, obj_1st, obj_2nd);

    % Store original YALMIP vars for mapping back solutions
    robust_model.var = original_var;
    
    % Handle optional u_init parameter
    if nargin < 13
        u_init = [];
    end

    % --- Step 2: Run CCG Algorithm Controller ---
    Robust_record = algorithm_CCG(robust_model, ops, u_init);

    % --- Step 3: Extract and Format Final Solution ---
    Solution = struct();
    if isfield(Robust_record, 'optimal_solution') && isstruct(Robust_record.optimal_solution)
        Solution.var = Robust_record.optimal_solution.var;
    else
        Solution.var = struct();
    end
    if isfield(Robust_record, 'UB')
        Solution.obj = Robust_record.UB(end);
    elseif isfield(Robust_record, 'obj_val')
        Solution.obj = Robust_record.obj_val;
    else
        Solution.obj = [];
    end
end

