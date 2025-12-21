%==========================================================================
% PowerBiMIP Example: Two-Stage Robust Optimization (TRO-LP)
% Robust Facility Location-Transportation Problem
%==========================================================================
%
% NOTE: Please ensure the PowerBiMIP toolbox is added to your MATLAB path 
%       before running this script (use "Add to Path" -> "Selected Folders 
%       and Subfolders").
%
% This script demonstrates how to model and solve a two-stage robust
% optimization problem with linear programming recourse (TRO-LP) using
% the PowerBiMIP toolbox.
%
%--------------------------------------------------------------------------
% Mathematical Formulation
%--------------------------------------------------------------------------
%
% This is a classic two-stage robust optimization problem from:
% Zeng, Bo, and Long Zhao. "Solving two-stage robust optimization problems 
% using a column-and-constraint generation method." Operations Research 
% Letters 41.5 (2013): 457-461.
%
% Problem: Robust Facility Location-Transportation Problem
%
% First-Stage Problem:
%   min_{y,z}  sum_i (f_i*y_i + c_i*z_i) + max_{d in D} min_{x >= 0} sum_{i,j} t_{ij}*x_{ij}
%   s.t.
%       z_i <= 800*y_i,           for all i = 0, 1, 2
%       y_i in {0, 1},            for all i = 0, 1, 2
%       z_i >= 0,                 for all i = 0, 1, 2
%       z_i >= 772,               for all i = 0, 1, 2
% Second-Stage Problem (for given y, z, d):
%   min_{x >= 0}  sum_{i,j} t_{ij}*x_{ij}
%   s.t.
%       sum_j x_{ij} <= z_i,      for all i = 0, 1, 2
%       sum_i x_{ij} >= d_j,      for all j = 0, 1, 2
%
% Uncertainty Set D:
%   d_0 = 206 + 40*g_0
%   d_1 = 274 + 40*g_1
%   d_2 = 220 + 40*g_2
%   0 <= g_j <= 1,                for all j = 0, 1, 2
%   g_0 + g_1 + g_2 <= 1.8
%   g_0 + g_1 <= 1.2
%
% Parameters:
%   Fixed costs: f = [400, 414, 326]
%   Capacity costs: c = [18, 25, 20]
%   Transportation cost matrix:
%       T = [22  33  24;
%            33  23  30;
%            20  25  27]
%
% Variables:
%   - y_i: Binary variables (first-stage), whether to open facility at location i
%   - z_i: Continuous variables (first-stage), capacity at facility i
%   - g_j: Uncertainty variables, auxiliary variables for demand uncertainty
%   - d_j: Demand parameters (derived from g_j: d_j = d_j_nominal + 40*g_j)
%   - x_{ij}: Continuous variables (second-stage), transportation from facility i to demand point j
%
% Known Optimal Solution:
%   Objective value: 33680
%
%--------------------------------------------------------------------------

%% 1. Initialization
dbstop if error;
clear; close all; clc; 
yalmip('clear');

%% 2. Problem Parameters
% Fixed costs for opening facilities
f = [400; 414; 326];
% Capacity costs per unit
c = [18; 25; 20];
% Transportation cost matrix (facility i -> demand j)
T = [22, 33, 24;
     33, 23, 30;
     20, 25, 27];
% Nominal demand values
d_nominal = [206; 274; 220];

n_facilities = 3;
n_demands = 3;
capacity_limit = 800;

%% 3. Variable Definition (Directly into tro_model)
% First-stage variables
model.var_1st.y = binvar(n_facilities, 1, 'full'); 
model.var_1st.z = sdpvar(n_facilities, 1, 'full');

% Uncertainty variables
model.var_uncertain = sdpvar(n_demands, 1, 'full');    

% Second-stage variables
model.var_2nd.x = sdpvar(n_facilities, n_demands, 'full'); 

%% 4. Model Formulation

% --- First-Stage Constraints ---
% Use tro_model.var_1st fields directly
model.cons_1st = [];
model.cons_1st = model.cons_1st + (model.var_1st.z >= 0); 
model.cons_1st = model.cons_1st + (sum(model.var_1st.z) >= 772); 

for i = 1:n_facilities
    model.cons_1st = model.cons_1st + ...
        (model.var_1st.z(i) <= capacity_limit * model.var_1st.y(i));
end

% --- Second-Stage Constraints ---
% Use tro_model.var_2nd.x, tro_model.var_1st, and tro_model.var_uncertain
model.cons_2nd = [];
model.cons_2nd = model.cons_2nd + ...
    (model.var_2nd.x(:) >= 0);

% Capacity limit per facility (Recourse constraint)
for i = 1:n_facilities
    model.cons_2nd = model.cons_2nd + ...
        (sum(model.var_2nd.x(i, :)) <= model.var_1st.z(i));
end

% Demand satisfaction (Recourse constraint with Uncertainty)
for j = 1:n_demands
    % Demand d_j depends on tro_model.var_uncertain(j)
    d_j = d_nominal(j) + 40 * model.var_uncertain(j); 
    model.cons_2nd = model.cons_2nd + ...
        (sum(model.var_2nd.x(:, j)) >= d_j);
end

% --- Uncertainty Set Constraints ---
model.cons_uncertainty = [];
model.cons_uncertainty = model.cons_uncertainty + ...
    (model.var_uncertain >= 0);
model.cons_uncertainty = model.cons_uncertainty + ...
    (model.var_uncertain <= 1);
model.cons_uncertainty = model.cons_uncertainty + (sum(model.var_uncertain) <= 1.8);
model.cons_uncertainty = model.cons_uncertainty + (model.var_uncertain(1) + model.var_uncertain(2) <= 1.2);

% --- Objective Functions ---
model.obj_1st = f' * model.var_1st.y + c' * model.var_1st.z;
model.obj_2nd = sum(sum(T .* model.var_2nd.x));

%% 6. Configure and Run the Solver
ops = TROsettings( ...
    'mode', 'exact_KKT', ...          % 'exact_KKT' (Strong Duality) or 'quick'
    'solver', 'gurobi', ...           % Underlying solver
    'verbose', 2, ...                 % 0: Silent, 1: Summary, 2: Detailed
    'gap_tol', 1e-4, ...              % Convergence tolerance
    'max_iterations', 50, ...
    'plot.verbose', 1 ...
    );

u_init = []; 

% --- SOLVE ---
fprintf('Solving Robust Facility Location Problem...\n');
[Solution, Robust_record] = solve_TRO(model, ops, u_init);

%% 7. Analyze Results
if ~isempty(Solution.obj)
    fprintf('\nOptimal Objective: %.4f\n', Solution.obj);
    
    % Access results using value() on the variables stored in the struct
    % (The solver assigns values back to these original sdpvar objects)
    y_opt = value(model.var_1st.y);
    z_opt = value(model.var_1st.z);
    
    fprintf('Facility Decisions:\n');
    for i = 1:n_facilities
        if y_opt(i) > 0.5
            fprintf('  Facility %d: OPEN (Capacity: %.2f)\n', i, z_opt(i));
        else
            fprintf('  Facility %d: CLOSED\n', i);
        end
    end
else
    fprintf('\nSolver failed or infeasible.\n');
end