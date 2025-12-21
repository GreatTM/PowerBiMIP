function [model_out, ops_out] = preprocess_bilevel_step(model_in, ops_in)
%PREPROCESS_BILEVEL_STEP Performs a single transformation step in the model preprocessing pipeline.
%
%   Description:
%       This function is called by 'preprocess_bilevel_model' when a
%       coupled model is detected. It applies a single, appropriate
%       transformation based on the model's current perspective (e.g.,
%       pessimistic-to-optimistic or coupled-to-uncoupled).
%
%   Input:
%       model_in - struct: The coupled PowerBiMIP model structure to be transformed.
%       ops_in   - struct: A struct with solver options.
%
%   Output:
%       model_out - struct: The model after one transformation step.
%       ops_out   - struct: The updated options struct, which may have a
%                   modified .perspective field after transformation.

    % By default, options are passed through unchanged.
    ops_out = ops_in;

    % --- Select Transformation Based on Model Perspective ---
    switch lower(ops_in.perspective)
        
        % Case 1: Pessimistic with coupled constraints -> Apply Transformation 1
        case 'pessimistic'
            if ops_in.verbose >= 1
                fprintf('  Applying Transformation 1: [Pessimistic + Coupled] -> [Optimistic + Coupled]\n');
            end
            
            % The feature to transform from pessimistic-coupled is currently
            % under development.
            error('PowerBiMIP:NotYetImplemented', ...
                  'Transformation from pessimistic-coupled to optimistic-coupled is under development and not yet available.');
            
            % The following code is currently unreachable due to the error above.
            % model_out = transform_pessimistic_to_optimistic(model_in);
            % ops_out.perspective = 'optimistic';

        % Case 2: Optimistic with coupled constraints -> Apply Transformation 2
        case 'optimistic'
            if ops_in.verbose >= 1
                fprintf('  Applying Transformation 2: [Optimistic + Coupled] -> [Optimistic + Uncoupled]\n');
            end

            % Get or set the penalty coefficient kappa.
            if isfield(ops_in, 'kappa') && ~isempty(ops_in.kappa)
                kappa = ops_in.kappa;
                if ops_in.verbose >= 2
                    fprintf('    Using user-defined penalty kappa = %g.\n', kappa);
                end
            else
                kappa = 1e6; % Default value
                if ops_in.verbose >= 2
                    fprintf('    Using default penalty kappa = %g.\n', kappa);
                end
            end
            
            model_out = transform_coupled_to_uncoupled(model_in, kappa, ops_in);
            
            % The model is now uncoupled; the perspective remains optimistic.
            
        otherwise
            % Handle other unknown states.
            error('PowerBiMIP:UndefinedState', ...
                  'Undefined model state during preprocessing. Perspective: %s', ops_in.perspective);
    end
end