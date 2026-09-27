function model_processed = BimipModelTransformation(coupled_info, model, ops)
    if strcmpi(model.model_type, 'OBL') || strcmpi(model.model_type, 'PBL')
        % If the model is already uncoupled, no preprocessing is needed.
        model_processed = model;
        if ops.verbose >= 1
            fprintf('No preprocessing is needed.\n');
        end
        return;
    elseif strcmpi(model.model_type, 'OBL-CC-1')
        % Coupled constraints exist, but upper vars in coupled constraints 
        % do NOT appear in lower-level constraints. No transformation needed.
        % The coupled constraints will be handled directly in SP2.
        if ops.verbose >= 1
            fprintf('Initial model has coupled constraints, but they do NOT require transformation.\n');
            fprintf('There are no linking variables in coupled constraints.\n');
            fprintf('Skipping transformation. Coupled constraints will be handled in subproblems.\n');
        end
        % Mark the model as "special coupled" so SP2 knows to handle it
        model_processed = model;
        return;
    elseif strcmpi(model.model_type, 'OBL-CC-2')
        if ops.verbose >= 1
            fprintf('Initial model has coupled constraints. Starting reformulation...\n');
            fprintf('  Applying Transformation: [Optimistic + Coupled] -> [Optimistic + Uncoupled]\n');
        end
        model_processed = transform_coupled_to_uncoupled(coupled_info, model, ops);
        % 再检查一遍
        [model_type, ~] =  BiMIP_Model_Classifier(model_processed, ops);
        % 更新模型参数
        model_processed.model_type = model_type;
        if ~strcmpi(model_processed.model_type, 'OBL')
            error('PowerBiMIP:UndefinedState', ...
                  'Please check transform_coupled_to_uncoupled.m');
        end
        return;
    elseif strcmpi(model.model_type, 'PBL-CC')
        % PBL-CC模型暂不支持
        error('PowerBiMIP:NotYetImplemented', ...
              'PowerBiMIP currently does not support processing PBL-CC type models.');
    else
        error('PowerBiMIP:UndefinedState', ...
              'Undefined model type');
    end
end