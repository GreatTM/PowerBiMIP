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
clear; close all; clc; 
yalmip('clear');

%% 2. Variable Definition using YALMIP
% It's good practice to group all variables in a single struct.
model.var_upper.x = intvar(1,1,'full'); % Upper-level integer variable
model.var_lower.z = intvar(1,1,'full'); % Lower-level integer variable
model.var_lower.y = sdpvar(4,1,'full'); % Lower-level continuous variables

%% 3. Model Formulation
% --- Upper-Level Constraints ---
model.cons_upper = [];
model.cons_upper = model.cons_upper + ...
    (model.var_upper.x >= 0);
model.cons_upper = model.cons_upper + ...
    (-25 * model.var_upper.x + 20 * model.var_lower.z <= 30);
model.cons_upper = model.cons_upper + ...
    (model.var_upper.x + 2 * model.var_lower.z <= 10);
model.cons_upper = model.cons_upper + ...
    (2 * model.var_upper.x - model.var_lower.z <= 15);
model.cons_upper = model.cons_upper + ...
    (2 * model.var_upper.x + 10 * model.var_lower.z >= 15);

% --- Lower-Level Constraints ---
model.cons_lower = [];
model.cons_lower = model.cons_lower + ...
    (-25 * model.var_upper.x + 20 * model.var_lower.z <= 30 + model.var_lower.y(1,1) );
model.cons_lower = model.cons_lower + ...
    (model.var_upper.x + 2 * model.var_lower.z <= 10 + model.var_lower.y(2,1) );
model.cons_lower = model.cons_lower + ...
    (2 * model.var_upper.x - model.var_lower.z <= 15 + model.var_lower.y(3,1) );
model.cons_lower = model.cons_lower + ...
    (2 * model.var_upper.x + 10 * model.var_lower.z >= 15 - model.var_lower.y(4,1) );
model.cons_lower = model.cons_lower + ...
    (model.var_lower.z >= 0);
model.cons_lower = model.cons_lower + ...
    (model.var_lower.y >= 0);

% --- Objective Functions ---
% Note: Maximization problems should be converted to minimization problems 
% by negating the objective function.
model.obj_upper = -model.var_upper.x - 10 * model.var_lower.z;
model.obj_lower = model.var_lower.z + 1e3 * sum(model.var_lower.y,'all');

%% 4. Configure and Run the Solver
% Configure PowerBiMIP settings
ops = BiMIPsettings( ...
    'perspective', 'optimistic', ...    % Perspective: 'optimistic' or 'pessimistic'
    'method', 'exact_KKT', ...                % Method: 'exact_KKT', 'exact_strong_duality', or 'quick'
    'solver', 'gurobi', ...             % Specify the underlying MIP solver
    'verbose', 2, ...                   % Verbosity level [0:silent, 1:summary, 2:summary+plots]
    'max_iterations', 10, ...           % Set the maximum number of iterations
    'optimal_gap', 1e-4, ...             % Set the desired optimality gap
    'plot.verbose', 0, ...
    'plot.saveFig', true ...
    );

% Call the main solver function
[Solution, BiMIP_record] = solve_BiMIP(model, ops);