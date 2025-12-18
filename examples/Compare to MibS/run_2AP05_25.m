% Run MibS benchmark instance 2AP05-25 (Assignment Interdiction) using PowerBiMIP
%
% This script demonstrates how to load a MibS formatted instance and solve it
% using the PowerBiMIP toolbox.

clear; clc;

%% 1. Setup Paths
% Get the directory of this script
base_dir = fileparts(mfilename('fullpath'));
% Construct paths to the data files
% Path: MibSdata/interdiction/Assignment/2AP05-25.mps
mps_file = fullfile(base_dir, 'MibSdata', 'interdiction', 'Assignment', '2AP05-25.mps');
txt_file = fullfile(base_dir, 'MibSdata', 'interdiction', 'Assignment', '2AP05-25.txt');

% Check if files exist
if ~exist(mps_file, 'file')
    error('MPS file not found: %s', mps_file);
end
if ~exist(txt_file, 'file')
    error('TXT file not found: %s', txt_file);
end

%% 2. Load Instance
fprintf('Loading MibS instance: %s...\n', '2AP05-25');
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
    'max_iterations', 100, ...      % Set iteration limit
    'optimal_gap', 1e-4 ...         % Convergence tolerance
);

% IMPORTANT: 2AP05-25 is an Interdiction problem (Max-Min or Min-Max).
% MibS default format often implies Min-Min, but Interdiction is zero-sum.
% If OS in txt file is -1, it might imply Maximize Upper Level?
% PowerBiMIP assumes Min Upper, Min Lower (Optimistic).
% For Interdiction (Leader Min, Follower Max, or vice versa zero-sum),
% our solver detects Interdiction automatically if c_upper_lower_vars = -c_lower_vars.
% However, loadMibSInstance loads objectives as is.
% We should check if we need to negate lower objective manually if the instance is defined as Min-Min in file but intended as Min-Max.
% MibS Interdiction instances usually have Upper Objective = Ref to x and y,
% and Lower Objective = Ref to y.
% If they are zero sum (c_u = -c_l for y), the automatic detection works.
% Let's run and see if the solver detects it.

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
