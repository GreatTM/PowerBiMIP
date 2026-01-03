% 函数功能：用户自定义主函数示例，由用户完成建模后，调用BiMIP求解工具包求解
% 函数输入：无
% 函数输出：无

function main_Centralized_SPO()
    %% 环境初始化
    dbstop if error
    clear; close all; clc; yalmip('clear');

    %% 参数设置
    params = params_settings(...
        'results_record', 1 ...
    );
    global folder_path
    if params.results_record
        % 创建以当前时间命名的文件夹，用以保存所有结果
        timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        folder_path = fullfile('.\results', char(timestamp));
        mkdir(folder_path);
        
        % 保存命令行窗口的所有输出为.txt文件
        diary_file = fullfile(folder_path, 'command_output.txt');
        if exist(diary_file, 'file')
            delete(diary_file); % 如果文件已存在，先删除
        end
        diary(diary_file);
    end

    %% 定义时间参数
    start_date = datetime('2023-11-24 00:00:00');
    end_date = datetime('2023-12-03 23:45:00');
    current_train_start = start_date;

    %% 初始化结果存储
    results = struct(...
        'TrainRange', {},...
        'TestRange', {},...
        'SPO_Pred', {},...
        'MSE_Pred', {},...
        'SPO_Params', {},...
        'MSE_Params', {},...
        'DecisionResults', {},...
        'CostReduction', {},...
        'Statistics',{},...
        'RD_record',{},...
        'SolvingTime', {}...  % 新增求解时间字段
    );
    
    %% 滚动执行主循环 
    cycle_count = 0;
    while current_train_start + days(8) - minutes(15) <= end_date
        %% 清理工作区（保留必要变量）
        yalmip('clear');
        cycle_count = cycle_count + 1;
        
        %% 计算时间范围
        train_end = current_train_start + days(7) - minutes(15);
        test_start = current_train_start + days(7);
        test_end = test_start + days(1) - minutes(15);
        
        %% 命令行输出
        fprintf('第%d个周期 [%s 至 %s]\n', cycle_count,...
            datestr(current_train_start, 'yyyy-mm-dd'),...
            datestr(train_end, 'yyyy-mm-dd'));
        %% 参数加载
        params = params_settings(...
            'system_kind', 'eps',...
            'system_scale', 'big',...
            'train_start_time', datestr(current_train_start, 'yyyy-mm-dd HH:MM:SS'),...
            'train_end_time', datestr(train_end, 'yyyy-mm-dd HH:MM:SS'),...
            'test_start_time', datestr(test_start, 'yyyy-mm-dd HH:MM:SS'),...
            'test_end_time', datestr(test_end, 'yyyy-mm-dd HH:MM:SS'),...
            'res_curtailment', 0, ...
            'load_shedding', 1, ...
            'regularization_selection', 1, ...
            'regularization_coefficient', 10, ...
            'results_record', 1 ...
            );

        fprintf('系统：%s,%s\n', params.system_kind,params.system_scale);

        
        tic;
        %% 数据加载
        [system_data, training_data, test_data] = data_loader(params);
        RES_mlrmodel = fitlm(training_data.RES_feature_data, sum(training_data.RES_realization_data,2));
        training_data.TPO_RES_forecast_data = predict(RES_mlrmodel, training_data.RES_feature_data);
        training_data.TPO_RES_forecast_data = training_data.TPO_RES_forecast_data * system_data.RES_weight';
        training_data.theta_initial = RES_mlrmodel.Coefficients.Estimate;
    
        %% 模型构建
        model = model_building(system_data, training_data, params);
        
        %% 调用BiMIP求解器
        % BiMIP求解工具包配置
        ops = BiMIPsettings( ...
            'method', 'quick', ...
            'solver', 'cplex', ...
            'verbose', 2, ...
            'plot.verbose', 1, ...
            'max_iterations', 10, ...
            'optimal_gap', 1e-3, ...
            'penalty_rho',1e4);

        [Solution, BiMIP_record] = solve_BiMIP(model, ops);

        %% 预测
        % 得到theta值
        theta_SPO = Solution.var_upper.theta;

        % SPO预测
        SPO_prediction_result = test_data.RES_feature_data * ...
            theta_SPO(2:end) + theta_SPO(1);
        % 传统预测
        RES_mlrmodel = fitlm(training_data.RES_feature_data, sum(training_data.RES_realization_data,2));
        MSE_prediction_result = predict(RES_mlrmodel, test_data.RES_feature_data);
        
        SPO_prediction_result = SPO_prediction_result * system_data.RES_weight';
        MSE_prediction_result = MSE_prediction_result * system_data.RES_weight';

        %% 决策模型求解
        [Solution_UC1_MSE, Solution_UC2_MSE, Solution_UC1_SPO, Solution_UC2_SPO] = ...
            solve_decision_models(params, system_data, test_data, MSE_prediction_result, SPO_prediction_result);
        
        %% 调用修改后的绘图函数
        [cost_red, stats] = plot_results(...
                test_data, MSE_prediction_result, SPO_prediction_result, ...
                Solution_UC1_MSE, Solution_UC1_SPO, ...
                Solution_UC2_MSE, Solution_UC2_SPO, params, [test_start, test_end]...
            );
        solving_time = toc;
        %% 结果存储
        results(cycle_count).TrainRange = [current_train_start, train_end];
        results(cycle_count).TestRange = [test_start, test_end];
        results(cycle_count).SPO_Pred = SPO_prediction_result;
        results(cycle_count).MSE_Pred = MSE_prediction_result;
        results(cycle_count).SPO_Params = BiMIP_record.master_problem_solution{1, end}.var.var_upper.theta;
        results(cycle_count).MSE_Params = RES_mlrmodel.Coefficients.Estimate;
        results(cycle_count).DecisionResults = struct(...
            'UC1_MSE', Solution_UC1_MSE,...
            'UC2_MSE', Solution_UC2_MSE,...
            'UC1_SPO', Solution_UC1_SPO,...
            'UC2_SPO', Solution_UC2_SPO...
        );
        results(cycle_count).CostReduction = cost_red;
        results(cycle_count).Statistics = stats;
        results(cycle_count).RD_record = BiMIP_record;
        results(cycle_count).SolvingTime = solving_time;  % 保存求解时间

        %% 更新训练窗口
        current_train_start = current_train_start + days(1);
    end

    %% 结果保存
    % 结果保存
    if params.results_record
        % 保存所有打开的图形窗口为.fig格式
        fig_handles = findobj('Type', 'figure'); % 获取所有打开的图形窗口句柄
        for i = 1:length(fig_handles)
            fig_name = sprintf('figure_%02d.fig', i); % 自动生成文件名
            saveas(fig_handles(i), fullfile(folder_path, fig_name)); % 保存每个图形
        end
    
        % 保存工作区中所有变量为.mat格式
        mat_file = fullfile(folder_path, 'workspace_variables.mat');
        warning off
        save(mat_file); % 保存所有变量，无需指定具体变量名
        warning on
        disp(['所有结果已保存至文件夹: ', folder_path]);
    end
end
