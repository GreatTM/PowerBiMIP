function model = model_building(system_data, training_data, params)
    % 定义预测模型参数
    theta = sdpvar(size(training_data.RES_feature_data,2)+1,1,'full');
    % 预测值
    pres_forecast = theta(1) + ...
        training_data.RES_feature_data * theta(2:end);
    pres_forecast = pres_forecast * system_data.RES_weight';

    [model.var_lower, model.cons_lower, model.obj_lower] = ...
        EPS_UC_model_stage1(params, system_data, training_data, pres_forecast);
    [model.var_upper, model.cons_upper, model.obj_upper] = ...
        EPS_UC_model_stage2(params, system_data, training_data, model.var_lower);

    model.var_upper.theta = theta;

    %% 目标函数处理
    % 目标函数（L1正则化要线性化）
    switch params.regularization_selection
        case 0 % 不正则化
            model.obj_upper = model.obj_upper;
        case 1 % L1正则化
            % 定义线性化辅助变量
            model.var_upper.piecewise_aux = sdpvar(size(model.var_upper.theta,1), ...
                                             size(model.var_upper.theta,2),'full');
            % 辅助约束
            model.cons_upper = model.cons_upper + ...
                (model.var_upper.piecewise_aux >= model.var_upper.theta);
            model.cons_upper = model.cons_upper + ...
                (model.var_upper.piecewise_aux >= -model.var_upper.theta);
            % 定义上层目标函数
            model.obj_upper = model.obj_upper + ...
                                    params.regularization_coefficient * ...
                                    sum(model.var_upper.piecewise_aux,'all');
        case 2  % 
            model.obj_upper = model.obj_upper + ...
                                    params.regularization_coefficient * ...
                                    sum((model.var_upper.theta)'*(model.var_upper.theta));
        otherwise
            error('Check whether params.regularization_selection is correct');
    end
end
