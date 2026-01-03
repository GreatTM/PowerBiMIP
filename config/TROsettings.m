function options = TROsettings(varargin)
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
%   See also BiMIPsettings, solve_TRO

    % --- Default parameter settings ---
    default_options = struct();
    default_options.mode = 'exact_KKT';          % 'exact' (strong_duality) | 'quick'
    default_options.solver = 'gurobi';
    default_options.verbose = 1;             % 0 silent | 1 summary | 2 detailed | 3 very detailed
    default_options.gap_tol = 1e-4;
    default_options.max_iterations = 50;
    default_options.perspective = 'TRO';     % Placeholder for future robust types
    
    % Parameters for the 'quick' method (L1-PADM based)
    default_options.penalty_rho = 100;        % Initial penalty factor for the PADM algorithm
    default_options.penalty_term_gap = 1e-4; % Tolerance for the penalty term to be considered zero
    default_options.rho_tolerance = 1;       % Relative tolerance for penalty rho search (currently unused)
    default_options.padm_tolerance = 1e-3;   % Convergence tolerance for the PADM algorithm
    default_options.padm_max_iter = 100;     % Max iterations for the PADM algorithm

    % Plot settings
    default_options.plot.saveFig = false;     % Whether to save figure
    default_options.plot.figFormat = {'png', 'eps', 'fig'}; % Save formats
    default_options.plot.style = 'paper';    % 'paper' or 'screen'
    default_options.plot.verbose = 0;        % 0=no plot, 1=final plot, 2=real-time plot
    default_options.plot.saveDir = 'results/figures/'; % Directory to save figures

    % --- Initialize with defaults ---
    options = default_options;
    options.custom_params = struct();

    % --- Process user-defined parameters ---
    if nargin > 0
        for i = 1:2:nargin
            paramName = varargin{i};
            paramValue = varargin{i+1};

            % Handle nested parameters like 'plot.verbose'
            if contains(paramName, '.')
                parts = strsplit(paramName, '.');
                if numel(parts) == 2
                    parent = parts{1}; child = parts{2};
                    if ~isfield(options, parent)
                        options.(parent) = struct();
                    end
                    options.(parent).(child) = paramValue;

                    changed = true;
                    if isfield(default_options, parent) && isfield(default_options.(parent), child)
                        changed = ~isequaln(default_options.(parent).(child), paramValue);
                    end
                    if changed
                        options.custom_params.(strrep(paramName,'.','__')) = paramValue;
                    end
                    continue;
                else
                    warning('RobustCCG:Settings','Unsupported nested parameter: %s',paramName);
                end
            else
                % Record non-default parameters
                if isfield(default_options, paramName)
                    if ~isequaln(default_options.(paramName), paramValue)
                        options.custom_params.(strrep(paramName,'.','__')) = paramValue;
                    end
                else
                    options.custom_params.(strrep(paramName,'.','__')) = paramValue;
                    warning('RobustCCG:Settings', 'Non-standard parameter added: %s', paramName);
                end
                options.(paramName) = paramValue;
            end
        end
    end

    % --- Build YALMIP solver settings ---
    solverVerbose = 0;
    if options.verbose >= 3
        solverVerbose = 1; % Only expose solver logs in debug mode
    end
    options.ops_MP = sdpsettings('solver', options.solver, 'verbose', solverVerbose);
    options.ops_SP = sdpsettings('solver', options.solver, 'verbose', solverVerbose);
end