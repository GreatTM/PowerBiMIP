function [model_processed, current_ops] = preprocess_bilevel_model(model, ops)
%PREPROCESS_BILEVEL_MODEL Preprocesses a bilevel MIP model to remove coupled constraints.
%
%   Syntax:
%       [model_processed, current_ops] = preprocess_bilevel_model(model, ops)
%
%   Description:
%       This function is a core preprocessing module for the PowerBiMIP toolkit.
%       It takes a standard-form bilevel MIP model and applies a series of
%       equivalence transformations to produce a standard model without
%       coupled constraints, which can then be handled by the core solver.
%
%       The transformation process is as follows:
%       1. Checks if the model contains coupled constraints. If not, the model
%          is returned directly without modifications.
%       2. If the model is [Pessimistic + Coupled], it is transformed into an
%          [Optimistic + Coupled] equivalent.
%       3. If the model is [Optimistic + Coupled], it is transformed into an
%          [Optimistic + Uncoupled] equivalent.
%       4. The process iterates until the model becomes uncoupled.
%
%   Input:
%       model - struct: The standard PowerBiMIP model structure.
%       ops   - struct: A struct with solver options, which must include:
%               .perspective: 'optimistic' or 'pessimistic'
%               .kappa: (Optional) A penalty coefficient for transformations.
%
%   Output:
%       model_processed - struct: The processed model without coupled constraints.
%       current_ops     - struct: The updated options struct, reflecting the
%                         model's final perspective (which may have changed
%                         from pessimistic to optimistic).
    
    current_model = model;
    current_ops = ops;
    
    % Check if the initial model has coupled constraints.
    [is_coupled, coupled_info] = has_coupled_constraints(current_model);
    
    if ~is_coupled
        % If the model is already uncoupled, no preprocessing is needed.
        model_processed = current_model;
        return;
    end
    
    % Check if coupled constraints need relaxation
    if is_coupled && ~coupled_info.needs_relaxation
        % Coupled constraints exist, but upper vars in coupled constraints 
        % do NOT appear in lower-level constraints. No transformation needed.
        % The coupled constraints will be handled directly in SP2.
        if ops.verbose >= 1
            fprintf('Initial model has coupled constraints, but they do NOT require relaxation.\n');
            fprintf('Upper-level variables in coupled constraints do not appear in lower-level constraints.\n');
            fprintf('Skipping transformation. Coupled constraints will be handled in subproblems.\n');
        end
        % Mark the model as "special coupled" so SP2 knows to handle it
        current_model.has_simple_coupled = true;
        model_processed = current_model;
        return;
    end
    
    if ops.verbose >= 1
        fprintf('Initial model has coupled constraints. Starting reformulation...\n');
    end
    % Iteratively apply transformations until the model is uncoupled.
    iteration = 1;
    while is_coupled
        % Display iteration info only in verbose mode.
        if ops.verbose >= 2
            fprintf('  Preprocessing Iteration %d...\n', iteration);
        end
        
        % Call the single-step transformation function.
        [current_model, current_ops] = preprocess_bilevel_step(current_model, current_ops);
        
        % Check if the transformed model still has coupled constraints.
        [is_coupled, ~] = has_coupled_constraints(current_model);
        iteration = iteration + 1;
        
        % Safety break to prevent infinite loops.
        if iteration > 5 
            error('PowerBiMIP:PreprocessingError', 'Preprocessing loop exceeded 5 iterations. Check model or transformation logic.');
        end
    end
    
    if ops.verbose >= 1
        fprintf('Preprocessing complete. Model is now uncoupled.\n');
    end
    model_processed = current_model;
end