function [new_all_vars, new_subsets_struct] = replicateVariables(all_orig_vars, orig_subsets_struct)
%REPLICATEVARIABLES Replicates YALMIP variables using global YALMIP tables.
%
%   Description:
%       Creates a clone of the input variables. It strictly follows YALMIP's
%       internal global tables (yalmip('binvariables') and yalmip('intvariables'))
%       to determine variable types.
%
%   Inputs:
%       all_orig_vars       - A vector of unique YALMIP variables (the master list).
%       orig_subsets_struct - A struct containing subsets of these variables.
%
%   Outputs:
%       new_all_vars        - The replicated master vector.
%       new_subsets_struct  - The reconstructed subsets using new variables.

    % --- 1. Input Validation and Preparation ---
    % 如果输入为空，那么没有变量需要复制，返回的变量都是空的
    if isempty(all_orig_vars)
        new_all_vars = sdpvar(0, 1);
        new_subsets_struct = orig_subsets_struct;
        fields = fieldnames(new_subsets_struct);
        for i = 1:numel(fields)
            new_subsets_struct.(fields{i}) = sdpvar(0,1);
        end
        return;
    end
    
    % Ensure input is a column vector for consistent indexing
    all_orig_vars_vec = all_orig_vars(:);
    n_vars = length(all_orig_vars_vec);
    
    % Get the YALMIP indices of the input variables
    orig_indices = getvariables(all_orig_vars_vec);
    
    % --- 2. Type Detection via Global Tables ---
    % Get global lists of variable indices directly from YALMIP
    global_bin_indices = yalmip('binvariables');
    global_int_indices = yalmip('intvariables');
    
    % Determine which of our original variables are Binary
    % 'ismember' is used here to get a logical mask aligned with 'orig_indices'
    [is_bin_loc, ~] = ismember(orig_indices, global_bin_indices);
    
    % Determine which of our original variables are Integer
    % Based on your requirement: these lists are treated as mutually exclusive sets
    [is_int_loc, ~] = ismember(orig_indices, global_int_indices);
    
    % --- 3. Create New Variables ---
    % Start by creating a full vector of continuous variables (default)
    new_all_vars = sdpvar(n_vars, 1, 'full');
    
    % Find indices for binaries and integers
    idx_bin = find(is_bin_loc);
    idx_int = find(is_int_loc);
    
    % Overwrite specific positions with binary variables
    if ~isempty(idx_bin)
        new_all_vars(idx_bin) = binvar(length(idx_bin), 1);
    end
    
    % Overwrite specific positions with integer variables
    if ~isempty(idx_int)
        new_all_vars(idx_int) = intvar(length(idx_int), 1);
    end
    
    % --- 4. Reconstruct Subsets (Mapping) ---
    new_subsets_struct = struct();
    sub_fields = fieldnames(orig_subsets_struct);
    
    for i = 1:length(sub_fields)
        sub_name = sub_fields{i};
        current_subset = orig_subsets_struct.(sub_name);
        
        if isempty(current_subset)
            new_subsets_struct.(sub_name) = sdpvar(0, 1);
            continue;
        end
        
        % Get YALMIP indices of the current subset
        subset_indices = getvariables(current_subset);
        
        % Find where these indices exist in our master 'orig_indices' list
        [found, loc] = ismember(subset_indices, orig_indices);
        
        if ~all(found)
             error('PowerBiMIP:SubsetMismatch', ...
                ['Variables in subset "%s" are missing from the provided "all_orig_vars". ' ...
                 'Make sure all_orig_vars contains the union of all subsets.'], sub_name);
        end
        
        % Extract the new variables
        new_vars_flat = new_all_vars(loc);
        
        % Reshape to match the original subset's dimensions (row/col/matrix)
        new_subsets_struct.(sub_name) = reshape(new_vars_flat, size(current_subset));
    end
    
    % Restore the shape of the main output to match input
    new_all_vars = reshape(new_all_vars, size(all_orig_vars));
end