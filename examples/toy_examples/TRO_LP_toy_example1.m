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
%
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
clear; close all; clc; yalmip('clear');

%% 2. Problem Parameters
% Fixed costs for opening facilities
f = [400; 414; 326];

% Capacity costs per unit
c = [18; 25; 20];

% Transportation cost matrix (from facility i to demand point j)
T = [22, 33, 24;
     33, 23, 30;
     20, 25, 27];

% Nominal demand values
d_nominal = [206; 274; 220];

% Number of facilities and demand points
n_facilities = 3;
n_demands = 3;
capacity_limit = 800;

%% 3. Variable Definition using YALMIP
% First-stage variables
model.var.y = binvar(n_facilities, 1, 'full');  % Binary: whether to open facility i
model.var.z = sdpvar(n_facilities, 1, 'full');  % Continuous: capacity at facility i

% Uncertainty variables (auxiliary variables g for demand uncertainty)
model.var.g = sdpvar(n_demands, 1, 'full');     % Uncertainty variables g_j

% Second-stage variables
model.var.x = sdpvar(n_facilities, n_demands, 'full');  % Transportation from i to j

%% 4. Model Formulation
% --- First-Stage Constraints ---
model.cons.cons_1st = [];
% Capacity constraint: z_i <= 800*y_i
for i = 1:n_facilities
    model.cons.cons_1st = model.cons.cons_1st + (model.var.z(i) <= capacity_limit * model.var.y(i));
end

model.cons.cons_1st = model.cons.cons_1st + (model.var.z(:) >= 0);

% --- Second-Stage Constraints ---
model.cons.cons_2nd = [];
% Capacity constraint: sum_j x_{ij} <= z_i
for i = 1:n_facilities
    model.cons.cons_2nd = model.cons.cons_2nd + (sum(model.var.x(i, :)) <= model.var.z(i));
end

% Demand satisfaction: sum_i x_{ij} >= d_j, where d_j = d_nominal_j + 40*g_j
for j = 1:n_demands
    d_j = d_nominal(j) + 40 * model.var.g(j);  % Demand parameter as function of uncertainty
    model.cons.cons_2nd = model.cons.cons_2nd + (sum(model.var.x(:, j)) >= d_j);
end

% Non-negativity: x_{ij} >= 0
model.cons.cons_2nd = model.cons.cons_2nd + (model.var.x(:) >= 0);

% --- Uncertainty Set Constraints ---
model.cons.cons_uncertainty = [];
% Bounds on g: 0 <= g_j <= 1
model.cons.cons_uncertainty = model.cons.cons_uncertainty + (model.var.g >= 0);
model.cons.cons_uncertainty = model.cons.cons_uncertainty + (model.var.g <= 1);

% Budget constraints: g_0 + g_1 + g_2 <= 1.8
model.cons.cons_uncertainty = model.cons.cons_uncertainty + (sum(model.var.g) <= 1.8);

% Additional constraint: g_0 + g_1 <= 1.2
model.cons.cons_uncertainty = model.cons.cons_uncertainty + (model.var.g(1) + model.var.g(2) <= 1.2);

% --- Objective Functions ---
% First-stage objective: sum_i (f_i*y_i + c_i*z_i)
model.obj.obj_1st = f' * model.var.y + c' * model.var.z;

% Second-stage objective: sum_{i,j} t_{ij}*x_{ij}
model.obj.obj_2nd = sum(sum(T .* model.var.x));

%% 6. Configure and Run the Solver
% Configure Robust C&CG settings
ops = RobustCCGsettings( ...
    'mode', 'exact', ...              % Subproblem mode: 'exact' (strong_duality) or 'quick'
    'solver', 'gurobi', ...           % Underlying MIP solver
    'verbose', 2, ...                 % Verbosity level [0:silent, 1:summary, 2:detailed, 3:very detailed]
    'gap_tol', 1e-4, ...             % Optimality gap tolerance
    'max_iterations', 50 ...         % Maximum iterations
    );

% Optional: Provide initial uncertainty scenario
% If u_init is provided, the first iteration will include this scenario
% If u_init is empty or not provided, the first iteration will not include eta
u_init = [0.5; 0.5; 0.5];  % Initial scenario: g = [0.5, 0.5, 0.5]
% u_init = [];  % Uncomment to test without initial scenario

% Call the main solver function
fprintf('\n==========================================================================\n');
fprintf('Solving Two-Stage Robust Optimization Problem\n');
fprintf('==========================================================================\n');
if ~isempty(u_init)
    fprintf('Using initial uncertainty scenario: g = [%.2f, %.2f, %.2f]\n', u_init(1), u_init(2), u_init(3));
else
    fprintf('No initial uncertainty scenario provided (first iteration without eta)\n');
end
fprintf('==========================================================================\n\n');

[Solution, Robust_record] = solve_Robust(model.var, ...
    model.var.z, model.var.y, model.var.x(:), [], model.var.g, ...
    model.cons.cons_1st, model.cons.cons_2nd, model.cons.cons_uncertainty, ...
    model.obj.obj_1st, model.obj.obj_2nd, ops, u_init);

%% 7. Display Results
fprintf('\n==========================================================================\n');
fprintf('Solution Summary\n');
fprintf('==========================================================================\n');

% Display optimal objective value
fprintf('Optimal Objective Value: %.4f\n', Solution.obj);
fprintf('Reference Value (from paper): ~33680\n');
fprintf('Relative Error: %.2f%%\n', abs(Solution.obj - 33680) / 33680 * 100);

% Display first-stage decisions
fprintf('\nFirst-Stage Decisions:\n');
fprintf('  Facility Opening (y):\n');
for i = 1:n_facilities
    if isfield(Solution.var, 'y') && length(Solution.var.y) >= i
        fprintf('    Facility %d: y_%d = %d\n', i-1, i-1, Solution.var.y(i));
    elseif isfield(Solution.var, 'var_z_1st') && length(Solution.var.var_z_1st) >= i
        fprintf('    Facility %d: y_%d = %d\n', i-1, i-1, Solution.var.var_z_1st(i));
    else
        y_val = value(model.var.y(i));
        fprintf('    Facility %d: y_%d = %d\n', i-1, i-1, round(y_val));
    end
end

fprintf('  Facility Capacity (z):\n');
for i = 1:n_facilities
    if isfield(Solution.var, 'z') && length(Solution.var.z) >= i
        fprintf('    Facility %d: z_%d = %.2f\n', i-1, i-1, Solution.var.z(i));
    elseif isfield(Solution.var, 'var_x_1st') && length(Solution.var.var_x_1st) >= i
        fprintf('    Facility %d: z_%d = %.2f\n', i-1, i-1, Solution.var.var_x_1st(i));
    else
        z_val = value(model.var.z(i));
        fprintf('    Facility %d: z_%d = %.2f\n', i-1, i-1, z_val);
    end
end

% Display worst-case scenario
fprintf('\nWorst-Case Scenario (from last iteration):\n');
if ~isempty(Robust_record.worst_case_u_history)
    last_g = Robust_record.worst_case_u_history{end};
    fprintf('  g = [%.4f, %.4f, %.4f]\n', last_g(1), last_g(2), last_g(3));
    last_d = d_nominal + 40 * last_g;
    fprintf('  d = [%.2f, %.2f, %.2f]\n', last_d(1), last_d(2), last_d(3));
end

% Display convergence information
fprintf('\nConvergence Information:\n');
fprintf('  Total Iterations: %d\n', Robust_record.cuts_count + 1);
fprintf('  Total Runtime: %.3f seconds\n', Robust_record.runtime);
if isfield(Robust_record, 'convergence_trace') && ~isempty(Robust_record.convergence_trace.gap)
    final_gap = Robust_record.convergence_trace.gap(end);
    fprintf('  Final Gap: %.4f%%\n', final_gap * 100);
    fprintf('  Lower Bound: %.4f\n', Robust_record.LB);
    fprintf('  Upper Bound: %.4f\n', Robust_record.UB);
end

% Display second-stage transportation solution (if available)
fprintf('\nSecond-Stage Transportation Solution (x_{ij}):\n');
x_val = value(model.var.x);
for i = 1:n_facilities
    fprintf('  From Facility %d: ', i-1);
    for j = 1:n_demands
        fprintf('x_%d%d = %.2f  ', i-1, j-1, x_val(i, j));
    end
    fprintf('\n');
end

fprintf('\n==========================================================================\n');

%% 8. Verification
% Verify that constraints are satisfied
fprintf('\nConstraint Verification:\n');
y_val = value(model.var.y);
z_val = value(model.var.z);
x_val = value(model.var.x);
g_val = value(model.var.g);
d_val = d_nominal + 40 * g_val;

% Check first-stage constraints
fprintf('  First-stage constraints:\n');
for i = 1:n_facilities
    lhs = z_val(i);
    rhs = capacity_limit * y_val(i);
    if lhs <= rhs + 1e-6
        fprintf('    z_%d <= 800*y_%d: %.2f <= %.2f [OK]\n', i-1, i-1, lhs, rhs);
    else
        fprintf('    z_%d <= 800*y_%d: %.2f <= %.2f [VIOLATED!]\n', i-1, i-1, lhs, rhs);
    end
end

% Check second-stage constraints
fprintf('  Second-stage constraints:\n');
for i = 1:n_facilities
    lhs = sum(x_val(i, :));
    rhs = z_val(i);
    if lhs <= rhs + 1e-6
        fprintf('    sum_j x_%dj <= z_%d: %.2f <= %.2f [OK]\n', i-1, i-1, lhs, rhs);
    else
        fprintf('    sum_j x_%dj <= z_%d: %.2f <= %.2f [VIOLATED!]\n', i-1, i-1, lhs, rhs);
    end
end

for j = 1:n_demands
    lhs = sum(x_val(:, j));
    rhs = d_val(j);
    if lhs >= rhs - 1e-6
        fprintf('    sum_i x_i%d >= d_%d: %.2f >= %.2f [OK]\n', j-1, j-1, lhs, rhs);
    else
        fprintf('    sum_i x_i%d >= d_%d: %.2f >= %.2f [VIOLATED!]\n', j-1, j-1, lhs, rhs);
    end
end

% Check uncertainty set constraints
fprintf('  Uncertainty set constraints:\n');
if all(g_val >= -1e-6) && all(g_val <= 1 + 1e-6)
    fprintf('    0 <= g_j <= 1: [OK]\n');
else
    fprintf('    0 <= g_j <= 1: [VIOLATED!]\n');
end

if sum(g_val) <= 1.8 + 1e-6
    fprintf('    g_0 + g_1 + g_2 <= 1.8: %.4f <= 1.8 [OK]\n', sum(g_val));
else
    fprintf('    g_0 + g_1 + g_2 <= 1.8: %.4f <= 1.8 [VIOLATED!]\n', sum(g_val));
end

if g_val(1) + g_val(2) <= 1.2 + 1e-6
    fprintf('    g_0 + g_1 <= 1.2: %.4f <= 1.2 [OK]\n', g_val(1) + g_val(2));
else
    fprintf('    g_0 + g_1 <= 1.2: %.4f <= 1.2 [VIOLATED!]\n', g_val(1) + g_val(2));
end

fprintf('\n==========================================================================\n');
fprintf('Example completed successfully!\n');
fprintf('==========================================================================\n');

