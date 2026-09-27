%% 算例介绍
% 针对传统"先预测-后决策"的开环框架下，预测模型难以考虑预测误差对决策成本的非对称影响导致决策次优性的问题，
% 文献[1]提出了一种闭环"预测-决策"框架以提高电力系统机组组合问题的决策经济性。
% 该问题被建模为典型的BiMIP模型：上层被建模为预测模型最优参数的搜索以及再调度问题；下层是电力系统机组组合问题。
% 算例规模：上层连续变量47050，上层离散变量0，下层连续变量39480，下层离散变量22680
% [1] Chen X, Liu Y, Wu L. Towards improving unit commitment economics: 
%     An add-on tailor for renewable energy and reserve predictions
%     [J]. IEEE Transactions on Sustainable Energy, 2024.

%% 初始化
dbstop if error
close all; clc; clear; yalmip('clear');

%% 数据载入
[system_data, training_data, test_data] = data_loader();

% 初始预测模型训练 (传统MSE方法)
RES_mlrmodel = fitlm(training_data.RES_feature_data, sum(training_data.RES_realization_data,2));
training_data.TPO_RES_forecast_data = predict(RES_mlrmodel, training_data.RES_feature_data);
training_data.TPO_RES_forecast_data = training_data.TPO_RES_forecast_data * system_data.RES_weight';
training_data.theta_initial = RES_mlrmodel.Coefficients.Estimate;

%% 模型构建
model = model_building(system_data, training_data);

%% 调用PowerBiMIP求解
ops = BiMIPsettings( ...
    'method', 'quick', ...
    'solver', 'gurobi', ...
    'verbose', 2, ...
    'plot.verbose', 1, ...
    'max_iterations', 10, ...
    'optimal_gap', 1e-3, ...
    'penalty_rho', 1e4);

[Solution, BiMIP_record] = solve_BiMIP(model, ops);

%% 预测+决策模型求解
% 得到SPO优化后的theta值
theta_SPO = Solution.var_upper.theta;

% SPO预测
SPO_prediction_result = test_data.RES_feature_data * theta_SPO(2:end) + theta_SPO(1);
% 传统MSE预测
MSE_prediction_result = predict(RES_mlrmodel, test_data.RES_feature_data);

SPO_prediction_result = SPO_prediction_result * system_data.RES_weight';
MSE_prediction_result = MSE_prediction_result * system_data.RES_weight';

% 求解决策模型 (UC)
[Solution_UC1_MSE, Solution_UC2_MSE, Solution_UC1_SPO, Solution_UC2_SPO] = ...
    solve_decision_models(system_data, test_data, MSE_prediction_result, SPO_prediction_result);

%% 结果展示
total_cost_MSE = Solution_UC2_MSE.obj;
total_cost_SPO = Solution_UC2_SPO.obj;
cost_reduction_rate = (total_cost_MSE - total_cost_SPO) / total_cost_MSE * 100;

fprintf('Total Cost Reduction: %.2f%%\n', cost_reduction_rate);
