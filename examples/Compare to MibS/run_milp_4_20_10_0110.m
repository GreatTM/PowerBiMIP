% Run MibS benchmark instance milp_4_20_10_0110 using PowerBiMIP
%
% This script demonstrates how to load a MibS formatted instance and solve it
% using the PowerBiMIP toolbox.

clear; clc;

%% 1. Setup Paths
% Get the directory of this script
base_dir = fileparts(mfilename('fullpath'));
% Construct paths to the data files
mps_file = fullfile(base_dir, 'MibSdata', 'notInterdiction', 'milp_4_20_10_0110.mps');
txt_file = fullfile(base_dir, 'MibSdata', 'notInterdiction', 'milp_4_20_10_0110.txt');

% Check if files exist
if ~exist(mps_file, 'file')
    error('MPS file not found: %s', mps_file);
end
if ~exist(txt_file, 'file')
    error('TXT file not found: %s', txt_file);
end

%% 2. Load Instance
fprintf('Loading MibS instance: %s...\n', 'milp_4_20_10_0110');
try
    model_mibs = loadMibSInstance(mps_file, txt_file);
    fprintf('Instance loaded successfully.\n');
catch ME
    fprintf('Error loading instance: %s\n', ME.message);
    return;
end

%% 3. Configure Solver
% Initialize solver settings
ops = BiMIPsettings(...
    'method', 'exact_KKT', ...      % Use Exact KKT method as requested
    'solver', 'cbc', ...            % Use CBC
    'verbose', 2, ...               % Show detailed output and convergence plot
    'max_iterations', 50, ...       % Set iteration limit
    'optimal_gap', 1e-4 ...         % Convergence tolerance
);

%% 4. Solve Problem
fprintf('Starting solver...\n');
try
    [Solution, BiMIP_record] = solve_BiMIP(...
        model_mibs.original_var, ...
        model_mibs.var_x_u, model_mibs.var_z_u, ...
        model_mibs.var_x_l, model_mibs.var_z_l, ...
        model_mibs.cons_upper, model_mibs.cons_lower, ...
        model_mibs.obj_upper, model_mibs.obj_lower, ...
        ops);
        
    fprintf('\nSolver finished.\n');
    fprintf('Optimal Objective: %.4f\n', Solution.obj);
    fprintf('Iterations: %d\n', BiMIP_record.iteration_num);
    
catch ME
    fprintf('Solver failed: %s\n', ME.message);
    % Print stack trace for debugging
    for k = 1:length(ME.stack)
        fprintf('File: %s, Line: %d, Name: %s\n', ...
            ME.stack(k).file, ME.stack(k).line, ME.stack(k).name);
    end
end
