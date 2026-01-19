function [Solution_UC1_MSE, Solution_UC2_MSE, Solution_UC1_SPO, Solution_UC2_SPO] = ...
    solve_decision_models(system_data, test_data, MSE_prediction_result, SPO_prediction_result)
    
    ops = sdpsettings('verbose', 0, 'solver', 'gurobi');
    
    %%%%%% SPO 方法求解 %%%%%%
    % 第一阶段
    [model_UC1_SPO.var, model_UC1_SPO.cons, model_UC1_SPO.obj] = ...
        EPS_UC_model_stage1(system_data, test_data, SPO_prediction_result);
    model_UC1_SPO.solution = optimize(model_UC1_SPO.cons, model_UC1_SPO.obj, ops);
    Solution_UC1_SPO = myFun_GetValue(model_UC1_SPO);

    % 第二阶段
    [model_UC2_SPO.var, model_UC2_SPO.cons, model_UC2_SPO.obj] = ...
        EPS_UC_model_stage2(system_data, test_data, Solution_UC1_SPO.var);
    model_UC2_SPO.solution = optimize(model_UC2_SPO.cons, model_UC2_SPO.obj, ops);
    Solution_UC2_SPO = myFun_GetValue(model_UC2_SPO);

    %%%%%% 传统MSE方法求解 %%%%%%
    % 第一阶段
    [model_UC1_MSE.var, model_UC1_MSE.cons, model_UC1_MSE.obj] = ...
        EPS_UC_model_stage1(system_data, test_data, MSE_prediction_result);
    model_UC1_MSE.solution = optimize(model_UC1_MSE.cons, model_UC1_MSE.obj, ops);
    Solution_UC1_MSE = myFun_GetValue(model_UC1_MSE);

    % 第二阶段
    [model_UC2_MSE.var, model_UC2_MSE.cons, model_UC2_MSE.obj] = ...
        EPS_UC_model_stage2(system_data, test_data, Solution_UC1_MSE.var);
    model_UC2_MSE.solution = optimize(model_UC2_MSE.cons, model_UC2_MSE.obj, ops);
    Solution_UC2_MSE = myFun_GetValue(model_UC2_MSE);
end
