function BiMIP_record = solver_algorithm(model, ops)
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
    % Select the core algorithm based on the perspective option.
    if strcmpi(model.model_type, 'OBL') || strcmpi(model.model_type, 'OBL-CC-1')
        % For the optimistic case, call the main optimistic solver.
        if ops.verbose >= 1
            fprintf('Solving with optimistic perspective...\n');
        end
        BiMIP_record = optimistic_solver(model, ops);
    elseif strcmpi(model.model_type, 'PBL')
            % For the pessimistic case, call the pessimistic solver.
            if ops.verbose >= 1
                fprintf('Solving with pessimistic perspective...\n');
            end
            BiMIP_record = pessimistic_solver(model, ops);
    else
        % Huh?
        error('PowerBiMIP:UndefinedState', ...
              'Unknown Problem');
    end
end