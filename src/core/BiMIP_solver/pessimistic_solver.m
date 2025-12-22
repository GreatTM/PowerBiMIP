function BiMIP_record = pessimistic_solver(model_processed, ops_processed)
%PESSIMISTIC_SOLVER Placeholder for the pessimistic BiMIP solver.
%
%   This function is a placeholder and currently does not solve the model.
%   It will be implemented in a future release of the PowerBiMIP toolkit.
%
%   Inputs:
%       model_processed - A struct containing the standardized BiMIP model data.
%       ops_processed   - A struct containing all processed solver options.
%
%   Outputs:
%       BiMIP_record    - (Not assigned) The function will always error out.

    % The output is declared to match the required function signature, but it
    % will not be assigned as the function will always throw an error.
    BiMIP_record = [];

    % Throw an error to inform the user that this feature is not yet available.
    error('PowerBiMIP:NotYetImplemented', ...
          ['The pessimistic solver is not yet available in the current version of PowerBiMIP. ' ...
           'This feature is coming soon. Thank you for your patience!']);
end