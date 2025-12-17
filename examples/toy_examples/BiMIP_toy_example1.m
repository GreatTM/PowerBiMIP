%==========================================================================
% PowerBiMIP Example: A Simple Bilevel Mixed-Integer Linear Program
%==========================================================================
%
% NOTE: Please ensure the PowerBiMIP toolbox is added to your MATLAB path 
%       before running this script (use "Add to Path" -> "Selected Folders 
%       and Subfolders").
%
% This script demonstrates how to model and solve a bilevel optimization 
% problem using the PowerBiMIP toolbox.
%
%--------------------------------------------------------------------------
% Mathematical Formulation
%--------------------------------------------------------------------------
%
% Upper-Level Problem:
%   min_{x}  -x - 10*z
%   s.t.
%       x >= 0
%       -25*x + 20*z <= 30
%       x   + 2*z  <= 10
%       2*x - z    <= 15
%       2*x + 10*z >= 15
%
%   Where z is determined by the solution of the Lower-Level Problem:
%
%   min_{y,z}  z + 1000 * sum(y)
%   s.t.
%       -25*x + 20*z <= 30 + y(1)
%       x   + 2*z  <= 10 + y(2)
%       2*x - z    <= 15 + y(3)
%       2*x + 10*z >= 15 - y(4)
%       z >= 0
%       y >= 0
%
% Variables:
%   - x: Upper-level integer variable
%   - z: Lower-level integer variable
%   - y: Lower-level continuous variables
%
% Known Optimal Solution:
%   x = 2, z = 2, upper-level objective = -22
%
%--------------------------------------------------------------------------

%% 1. Initialization
dbstop if error;
clear; close all; clc; yalmip('clear');

%% 2. Variable Definition using YALMIP
% It's good practice to group all variables in a single struct.
model.var.x = intvar(1,1,'full'); % Upper-level integer variable
model.var.z = intvar(1,1,'full'); % Lower-level integer variable
model.var.y = sdpvar(4,1,'full'); % Lower-level continuous variables

%% 3. Model Formulation
% --- Upper-Level Constraints ---
model.constraints_upper = [];
model.constraints_upper = model.constraints_upper + ...
    (model.var.x >= 0);
model.constraints_upper = model.constraints_upper + ...
    (-25 * model.var.x + 20 * model.var.z <= 30);
model.constraints_upper = model.constraints_upper + ...
    (model.var.x + 2 * model.var.z <= 10);
model.constraints_upper = model.constraints_upper + ...
    (2 * model.var.x - model.var.z <= 15);
model.constraints_upper = model.constraints_upper + ...
    (2 * model.var.x + 10 * model.var.z >= 15);

% --- Lower-Level Constraints ---
model.constraints_lower = [];
model.constraints_lower = model.constraints_lower + ...
    (-25 * model.var.x + 20 * model.var.z <= 30 + model.var.y(1,1) );
model.constraints_lower = model.constraints_lower + ...
    (model.var.x + 2 * model.var.z <= 10 + model.var.y(2,1) );
model.constraints_lower = model.constraints_lower + ...
    (2 * model.var.x - model.var.z <= 15 + model.var.y(3,1) );
model.constraints_lower = model.constraints_lower + ...
    (2 * model.var.x + 10 * model.var.z >= 15 - model.var.y(4,1) );
model.constraints_lower = model.constraints_lower + ...
    (model.var.z >= 0);
model.constraints_lower = model.constraints_lower + ...
    (model.var.y >= 0);

% --- Objective Functions ---
% Note: Maximization problems should be converted to minimization problems 
% by negating the objective function.
model.objective_upper = -model.var.x - 10 * model.var.z;
model.objective_lower = model.var.z + 1e3 * sum(model.var.y,'all');

%% 4. Define Variable Sets for the Solver
% This step is crucial for PowerBiMIP to understand the model structure.
% - 'u' denotes upper-level, 'l' denotes lower-level.
% - 'x' denotes continuous variables (sdpvar), 'z' denotes integer variables (intvar/binvar).

model.var_xu = []; % Upper-level continuous variables
model.var_zu = [reshape(model.var.x, [], 1)]; % Upper-level integer variables
model.var_xl = [reshape(model.var.y, [], 1)]; % Lower-level continuous variables
model.var_zl = [reshape(model.var.z, [], 1)]; % Lower-level integer variables

%% 5. Configure and Run the Solver
% Configure PowerBiMIP settings
ops = BiMIPsettings( ...
    'perspective', 'optimistic', ...    % Perspective: 'optimistic' or 'pessimistic'
    'method', 'quick', ...                % Method: 'exact_KKT', 'exact_strong_duality', or 'quick'
    'solver', 'gurobi', ...             % Specify the underlying MIP solver
    'verbose', 2, ...                   % Verbosity level [0:silent, 1:summary, 2:summary+plots]
    'max_iterations', 10, ...           % Set the maximum number of iterations
    'optimal_gap', 1e-4 ...             % Set the desired optimality gap
    );

% Call the main solver function
[Solution, BiMIP_record] = solve_BiMIP(model.var, ...
    model.var_xu, model.var_zu, model.var_xl, model.var_zl, ...
    model.constraints_upper, model.constraints_lower, ...
    model.objective_upper, model.objective_lower, ops);