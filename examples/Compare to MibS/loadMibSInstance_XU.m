function model = loadMibSInstance_XU(mps_file_path, txt_file_path)
%LOADMIBSINSTANCE_XU Loads a MibS XU-format benchmark instance into PowerBiMIP format.
%
%   model = loadMibSInstance_XU(mps_file_path, txt_file_path)
%
%   Description:
%       This function handles the specific "XU" format of MibS auxiliary files,
%       which differs from the standard MibS format.
%       Format features:
%       - @NUMVARS: Total number of lower level variables? Or total variables?
%         Usually XU instances specify Lower Level variables explicitly.
%       - @VARSBEGIN ... @VARSEND: List of Lower Level variables and their objective coefficients.
%         Format: [VarName] [ObjCoeff]
%       - @CONSTRSBEGIN ... @CONSTRSEND: List of Lower Level constraint names.
%
%   Inputs:
%       mps_file_path - String, absolute or relative path to the .mps file.
%       txt_file_path - String, absolute or relative path to the .txt file.
%
%   Output:
%       model - Struct containing the PowerBiMIP model components.

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
    
    %% 3. Parse XU-Format Auxiliary Text File
    if ~exist(txt_file_path, 'file')
        error('PowerBiMIP:FileNotFound', 'Auxiliary TXT file not found: %s', txt_file_path);
    end
    
    fid = fopen(txt_file_path, 'r');
    
    lower_var_names = {};
    lower_var_obj_coeffs = [];
    lower_con_names = {};
    
    mode = ''; % Current section
    
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if isempty(line), continue; end
        
        if startsWith(line, '@')
            mode = line;
            continue;
        end
        
        switch mode
            case '@VARSBEGIN'
                parts = strsplit(line);
                if length(parts) >= 2
                    lower_var_names{end+1} = parts{1};
                    lower_var_obj_coeffs(end+1) = str2double(parts{2});
                end
            case '@CONSTRSBEGIN'
                lower_con_names{end+1} = line;
        end
    end
    fclose(fid);
    
    %% 4. Define YALMIP Variables
    % Need to match variable names from MPS to identify which are lower/upper.
    % mpsread usually returns default names 'x1', 'x2'... if names are not stored,
    % OR `problem.colname` if available.
    
    if ~isfield(problem, 'colname')
        % If mpsread didn't return column names, we are in trouble for this format,
        % because the aux file refers to variables by name (e.g., 'y0', 'y1').
        %
        % HACK for xuLarge instances:
        % The xuLarge instances seem to have a specific naming convention.
        % The variables in the MPS file are usually named COL00001, COL00002...
        % OR they might be implicit if colname is missing.
        % However, the aux file uses 'y0', 'y1'...
        %
        % Let's check if we can infer names.
        % In `xuLarge500-1.mps` (if we could see it), we might see 'y0' etc.
        % If `mpsread` fails to parse them, we might need to manual parse.
        %
        % Wait, modern mpsread usually returns colname. If it's missing, it might be
        % because the MPS file doesn't have a COLUMNS section with names? Impossible.
        % Or `mpsread` stripped them.
        %
        % Alternative: Parse COLUMNS section names manually using helper.
        
        warning('PowerBiMIP:MPSReadWarning', 'mpsread did not return colname. Attempting manual extraction of column names.');
        all_col_names = get_mps_column_names(mps_file_path);
        
        if length(all_col_names) ~= num_vars
             error('PowerBiMIP:ManualParseError', 'Manual column extraction found %d names, but mpsread found %d vars.', length(all_col_names), num_vars);
        end
    else
        all_col_names = problem.colname; % Cell array of names
    end
    
    % Determine Integer Variables
    is_int = false(num_vars, 1);
    if isfield(problem, 'intcon') && ~isempty(problem.intcon)
        is_int(problem.intcon) = true;
    end
    
    % Create Variables
    x_vars = cell(num_vars, 1);
    for i = 1:num_vars
        if is_int(i)
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
    
    %% 5. Classify Variables
    % Map Lower Level Names to Indices
    % Create a map for fast lookup
    col_name_map = containers.Map(all_col_names, 1:num_vars);
    
    lower_indices = [];
    lower_obj_map = zeros(num_vars, 1); % Store lower objective coeffs aligned to var index
    
    for i = 1:length(lower_var_names)
        name = lower_var_names{i};
        if isKey(col_name_map, name)
            idx = col_name_map(name);
            lower_indices(end+1) = idx;
            lower_obj_map(idx) = lower_var_obj_coeffs(i);
        else
            warning('Variable %s from aux file not found in MPS columns.', name);
        end
    end
    
    upper_indices = setdiff(1:num_vars, lower_indices);
    
    % Split Variables
    u_idx = upper_indices;
    u_is_int = is_int(u_idx);
    model.var_x_u = x(u_idx(~u_is_int));
    model.var_z_u = x(u_idx(u_is_int));
    
    l_idx = lower_indices;
    l_is_int = is_int(l_idx);
    model.var_x_l = x(l_idx(~l_is_int));
    model.var_z_l = x(l_idx(l_is_int));
    
    %% 6. Build Constraints
    model.cons_upper = [];
    model.cons_lower = [];
    
    % --- Bounds ---
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
    
    % --- Linear Constraints ---
    % Map constraint names to decide Upper/Lower
    % Note: mpsread often fails to return rownames too.
    
    if ~isfield(problem, 'rownames')
         warning('PowerBiMIP:MPSReadWarning', 'mpsread did not return rownames. Attempting manual extraction of row names.');
         [constraint_info_manual, ~] = get_mps_constraint_names_full(mps_file_path);
         
         % Validate count
         total_con_mpsread = size(problem.Aineq, 1) + size(problem.Aeq, 1);
         if length(constraint_info_manual) ~= total_con_mpsread
             % This is critical. If counts mismatch, we can't map.
             % Sometimes N-row is excluded/included.
             error('PowerBiMIP:ManualParseError', 'Manual row extraction found %d names, but mpsread found %d constraints.', length(constraint_info_manual), total_con_mpsread);
         end
         
         % Use manual info
         constraint_info = constraint_info_manual;
    else
        all_row_names = problem.rownames;
        % Even if we have rownames, we need types and order to match Aineq/Aeq robustly.
        [constraint_info, ~] = get_mps_constraint_names_full(mps_file_path);
    end
    
    % Create set for fast lookup of Lower Constraints
    % Note: lower_con_names contains names from aux file
    is_lower_con_map = containers.Map();
    for i = 1:length(lower_con_names)
        is_lower_con_map(lower_con_names{i}) = true;
    end
    
    % Combine Aineq and Aeq
    if ~isempty(problem.Aineq)
        num_ineq = size(problem.Aineq, 1);
        for i = 1:num_ineq
            % Find name for this inequality row
            % problem.rownames includes ALL rows (ineq + eq) usually in order?
            % mpsread documentation: "The constraints are ordered as they appear in the file."
            % problem.Aineq corresponds to 'L' and 'G' rows.
            % problem.Aeq corresponds to 'E' rows.
            % BUT problem.rownames returns them in what order? 
            % Usually matches the concatenation? Or just a list of names?
            % Actually, we need to be careful.
            % Let's use the same `get_mps_constraint_names` helper to be robust about ORDER.
        end
    end
    
    % Use custom parser to get exact order and type, then match with mpsread matrices
    [constraint_info, ~] = get_mps_constraint_names_full(mps_file_path);
    
    % Verify count
    total_con_mpsread = size(problem.Aineq, 1) + size(problem.Aeq, 1);
    if length(constraint_info) ~= total_con_mpsread
        warning('Mismatch in constraint counts: Parser found %d, mpsread found %d. Falling back to name matching if possible.', length(constraint_info), total_con_mpsread);
    end
    
    idx_ineq = 0;
    idx_eq = 0;
    
    for i = 1:length(constraint_info)
        name = constraint_info(i).name;
        ctype = constraint_info(i).type;
        
        is_lower = isKey(is_lower_con_map, name);
        
        con = [];
        if strcmp(ctype, 'E')
            idx_eq = idx_eq + 1;
            if idx_eq <= size(problem.Aeq, 1)
                con = (problem.Aeq(idx_eq, :) * x == problem.beq(idx_eq));
            end
        else
            idx_ineq = idx_ineq + 1;
            if idx_ineq <= size(problem.Aineq, 1)
                con = (problem.Aineq(idx_ineq, :) * x <= problem.bineq(idx_ineq));
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
    
    %% 7. Objectives
    % Upper: problem.f
    model.obj_upper = problem.f' * x;
    
    % Lower: From aux file
    % We already built lower_obj_map aligned to variable indices
    model.obj_lower = lower_obj_map' * x;
    
    % Store raw info
    model.aux_info.lower_var_names = lower_var_names;
    model.aux_info.lower_con_names = lower_con_names;

end

function [constraint_info, obj_name] = get_mps_constraint_names_full(filename)
% Simple parser to extract row names and types from ROWS section in order
    fid = fopen(filename, 'r');
    constraint_info = struct('name', {}, 'type', {});
    obj_name = '';
    in_rows = false;
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), break; end
        
        if startsWith(strtrim(line), '*')
            continue;
        end
        
        if ~isempty(regexp(line, '^ROWS', 'once'))
            in_rows = true;
            continue;
        elseif ~isempty(regexp(line, '^COLUMNS', 'once'))
            break; 
        end
        
        if in_rows
            parts = strsplit(strtrim(line));
            if length(parts) >= 2
                type = parts{1};
                name = parts{2};
                if strcmp(type, 'N')
                    obj_name = name;
                else
                    constraint_info(end+1).name = name;
                    constraint_info(end).type = type;
                end
            end
        end
    end
    fclose(fid);
end

function col_names = get_mps_column_names(filename)
% Simple parser to extract column names from COLUMNS section
% Note: MPS format lists columns column-by-column. A column name appears multiple times.
% We need the UNIQUE ordered list of column names.
    fid = fopen(filename, 'r');
    col_names = {};
    seen_cols = containers.Map();
    in_cols = false;
    
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), break; end
        
        if startsWith(strtrim(line), '*')
            continue;
        end
        
        if ~isempty(regexp(line, '^COLUMNS', 'once'))
            in_cols = true;
            continue;
        elseif ~isempty(regexp(line, '^RHS', 'once'))
            break; 
        end
        
        if in_cols
            % MPS Fixed format or free format
            % Usually: [Space] ColName [Space] RowName [Space] Value
            parts = strsplit(strtrim(line));
            if ~isempty(parts)
                cname = parts{1};
                
                % Check for MARKER lines
                % Standard MPS Marker line: Name 'MARKER' ...
                % Check 2nd token for 'MARKER' (quoted or not)
                if length(parts) >= 2
                    second_token = parts{2};
                    if contains(second_token, 'MARKER')
                        continue;
                    end
                end
                
                % Also check if cname itself looks like a marker (heuristic)
                if contains(cname, 'MARKER')
                    continue;
                end
                
                if ~isKey(seen_cols, cname)
                    col_names{end+1} = cname;
                    seen_cols(cname) = true;
                end
            end
        end
    end
    fclose(fid);
end
