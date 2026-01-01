% RUN_TEP_BIMIP_CASE118  Solve the IEEE-118 bus Transmission Expansion
%Planning problem (Haghighat & Zeng 2018) using PowerBiMIP.
%
%   This script builds the bilevel MIP model with
%   build_TEP_BiMIP_case118(), then calls solve_BiMIP() with default
%   settings and prints a concise summary of the solution.
%
%   The exact-KKT method is automatically selected by solve_BiMIP based on
%   problem structure.
%
%   Author: Cursor-AI (generated)
%
% -------------------------------------------------------------------------

%% Prepare environment
clearvars; clc;
% import yalmip.*  % Often not needed if YALMIP is in path, avoids shadowing warnings

% Ensure MATPOWER is on path
if exist('makePTDF','file')~=2
    error('MATPOWER functions not found. Please add MATPOWER to MATLAB path.');
end

%% Clear YALMIP workspace to avoid ghost variables from previous runs
yalmip('clear');

%% Build bilevel model
fprintf('Building TEP model for IEEE-118 (Haghighat & Zeng 2018)...\n');
bimip_model = build_TEP_BiMIP_case118();

%% Options
ops = BiMIPsettings();
ops.verbose = 2;  % Print convergence details

%% Solve
fprintf('Solving Bilevel MIP...\n');
[Solution, record] = solve_BiMIP(bimip_model, ops); %#ok<NASGU>

%% Display planner decisions
x_val = value(bimip_model.var_upper.x);
% Define candidate list order matching the build function
candidates_data = [
    25   4   5.0;
    25  18   5.0;
    86  82   5.0;
    77  82   5.0;
    77  78   5.0;
    94  95   5.0;
    99 100   5.0;
    94 100   5.0;
    94  96   5.0;
];
candLines = candidates_data(:,1:2);
costs     = candidates_data(:,3);

fprintf('\n=== Transmission Expansion Decisions ===\n');
built_cost = 0;
for k = 1:length(x_val)
    if round(x_val(k))==1
        status = 'BUILT';
        built_cost = built_cost + costs(k);
        fprintf('  Line %d (%d-%d): %s (Cost: %.1f M$)\n', ...
            k, candLines(k,1), candLines(k,2), status, costs(k));
    else
        fprintf('  Line %d (%d-%d): NOT built\n', k, candLines(k,1), candLines(k,2));
    end
end

fprintf('\nTotal investment cost: %.2f M$\n', built_cost);
fprintf('Note: Exact match with paper depends on unknown line parameters/costs.\n');

% --- Detailed Solution Analysis ---
fprintf('\n=== Detailed Operational Analysis ===\n');
% Extract lower level solution
p_val = value(bimip_model.var_lower.p);
r_val = value(bimip_model.var_lower.r);
v_val = value(bimip_model.var_lower.v);

% Check load shedding
total_shedding = sum(sum(r_val));
fprintf('Total Load Shedding across all scenarios: %.4f MW\n', total_shedding);

% Check generation
fprintf('Total Generation: %.2f MW\n', sum(sum(p_val)));
fprintf('Number of committed generators (sum of v): %d\n', sum(sum(round(v_val))));

% Check cost components roughly
cg = 40; % Assuming approx linear cost
cnl = 40;
fuel_cost = sum(sum(p_val)) * cg;
shed_cost = total_shedding * 1e4;
fprintf('Approx Fuel Cost: %.2e $\n', fuel_cost);
fprintf('Approx Shedding Penalty: %.2e $\n', shed_cost);
