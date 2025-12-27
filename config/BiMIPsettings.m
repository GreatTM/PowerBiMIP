function options = BiMIPsettings(varargin)
%BIMIPSETTINGS Creates an options struct for the PowerBiMIP solver.
%
%   options = BiMIPsettings('param1', value1, 'param2', value2, ...)
%
%   Description:
%       This function creates a default options structure for the PowerBiMIP
%       solver and overrides it with any user-specified parameter-value pairs.
%
%   Output:
%       options - A struct containing the complete set of options for the solver.

    % --- Default parameter settings ---
    default_options = struct();
    
    % Perspective of the bilevel problem
    default_options.perspective = 'optimistic';   % ['optimistic'|'pessimistic']
    
    % Main algorithm parameters
    default_options.method = 'exact_KKT';          % Solution method ['exact_KKT'|'exact_strong_duality'|'quick']
    default_options.max_iterations = 10;     % Max iterations for the main algorithm
    default_options.optimal_gap = 0.01;      % Optimality gap tolerance (e.g., 0.01 for 1%)
    default_options.kappa = 50;              % Penalty factor for transforming coupled constraints

    % Parameters for the 'quick' method (L1-PADM based)
    default_options.penalty_rho = 50;        % Initial penalty factor for the PADM algorithm
    default_options.penalty_term_gap = 1e-4; % Tolerance for the penalty term to be considered zero
    default_options.rho_tolerance = 1;       % Relative tolerance for penalty rho search (currently unused)
    default_options.padm_tolerance = 1e-3;   % Convergence tolerance for the PADM algorithm
    default_options.padm_max_iter = 100;     % Max iterations for the PADM algorithm
    
    % Output and Logging
    default_options.verbose = 1;             % Verbosity level [0: silent | 1: summary | 2: detailed | 3: very detailed]
    
    % Plot settings
    default_options.plot.saveFig = false;     % Whether to save figure
    default_options.plot.figFormat = {'png', 'eps', 'fig'}; % Save formats
    default_options.plot.style = 'paper';    % 'paper' or 'screen'
    default_options.plot.verbose = 0;        % 0=no plot, 1=final plot, 2=real-time plot
    default_options.plot.saveDir = 'results/figures/'; % Directory to save figures

    % Initial value for PADM
    default_options.initial_value_flag = false;
    default_options.initial_value_A_l_vars = [];
    default_options.initial_value_B_l_vars = [];
    default_options.initial_value_E_l_vars = [];
    default_options.initial_value_F_l_vars = [];
    
    % Solver settings
    default_options.solver = 'gurobi';       % Choose MIP solver
    
    % --- Initialize options and process user inputs ---
    
    % Initialize options with default values
    options = default_options;
    
    % Process user-defined parameters
    options.custom_params = struct();
    if nargin > 0
        for i = 1:2:nargin
            param_name = varargin{i};
            param_value = varargin{i+1};
            
            % Handle nested parameters like 'plot.verbose'
            if contains(param_name, '.')
                parts = strsplit(param_name, '.');
                if numel(parts) == 2
                    parent = parts{1}; child = parts{2};
                    % Ensure parent struct exists
                    if ~isfield(options, parent)
                        options.(parent) = struct();
                    end
                    options.(parent).(child) = param_value;

                    % Determine if this overrides a default value
                    changed = true;
                    if isfield(default_options, parent) && isfield(default_options.(parent), child)
                        changed = ~isequaln(default_options.(parent).(child), param_value);
                    end
                    if changed
                        options.custom_params.(strrep(param_name,'.','__')) = param_value;
                    end
                    continue; % Skip generic handling below
                else
                    warning('PowerBiMIP:Settings','Unsupported nested parameter: %s',param_name);
                end
            else
                % Record non-default parameters for summary display
                if isfield(default_options, param_name)
                    if ~isequaln(default_options.(param_name), param_value)
                        options.custom_params.(strrep(param_name,'.','__')) = param_value;
                    end
                else
                    options.custom_params.(strrep(param_name,'.','__')) = param_value;
                    warning('PowerBiMIP:Settings', 'Non-standard parameter added: %s', param_name);
                end
                options.(param_name) = param_value;
            end
        end
    end
    
    % Automatically generate solver settings for YALMIP based on user choices
    solverVerbose = 0;
    if options.verbose >= 3
        solverVerbose = 1; % Expose solver logs only in debug mode
    end
    options.ops_MP  = sdpsettings('solver', options.solver, 'verbose', solverVerbose);
    options.ops_SP1 = sdpsettings('solver', options.solver, 'verbose', solverVerbose);
    options.ops_SP2 = sdpsettings('solver', options.solver, 'verbose', solverVerbose);
end