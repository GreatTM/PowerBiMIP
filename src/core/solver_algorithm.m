function BiMIP_record = solver_algorithm(model_processed, ops_processed)
%SOLVER_ALGORITHM Dispatches the appropriate solver based on the model type and options.
%
%   This function acts as a router. It first performs critical checks on the
%   model structure and then selects the corresponding core solver algorithm
%   based on the user-specified perspective ('optimistic' or 'pessimistic').
%
%   Inputs:
%       model_processed - A struct containing the standardized BiMIP model data.
%       ops_processed   - A struct containing all processed solver options.
%
%   Outputs:
%       BiMIP_record    - A struct containing detailed iteration history from
%                         the selected core solver.

    %% --- Step 1: Model Compliance Check ---
    % Check for coupled constraints, which are not handled by the standard reformulations.
    [is_coupled, ~] = has_coupled_constraints(model_processed);
    if is_coupled
        % If coupled constraints are found, the disciplined bilevel programming
        % approach has failed. This indicates an unexpected model structure.
        error('PowerBiMIP:DisciplinedBilevelProgrammingFailed', ...
              ['Disciplined bilevel programming failed. This might indicate an issue with the model reformulation logic. ' ...
               'Please contact the author to report this bug.']);
    end

    %% --- Step 2: Dispatch Solver Based on Perspective ---
    % Select the core algorithm based on the perspective option.
    switch lower(ops_processed.perspective)
        case 'optimistic'
            % For the optimistic case, call the main optimistic solver.
            fprintf('Solving with optimistic perspective...\n');
            BiMIP_record = optimistic_solver(model_processed, ops_processed);

        case 'pessimistic'
            % For the pessimistic case, call the pessimistic solver.
            fprintf('Solving with pessimistic perspective...\n');
            BiMIP_record = pessimistic_solver(model_processed, ops_processed);

        otherwise
            % Handle cases where an unsupported perspective is provided.
            error('PowerBiMIP:UnknownPerspective', ...
                  'Unknown perspective specified in options. Please use ''optimistic'' or ''pessimistic''.');
    end
end