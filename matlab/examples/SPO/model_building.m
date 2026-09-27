function model = model_building(system_data, training_data)
    % 定义预测模型参数 theta
    theta = sdpvar(size(training_data.RES_feature_data, 2) + 1, 1, 'full');
    
    % 预测值
    pres_forecast = theta(1) + training_data.RES_feature_data * theta(2:end);
    pres_forecast = pres_forecast * system_data.RES_weight';

    % 构建下层模型 (UC第一阶段)
    [model.var_lower, model.cons_lower, model.obj_lower] = ...
        EPS_UC_model_stage1(system_data, training_data, pres_forecast);
    
    % 构建上层模型 (UC第二阶段 - 再调度)
    [model.var_upper, model.cons_upper, model.obj_upper] = ...
        EPS_UC_model_stage2(system_data, training_data, model.var_lower);

    model.var_upper.theta = theta;

    %% 目标函数: L1正则化 (线性化)
    % 正则化系数 = 10
    REGULARIZATION_COEFF = 10;
    
    % 定义线性化辅助变量
    model.var_upper.piecewise_aux = sdpvar(size(theta, 1), size(theta, 2), 'full');
    
    % 辅助约束: |theta| <= piecewise_aux
    model.cons_upper = model.cons_upper + (model.var_upper.piecewise_aux >= theta);
    model.cons_upper = model.cons_upper + (model.var_upper.piecewise_aux >= -theta);
    
    % 上层目标函数 = 再调度成本 + L1正则化项
    model.obj_upper = model.obj_upper + REGULARIZATION_COEFF * sum(model.var_upper.piecewise_aux, 'all');
end
