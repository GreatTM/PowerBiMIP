function [model, aux] = loadMibSInstance(mps_file_path, txt_file_path)
%LOADMIBSINSTANCE Parsing MibS format. Painlessly. (Strict Structure Version)
%
%   [model, aux] = loadMibSInstance(mps_file, txt_file)
%
%   Reads those ancient MPS files and the weird MibS auxiliary text files.
%   Returns a clean struct ready for PowerBiMIP, and auxiliary info separately.
%
%   Output:
%       model : Struct with ONLY the 6 strict fields required by solve_BiMIP.
%       aux   : Struct containing raw MibS metadata (N, M, OS, etc.).

    %% 1. Sanity Checks
    if nargin < 2, error('Need two files. MPS and TXT. Don''t be stingy.'); end
    if ~exist('sdpvar', 'file'), error('YALMIP missing. We are going nowhere.'); end

    %% 2. The Heavy Lifting (MPS Read)
    if ~exist(mps_file_path, 'file'), error('MPS file is a ghost: %s', mps_file_path); end
    
    try
        % Mute the chatty toolbox!
        % We use evalc to capture and silence the "WARNING: Bound for..." output
        % printed by the HiGHS underlying solver.
        [~] = evalc('prob = mpsread(mps_file_path);');
    catch ME
        % If something goes truly wrong, we re-throw the error
        error('mpsread choked. Message: %s', ME.message);
    end
    
    num_vars = length(prob.f);
    %% 3. The Weird Part (TXT Parse)
    if ~exist(txt_file_path, 'file'), error('TXT file missing: %s', txt_file_path); end
    
    fid = fopen(txt_file_path, 'r');
    if fid == -1, error('Cannot open TXT. Permissions issue?'); end
    
    % Initialize buckets
    LC_idx = []; % Lower Cols (Variables)
    LR_idx = []; % Lower Rows (Constraints)
    LO_val = []; % Lower Obj Coeffs
    aux = struct();
    
    while ~feof(fid)
        ln = strtrim(fgetl(fid));
        if isempty(ln), continue; end
        
        parts = strsplit(ln);
        key = parts{1};
        val = str2double(parts{2:end}); 
        
        switch key
            case 'LC', LC_idx = [LC_idx; val + 1]; % 0-based to 1-based
            case 'LR', LR_idx = [LR_idx; val + 1];
            case 'LO', LO_val = [LO_val; val];
            case 'N',  aux.N = val;
            case 'M',  aux.M = val;
            case 'OS', aux.OS = val; 
        end
    end
    fclose(fid);

    %% 4. Variable Construction
    x_cells = cell(num_vars, 1);
    is_integer = false(num_vars, 1);
    if isfield(prob, 'intcon') && ~isempty(prob.intcon)
        is_integer(prob.intcon) = true;
    end
    
    for i = 1:num_vars
        lb = prob.lb(i);
        ub = prob.ub(i);
        if is_integer(i)
            if lb == 0 && ub == 1, x_cells{i} = binvar(1, 1);
            else, x_cells{i} = intvar(1, 1); end
        else
            x_cells{i} = sdpvar(1, 1);
        end
    end
    x_vec = [x_cells{:}]; 
    x_vec = x_vec(:); 

    %% 5. Split Variables
    all_idx = (1:num_vars)';
    is_lower = ismember(all_idx, LC_idx);
    
    model.var_upper = x_vec(~is_lower);
    model.var_lower = x_vec(is_lower);

    %% 6. Bounds
    model.cons_upper = [];
    model.cons_lower = [];
    
    for i = 1:num_vars
        has_lb = isfinite(prob.lb(i));
        has_ub = isfinite(prob.ub(i));
        if ~has_lb && ~has_ub, continue; end
        
        cons = [];
        if has_lb, cons = [cons, x_vec(i) >= prob.lb(i)]; end
        if has_ub, cons = [cons, x_vec(i) <= prob.ub(i)]; end
        
        if is_lower(i)
            model.cons_lower = [model.cons_lower, cons];
        else
            model.cons_upper = [model.cons_upper, cons];
        end
    end

    %% 7. Matrix Constraints
    [row_names, ~] = parse_mps_row_order(mps_file_path);
    num_rows_file = length(row_names);
    
    is_lower_row_name = containers.Map('KeyType','char','ValueType','logical');
    
    valid_mask = LR_idx <= num_rows_file;
    valid_LR = LR_idx(valid_mask);
    
    for k = 1:length(valid_LR)
        idx = valid_LR(k);
        if idx <= length(row_names)
            name = row_names{idx};
            is_lower_row_name(name) = true;
        end
    end
    
    names_list = {};
    if isfield(prob, 'rownames')
        names_list = prob.rownames;
        if ischar(names_list), names_list = cellstr(names_list); end
    else
        names_list = row_names;
    end
    
    if ~isempty(prob.Aineq)
        n_ineq = size(prob.Aineq, 1);
        for r = 1:n_ineq
            if r <= length(names_list)
                row_name = names_list{r};
                con = (prob.Aineq(r, :) * x_vec <= prob.bineq(r));
                if isKey(is_lower_row_name, row_name)
                    model.cons_lower = [model.cons_lower, con];
                else
                    model.cons_upper = [model.cons_upper, con];
                end
            end
        end
        
        if ~isempty(prob.Aeq)
            n_eq = size(prob.Aeq, 1);
            for r = 1:n_eq
                row_idx_global = n_ineq + r;
                if row_idx_global <= length(names_list)
                    row_name = names_list{row_idx_global};
                    con = (prob.Aeq(r, :) * x_vec == prob.beq(r));
                    if isKey(is_lower_row_name, row_name)
                        model.cons_lower = [model.cons_lower, con];
                    else
                        model.cons_upper = [model.cons_upper, con];
                    end
                end
            end
        end
    end
    
    %% 8. Objectives
    model.obj_upper = prob.f' * x_vec;
    
    c_lower = zeros(num_vars, 1);
    count = min(length(LC_idx), length(LO_val));
    for k = 1:count
        c_lower(LC_idx(k)) = LO_val(k);
    end
    model.obj_lower = c_lower' * x_vec;
    
    % Note: model.aux is NOT assigned here anymore to keep the struct clean.
end

function [names, types] = parse_mps_row_order(filename)
% Robust parser for MPS row names
    fid = fopen(filename, 'r');
    names = {};
    types = {};
    
    current_section = '';
    known_sections = {'NAME', 'ROWS', 'COLUMNS', 'RHS', 'RANGES', 'BOUNDS', 'ENDATA', 'SOS', 'QSECTION'};
    
    while ~feof(fid)
        raw_line = fgetl(fid);
        if ~ischar(raw_line), break; end
        
        line = strtrim(raw_line);
        if isempty(line) || line(1) == '*', continue; end
        
        parts = strsplit(line);
        token = parts{1};
        
        if ismember(token, known_sections)
            current_section = token;
            continue;
        end
        
        if strcmp(current_section, 'ROWS')
            if length(parts) >= 2
                type = parts{1}; 
                name = parts{2};
                if ismember(type, {'N', 'G', 'L', 'E'})
                    if strcmp(type, 'N'), continue; end
                    names{end+1} = name; %#ok<AGROW>
                    types{end+1} = type; %#ok<AGROW>
                end
            end
        elseif strcmp(current_section, 'COLUMNS')
            break; 
        end
    end
    fclose(fid);
end