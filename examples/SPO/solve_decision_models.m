function [Solution_UC1_MSE, Solution_UC2_MSE, Solution_UC1_SPO, Solution_UC2_SPO] = solve_decision_models(params, system_data, test_data, MSE_prediction_result, SPO_prediction_result)
    % 根据系统类型选择对应的阶段函数
    switch params.system_kind
        case 'eps'
            stage1_func = @EPS_UC_model_stage1;
            stage2_func = @EPS_UC_model_stage2;
        case 'ies'
            stage1_func = @IES_modeling_firststage;
            stage2_func = @IES_modeling_secondstage;
        case 'ies_simplified'
            stage1_func = @simplified_IES_modeling_firststage;
            stage2_func = @simplified_IES_modeling_secondstage;
        otherwise
            error('未知系统类型: %s', params.system_kind);
    end

    ops = sdpsettings('verbose',0,'solver','gurobi');
    %%%%%% SPO 方法求解 %%%%%%
    % 第一阶段模型
    [model_UC1_SPO.var, model_UC1_SPO.cons, model_UC1_SPO.obj] = ...
        stage1_func(params, system_data, test_data, SPO_prediction_result);
    
    model_UC1_SPO.solution = optimize(model_UC1_SPO.cons, model_UC1_SPO.obj, ops);
    Solution_UC1_SPO = myFun_GetValue(model_UC1_SPO);

    % 第二阶段模型
    [model_UC2_SPO.var, model_UC2_SPO.cons, model_UC2_SPO.obj] = ...
        stage2_func(params, system_data, test_data, Solution_UC1_SPO.var);
    
    model_UC2_SPO.solution = optimize(model_UC2_SPO.cons, model_UC2_SPO.obj, ops);
    Solution_UC2_SPO = myFun_GetValue(model_UC2_SPO);

    %%%%%% 传统MSE方法求解 %%%%%%
    % 第一阶段模型
    [model_UC1_MSE.var, model_UC1_MSE.cons, model_UC1_MSE.obj] = ...
        stage1_func(params, system_data, test_data, MSE_prediction_result);
    
    model_UC1_MSE.solution = optimize(model_UC1_MSE.cons, model_UC1_MSE.obj, ops);
    Solution_UC1_MSE = myFun_GetValue(model_UC1_MSE);

    % 第二阶段模型
    [model_UC2_MSE.var, model_UC2_MSE.cons, model_UC2_MSE.obj] = ...
        stage2_func(params, system_data, test_data, Solution_UC1_MSE.var);
    
    model_UC2_MSE.solution = optimize(model_UC2_MSE.cons, model_UC2_MSE.obj, ops);
    Solution_UC2_MSE = myFun_GetValue(model_UC2_MSE);
end