% Run MibS benchmark instance milp_4_20_10_0110 using PowerBiMIP
% Known Optimal Solution:
%   Objective value: -375

dbstop if error;
clear; close all; clc; 
yalmip('clear');

%% 1. Setup Paths
% Get the directory of this script
base_dir = fileparts(mfilename('fullpath'));

% Construct paths to the data files (Assumed to be in the same directory)
instance_name = 'milp_10_20_50_2310';
mps_file = fullfile(base_dir, [instance_name, '.mps']);
txt_file = fullfile(base_dir, [instance_name, '.txt']);

% Check if files exist
if ~exist(mps_file, 'file')
    error('MPS file not found: %s', mps_file);
end
if ~exist(txt_file, 'file')
    error('TXT file not found: %s', txt_file);
end

%% 2. Load Instance
fprintf('Loading MibS instance: %s...\n', instance_name);
try
    % The new loader returns a struct compatible with solve_BiMIP directly
    model_mibs = loadMibSInstance(mps_file, txt_file);
    fprintf('Instance loaded successfully.\n');
catch ME
    fprintf('Error loading instance: %s\n', ME.message);
    return;
end

%% 3. Configure Solver
% Initialize solver settings
ops = BiMIPsettings(...
    'method', 'exact_KKT', ...      % Use Exact KKT method
    'solver', 'gurobi', ...            % Use CBC (ensure YALMIP recognizes it)
    'verbose', 2, ...               % Show detailed output
    'max_iterations', 5000, ...       % Set iteration limit
    'optimal_gap', 1e-4 ...         % Convergence tolerance
);

%% 4. Solve Problem
fprintf('Starting solver...\n');
try
    % New Interface: Just pass the model struct and options
    [Solution, BiMIP_record] = solve_BiMIP(model_mibs, ops);
        
    fprintf('\nSolver finished.\n');
    fprintf('Optimal Objective: %.4f\n', Solution.obj_upper);
    fprintf('Iterations: %d\n', BiMIP_record.iteration_num);
    
catch ME
    fprintf('Solver failed: %s\n', ME.message);
    % Print stack trace for debugging
    for k = 1:length(ME.stack)
        fprintf('File: %s, Line: %d, Name: %s\n', ...
            ME.stack(k).file, ME.stack(k).line, ME.stack(k).name);
    end
end