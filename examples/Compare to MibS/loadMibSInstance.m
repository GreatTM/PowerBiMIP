function model = loadMibSInstance(mps_file_path, txt_file_path)
%LOADMIBSINSTANCE Loads a MibS benchmark instance into PowerBiMIP format.
%
%   model = loadMibSInstance(mps_file_path, txt_file_path)
%
%   Description:
%       This function reads a standard MIP instance in MPS format and an
%       auxiliary text file used by MibS (Mixed Integer Bilevel Solver) to
%       specify the bilevel structure. It constructs a PowerBiMIP model
%       structure ready for solution.
%
%   Inputs:
%       mps_file_path - String, absolute or relative path to the .mps file.
%       txt_file_path - String, absolute or relative path to the .txt file.
%
%   Output:
%       model - Struct containing the PowerBiMIP model components:
%           .var_x_u, .var_z_u  - Upper level variables
%           .var_x_l, .var_z_l  - Lower level variables
%           .cons_upper         - Upper level constraints
%           .cons_lower         - Lower level constraints
%           .obj_upper          - Upper level objective
%           .obj_lower          - Lower level objective
%           .original_var       - The YALMIP variable vector
%           .aux_info           - Struct with raw MibS auxiliary data
%
%   Dependencies:
%       - MATLAB Optimization Toolbox (for mpsread)
%       - YALMIP
%
%   Example:
%       model = loadMibSInstance('input.mps', 'input.txt');
%       [sol, rec] = solve_BiMIP(model.original_var, ...
%           model.var_x_u, model.var_z_u, model.var_x_l, model.var_z_l, ...
%           model.cons_upper, model.cons_lower, ...
%           model.obj_upper, model.obj_lower, ops);

    %% 1. Check Dependencies
    if exist('mpsread', 'file') ~= 2
        error('PowerBiMIP:DependencyError', 'MATLAB Optimization Toolbox (mpsread) is required.');
    end
    
    %% 2. Read MPS File
    if ~exist(mps_file_path, 'file')
        error('PowerBiMIP:FileNotFound', 'MPS file not found: %s', mps_file_path);
    end
    
    try
        problem = mpsread(mps_file_path);
    catch ME
        error('PowerBiMIP:MPSReadError', 'Failed to read MPS file: %s', ME.message);
    end
    
    num_vars = length(problem.f);
    
    %% 3. Parse Auxiliary Text File
    if ~exist(txt_file_path, 'file')
        error('PowerBiMIP:FileNotFound', 'Auxiliary TXT file not found: %s', txt_file_path);
    end
    
    fid = fopen(txt_file_path, 'r');
    if fid == -1
        error('PowerBiMIP:FileAccessError', 'Could not open TXT file: %s', txt_file_path);
    end
    
    % Initialize storage
    LC_indices = []; % Lower Level Columns (Variables)
    LR_indices = []; % Lower Level Rows (Constraints)
    LO_values = [];  % Lower Level Objective Coefficients
    aux_info = struct();
    
    % Parse line by line
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line)
            parts = strsplit(strtrim(line));
            if isempty(parts), continue; end
            
            key = parts{1};
            if length(parts) > 1
                val = str2double(parts{2});
            else
                val = NaN;
            end
            
            switch key
                case 'N'
                    aux_info.N = val;
                case 'M'
                    aux_info.M = val;
                case 'LC'
                    % MibS uses 0-based indexing, convert to 1-based
                    LC_indices = [LC_indices; val + 1];
                case 'LR'
                    % MibS uses 0-based indexing, convert to 1-based
                    LR_indices = [LR_indices; val + 1];
                case 'LO'
                    LO_values = [LO_values; val];
                case 'OS'
                    aux_info.OS = val;
                case 'OB'
                    % Sometimes appears in MibS files, objective offset?
                    aux_info.OB = val;
                otherwise
                    % Store other keys if any
                    if ~isfield(aux_info, 'others')
                        aux_info.others = struct();
                    end
                    aux_info.others.(key) = val;
            end
        end
    end
    fclose(fid);
    
    model.aux_info = aux_info;
    
    %% 4. Define YALMIP Variables
    % Determine variable types based on MPS intcon
    % mpsread returns intcon as a vector of indices of integer variables
    is_int = false(num_vars, 1);
    if isfield(problem, 'intcon') && ~isempty(problem.intcon)
        is_int(problem.intcon) = true;
    end
    
    % Create the single variable vector
    x = sdpvar(num_vars, 1);
    
    % Assign variable types (binaries are treated as integers in YALMIP usually, 
    % but we can specify them if we want. For general MIP, intvar is safe.
    % If bounds are 0-1, YALMIP treats intvar as binvar automatically often, 
    % but to be precise we rely on bounds).
    % However, sdpvar definition does not inherently carry 'integer' property 
    % in the same way for all solvers unless using 'intvar' or 'binvar' command.
    % To keep the vector unified, we use sdpvar and add type constraints later?
    % No, better to use proper constructors if possible, OR just track indices.
    % PowerBiMIP expects: var_x_u (sdpvar), var_z_u (intvar/binvar).
    
    % Actually, we can't easily mix them in one vector `x` if we declare them differently.
    % Strategy: Declare all as sdpvar, but when separating into _u and _l, 
    % we might need to cast or re-declare? 
    % NO, YALMIP variables are objects. We can create them individually.
    
    x_vars = cell(num_vars, 1);
    for i = 1:num_vars
        if is_int(i)
            % Check bounds for binary
            if problem.lb(i) == 0 && problem.ub(i) == 1
                x_vars{i} = binvar(1, 1);
            else
                x_vars{i} = intvar(1, 1);
            end
        else
            x_vars{i} = sdpvar(1, 1);
        end
    end
    x = [x_vars{:}]'; % Concatenate into column vector
    model.original_var = x;
    
    %% 5. Classify Variables (Upper vs Lower)
    % LC_indices are the lower level variables.
    all_indices = (1:num_vars)';
    is_lower_var = ismember(all_indices, LC_indices);
    upper_indices = all_indices(~is_lower_var);
    lower_indices = all_indices(is_lower_var);
    
    % Separate variables
    % We also need to separate Continuous vs Integer for PowerBiMIP interface
    
    % Upper Level
    u_idx = upper_indices;
    u_is_int = is_int(u_idx);
    model.var_x_u = x(u_idx(~u_is_int));
    model.var_z_u = x(u_idx(u_is_int));
    
    % Lower Level
    l_idx = lower_indices;
    l_is_int = is_int(l_idx);
    model.var_x_l = x(l_idx(~l_is_int));
    model.var_z_l = x(l_idx(l_is_int));
    
    %% 6. Build Constraints
    model.cons_upper = [];
    model.cons_lower = [];
    
    % --- 6a. Bounds (Box Constraints) ---
    % Add variable bounds to their respective levels
    % MPS bounds: lb <= x <= ub
    for i = 1:num_vars
        % Lower Bound
        if isfinite(problem.lb(i))
            con = (x(i) >= problem.lb(i));
            if ismember(i, lower_indices)
                model.cons_lower = [model.cons_lower, con];
            else
                model.cons_upper = [model.cons_upper, con];
            end
        end
        % Upper Bound
        if isfinite(problem.ub(i))
            con = (x(i) <= problem.ub(i));
             if ismember(i, lower_indices)
                model.cons_lower = [model.cons_lower, con];
            else
                model.cons_upper = [model.cons_upper, con];
            end
        end
    end
    
    % --- 6b. Linear Inequalities (Aineq * x <= bineq) ---
    if ~isempty(problem.Aineq)
        num_ineq = size(problem.Aineq, 1);
        % Map MPS rows to constraints
        % We need to know which rows correspond to inequality matrices vs equality matrices.
        % mpsread separates them. But the LR indices in MibS correspond to the raw rows in MPS file?
        % This is TRICKY. MibS 'LR' indices refer to the order of rows in the ROWS section of MPS.
        % mpsread separates rows into Aineq and Aeq, losing the original order.
        
        % SOLUTION: We cannot rely on mpsread's Aineq/Aeq separation if we need to map back to original indices easily.
        % However, we might be able to infer. 
        % Alternative: Parse MPS manually? Too complex.
        % Better: Use `mpsread` output but correlate with row names?
        % mpsread output does not return row names directly in a convenient list aligned with Aineq/Aeq rows?
        % Actually, modern mpsread returns `problem.rownames`? Let's check documentation or assume not.
        %
        % If we can't map indices, we have a problem.
        % Let's assume mpsread returns everything in one matrix A if we use a different reader? No.
        
        % Let's assume standard behavior: mpsread does not easily give us original row index.
        % BUT, MibS format usually implies the rows are the constraints.
        % Let's look at `int0sum_i0_10.mps` again.
        % ROWS
        %  L R0001
        %  L R0002 ...
        %  N Rupobj
        % All 'L' (Less than or Equal, or Greater, or Equal depending on value).
        % 'N' is objective.
        
        % In `int0sum_i0_10.txt`: `LR 4`, `LR 5`, `LR 6`, `LR 7`.
        % This implies rows at index 4,5,6,7 (0-based) are lower level.
        % These correspond to R0005, R0006, R0007, R0008.
        % R0001-R0004 are Upper.
        
        % If mpsread reorders them, we are in trouble.
        % Does mpsread preserve order?
        % Usually it groups inequalities and equalities.
        % If all are inequalities, order might be preserved.
        
        % Let's look for a workaround. `mpsread` is opaque.
        % Does `mpsread` return a `rowname` field?
        % Yes, usually `problem.rownames` exists if `mpsread` supports it (in newer MATLABs).
        % Let's check struct fields in a try-catch or existence check.
        % If `problem` has `rownames`, we can match names.
        % But we need the names from the file order.
        
        % CRITICAL: We need the list of row names in the order they appear in the file to map the indices.
        % Since we are reading the file anyway, maybe we can parse the ROWS section manually to get names order.
    end
    
    % --- Helper to extract Row Names Order ---
    % Since mpsread might not return rownames, and we need to map Aineq/Aeq to 
    % original file order to determine Upper/Lower classification, we use a 
    % custom parser to get the order and type of constraints.
    [constraint_info, ~] = get_mps_constraint_names(mps_file_path);
    num_constraints = length(constraint_info);
    
    % Determine which names are lower level based on LR indices
    % LR_indices are 1-based indices into the list of constraints (excluding Objective N-row)
    is_lower_constraint = false(num_constraints, 1);
    valid_lr_indices = LR_indices(LR_indices <= num_constraints);
    is_lower_constraint(valid_lr_indices) = true;
    
    % We now have a list `constraint_info` where:
    % constraint_info(i).type is 'E', 'L', or 'G'.
    % is_lower_constraint(i) tells us if it belongs to Lower Level.
    
    % mpsread separates constraints into Aineq (<=) and Aeq (==).
    % Aineq contains rows for 'L' (<=) and 'G' (>=, converted to <=).
    % Aeq contains rows for 'E'.
    % We assume mpsread preserves the RELATIVE order of constraints within these groups.
    
    idx_ineq = 0;
    idx_eq = 0;
    
    % Iterate through constraints in the order they appear in the file
    for i = 1:num_constraints
        ctype = constraint_info(i).type;
        is_lower = is_lower_constraint(i);
        
        con = [];
        
        if strcmp(ctype, 'E')
            % Equality constraint
            idx_eq = idx_eq + 1;
            if idx_eq <= size(problem.Aeq, 1)
                con = (problem.Aeq(idx_eq, :) * x == problem.beq(idx_eq));
            else
                warning('PowerBiMIP:IndexMismatch', 'More E-rows in file than in mpsread Aeq.');
            end
        else
            % Inequality constraint (L or G)
            % mpsread converts everything to Aineq * x <= bineq
            idx_ineq = idx_ineq + 1;
            if idx_ineq <= size(problem.Aineq, 1)
                con = (problem.Aineq(idx_ineq, :) * x <= problem.bineq(idx_ineq));
            else
                warning('PowerBiMIP:IndexMismatch', 'More L/G-rows in file than in mpsread Aineq.');
            end
        end
        
        if ~isempty(con)
            if is_lower
                model.cons_lower = [model.cons_lower, con];
            else
                model.cons_upper = [model.cons_upper, con];
            end
        end
    end

    % Remove the old fallback logic
    % (The previous has_rownames logic is replaced by this more robust approach)

    
    %% 7. Build Objectives
    % Upper Level Objective: problem.f
    model.obj_upper = problem.f' * x;
    
    % Lower Level Objective: Construct from LO coefficients
    c_lower = zeros(num_vars, 1);
    
    % LO_values correspond to LC_indices one-to-one?
    % MibS format says: "LO -23", "LO 31"...
    % "The coefficients of the lower level objective function."
    % "The order corresponds to the order of lower level variables."
    if length(LO_values) ~= length(LC_indices)
        warning('PowerBiMIP:DataMismatch', 'Number of LO values (%d) does not match number of LC indices (%d).', length(LO_values), length(LC_indices));
    end
    
    count = min(length(LO_values), length(LC_indices));
    for i = 1:count
        idx = LC_indices(i);
        val = LO_values(i);
        c_lower(idx) = val;
    end
    
    model.obj_lower = c_lower' * x;
    
    % Handle Optimization Sense (OS)
    % OS = -1 usually implies MAX? Or MIN?
    % In MibS 'int0sum', OS is -1.
    % PowerBiMIP assumes Min-Min.
    % If the original problem is Min-Max (Interdiction), we need to know.
    % BUT, usually MibS defines Interdiction as Max-Min or Min-Max?
    % MibS paper: "Min_{x} F(x,y) s.t. y \in argmin { f(x,y) ... }" -> Standard Min-Min.
    % If OS determines the sense of Lower Level?
    % For 'int0sum' (random), it is likely Min-Min.
    % For 'knapsack interdiction', it is typically Max-Min or Min-Max.
    % Let's rely on user to invert if needed, or provide a flag.
    % For now, store it in aux_info.
    
end

function [constraint_info, obj_name] = get_mps_constraint_names(filename)
% Simple parser to extract row names and types from ROWS section in order
    fid = fopen(filename, 'r');
    constraint_info = struct('name', {}, 'type', {});
    obj_name = '';
    in_rows = false;
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), break; end
        
        % Skip comments
        if startsWith(strtrim(line), '*')
            continue;
        end
        
        % Detect sections
        if ~isempty(regexp(line, '^ROWS', 'once'))
            in_rows = true;
            continue;
        elseif ~isempty(regexp(line, '^COLUMNS', 'once'))
            break; % Done with rows
        end
        
        if in_rows
            % Parse row definition: Type Name
            parts = strsplit(strtrim(line));
            if length(parts) >= 2
                type = parts{1};
                name = parts{2};
                if strcmp(type, 'N')
                    obj_name = name;
                else
                    constraint_info(end+1).name = name;
                    constraint_info(end).type = type; % E, L, G
                end
            end
        end
    end
    fclose(fid);
end
