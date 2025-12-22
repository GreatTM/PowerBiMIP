% Run MibS benchmark instance int0sum_i0_360 using PowerBiMIP
% Known Optimal Solution:
%   Objective value: -89

dbstop if error;
clear; close all; clc; 
yalmip('clear');

%% 1. Setup Paths
% Get the directory of this script
base_dir = fileparts(mfilename('fullpath'));

% Construct paths to the data files (Assumed to be in the same directory)
instance_name = 'int0sum_i0_360';
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
    'solver', 'cbc', ...            % Use CBC
    'verbose', 2, ...               % Show detailed output
    'max_iterations', 100, ...      % Larger instance might need more iterations
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
    for k = 1:length(ME.stack)
        fprintf('File: %s, Line: %d, Name: %s\n', ...
            ME.stack(k).file, ME.stack(k).line, ME.stack(k).name);
    end
end