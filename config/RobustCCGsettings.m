function options = RobustCCGsettings(varargin)
%ROBUSTCCGSETTINGS Creates an options struct for the Robust C&CG solver.
%
%   options = RobustCCGsettings('param1', value1, ...)
%
%   Description:
%       This function builds default options for the Robust C&CG workflow
%       (TRO-LP with RCR assumption) and allows users to override any field
%       via name-value pairs. The style follows BiMIPsettings for a uniform
%       user experience.
%
%   Outputs:
%       options - Struct containing solver options, YALMIP settings, and
%                 user-specified overrides in options.custom_params.
%
%   See also BiMIPsettings, solve_Robust

    % --- Default parameter settings ---
    default_options = struct();
    default_options.mode = 'exact_KKT';          % 'exact' (strong_duality) | 'quick'
    default_options.solver = 'gurobi';
    default_options.verbose = 1;             % 0 silent | 1 summary | 2 detailed | 3 very detailed
    default_options.gap_tol = 1e-4;
    default_options.max_iterations = 50;
    default_options.perspective = 'TRO';     % Placeholder for future robust types

    % --- Initialize with defaults ---
    options = default_options;
    options.custom_params = struct();

    % --- Process user-defined parameters ---
    if nargin > 0
        for i = 1:2:nargin
            paramName = varargin{i};
            paramValue = varargin{i+1};

            % Record non-default parameters
            if isfield(default_options, paramName)
                if ~isequaln(default_options.(paramName), paramValue)
                    options.custom_params.(paramName) = paramValue;
                end
            else
                options.custom_params.(paramName) = paramValue;
                warning('RobustCCG:Settings', 'Non-standard parameter added: %s', paramName);
            end

            options.(paramName) = paramValue;
        end
    end

    % --- Build YALMIP solver settings ---
    % Reduce verbosity passed to solver to keep output concise
    options.ops_MP = sdpsettings('solver', options.solver, 'verbose', 0);
    options.ops_SP = sdpsettings('solver', options.solver, 'verbose', max(0, options.verbose - 2));
end

