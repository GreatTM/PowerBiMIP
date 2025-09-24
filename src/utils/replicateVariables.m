function [new_all_vars, new_subsets_struct] = replicateVariables(all_orig_vars, orig_subsets_struct, issdpvar, isbinvar, isintvar)
%REPLICATEVARIABLES Replicates YALMIP variables and their subset relationships.
%
%   Description:
%       This function creates a new, independent set of YALMIP variables
%       based on a total vector of original variables and a struct of subsets.
%       It then reconstructs the subsets with the new variables, preserving
%       the original relative positioning and structure.
%
%   Inputs:
%     - all_orig_vars: A column vector containing all original YALMIP variables.
%                      E.g., [x(:); y(:); z(:)]
%     - orig_subsets_struct: A struct where each field is a subset of all_orig_vars.
%                            E.g., struct('s1', x(1:5), 's2', y(1:3))
%     - issdpvar: (logical) true to create sdpvar variables.
%     - isbinvar: (logical) true to create binvar variables.
%     - isintvar: (logical) true to create intvar variables.
%
%   Outputs:
%     - new_all_vars: The new, replicated total vector of variables.
%     - new_subsets_struct: A struct containing the reconstructed subsets
%                           using the new variables.

    % --- Input Validation ---
    % Check if all_orig_vars is empty.
    if isempty(all_orig_vars)
        % If the total vector is empty, create new empty vectors.
        if issdpvar
            new_all_vars = sdpvar(0, 1);
        end
        if isbinvar
            new_all_vars = binvar(0, 1);
        end
        if isintvar
            new_all_vars = intvar(0, 1);
        end
        
        % Replicate the subset struct, but set all subsets to be empty.
        new_subsets_struct = struct();
        sub_fields = fieldnames(orig_subsets_struct);
        for i = 1:length(sub_fields)
            sub_name = sub_fields{i};
            if issdpvar
                new_subsets_struct.(sub_name) = sdpvar(0, 1);
            end
            if isbinvar
                new_subsets_struct.(sub_name) = binvar(0, 1);
            end
            if isintvar
                new_subsets_struct.(sub_name) = intvar(0, 1);
            end
        end
        return;
    end
    
    % Ensure all_orig_vars is a vector.
    if ~isvector(all_orig_vars)
        error('PowerBiMIP:InvalidInput', 'Input ''all_orig_vars'' must be a vector.');
    end
    
    % --- Step 1: Capture the positions of subsets within the total variable vector ---
    % Get the variable handles of the total original vector.
    all_orig_vars_handle = getvariables(all_orig_vars);
    
    % Capture the indices of each subset within the total vector.
    subset_indices = struct();
    sub_fields = fieldnames(orig_subsets_struct);
    
    for i = 1:length(sub_fields)
        sub_name = sub_fields{i};
        current_subset = orig_subsets_struct.(sub_name);
        
        % Check if the current subset is empty.
        if isempty(current_subset)
            % If the subset is empty, store empty indices.
            subset_indices.(sub_name) = [];
            continue;
        end
        
        % Ensure the subset is a vector.
        if ~isvector(current_subset)
            error('PowerBiMIP:InvalidInput', 'Subset ''%s'' must be a vector.', sub_name);
        end
        
        % Get the variable handles of the subset.
        subset_handle = getvariables(current_subset);
        
        % Use ismember to find the locations of the subset handles within the total vector handles.
        [~, loc] = ismember(subset_handle, all_orig_vars_handle);
        
        % Store these location indices.
        subset_indices.(sub_name) = loc;
    end
    
    % --- Step 2: Reconstruct new variables and subsets based on the captured indices ---
    % Get the total dimension of the original variable vector.
    orig_total_dims = size(all_orig_vars, 1);
    
    % Define a new, independent vector of variables of the same size.
    if issdpvar
        new_all_vars = sdpvar(orig_total_dims, 1, 'full');
    end
    if isbinvar
        new_all_vars = binvar(orig_total_dims, 1, 'full');
    end
    if isintvar
        new_all_vars = intvar(orig_total_dims, 1, 'full');
    end

    % Reconstruct the new subsets.
    new_subsets_struct = struct();
    for i = 1:length(sub_fields)
        sub_name = sub_fields{i};
        indices = subset_indices.(sub_name);
        
        % If indices are empty, create an empty subset.
        if isempty(indices)
            if issdpvar
                new_subsets_struct.(sub_name) = sdpvar(0, 1);
            end
            if isbinvar
                new_subsets_struct.(sub_name) = binvar(0, 1);
            end
            if isintvar
                new_subsets_struct.(sub_name) = intvar(0, 1);
            end
        else
            % Extract variables from the new total vector at the stored indices to form the new subset.
            new_subsets_struct.(sub_name) = new_all_vars(indices);
        end
    end
end