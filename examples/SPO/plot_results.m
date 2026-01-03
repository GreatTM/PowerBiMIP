function [CostReduction, Statistics] = plot_results(test_data, MSE_prediction_result, SPO_prediction_result, Solution_UC1_MSE, Solution_UC1_SPO, Solution_UC2_MSE, Solution_UC2_SPO, params, test_range)
    %% 获取测试日期范围
    test_date_str = [datestr(test_range(1), 'yyyy-mm-dd') ' 至 ' datestr(test_range(2), 'yyyy-mm-dd')];
    
    %% 图1：预测曲线对比（添加日期标注）
    actual = sum(test_data.RES_realization_data, 2);
    MSE_prediction_result = sum(MSE_prediction_result,2);
    SPO_prediction_result = sum(SPO_prediction_result,2);

%     figure('Name', ['预测对比 - ' test_date_str]);
%     plot(actual, 'k--', 'LineWidth', 1.5, 'DisplayName', '实际值');
%     hold on;
%     plot(MSE_prediction_result, 'b', 'LineWidth', 1.5, 'DisplayName', 'MSE预测');
%     plot(SPO_prediction_result, 'r', 'LineWidth', 1.5, 'DisplayName', 'SPO预测');
%     title(['RES功率预测对比 (' test_date_str ')']);
%     xlabel('Time');
%     ylabel('RES Power (MW)');
%     legend('Location', 'best');
%     grid on;
%     hold off;

    %% 图2：UC2成本项对比（新增过滤逻辑）
    % 提取非零成本项
    mse_terms = [Solution_UC1_MSE.var.cost_terms(1:4); Solution_UC2_MSE.var.cost_terms];
    spo_terms = [Solution_UC1_SPO.var.cost_terms(1:4); Solution_UC2_SPO.var.cost_terms];
    
    % 创建非零索引（至少有一个模型对应项不为零）
    non_zero_idx = (mse_terms ~= 0) | (spo_terms ~= 0);
    
    % 过滤零项
    mse_terms = mse_terms(non_zero_idx);
    spo_terms = spo_terms(non_zero_idx);
    
    % 生成标签（根据实际含义修改）
    switch params.system_kind
        case 'eps'
            term_labels = {'AnticiFuel', 'NoLoad', 'StartUP', 'Shutdown', ...
                'REG_{up}', 'REG_{down}',...
                'Curtailment', 'LoadShed'};
        case 'ies'
            term_labels = {'AnticiFuel', 'NoLoad', 'StartUP', 'Shutdown', ...
                'AnticiPCHP', 'NoLoadCHP', 'AnticiHCHP', ...
                'REG_{up}', 'REG_{down}', 'CHP_REG_{up}', 'CHP_REG_{down}', 'HCHP_{UP}', 'HCHP_{DOWN}',...
                'Curtailment', 'LoadShed'};
        case 'ies_simplified'
            term_labels = {'AnticiFuel', 'NoLoad', 'StartUP', 'Shutdown', ...
                'AnticiPCHP', 'NoLoadCHP', 'AnticiHCHP', ...
                'REG_{up}', 'REG_{down}', 'CHP_REG_{up}', 'CHP_REG_{down}', 'HCHP_{UP}', 'HCHP_{DOWN}',...
                'Curtailment', 'LoadShed'};
        otherwise
            error('未知系统类型: %s', params.system_kind);
    end
    term_labels = term_labels(non_zero_idx);
    
%     figure('Name', ['成本对比 - ' test_date_str]);
%     bar_data = [mse_terms, spo_terms];
%     h = bar(bar_data);
%     set(gca, 'XTickLabel', term_labels);
%     legend({'MSE', 'SPO'}, 'Location', 'best');
%     ylabel('Cost ($)');
%     title(['成本项对比 (' test_date_str ')']);

    
%     % 添加数值标签
%     for i = 1:size(bar_data,1)
%         text(h(1).XEndPoints(i), h(1).YEndPoints(i), sprintf('%.1f', mse_terms(i)),...
%             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
%         text(h(2).XEndPoints(i), h(2).YEndPoints(i), sprintf('%.1f', spo_terms(i)),...
%             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
%     end
%     grid on;

    %% UC2成本降低百分比
    total_mse = Solution_UC2_MSE.obj;
    total_spo = Solution_UC2_SPO.obj;
    CostReduction = struct(...
        'TotalMSE', total_mse,...
        'TotalSPO', total_spo,...
        'ReductionRate', (total_mse - total_spo)/total_mse*100 ...
    );
    
    fprintf('\nTotal Cost Reduction: %.2f%%\n\n', CostReduction.ReductionRate);

    %% 统计指标计算（保持不变）
    metrics = {'MSE'; 'MAE'; 'MOPE (%)'; 'MUPE (%)'};
    [n, ~] = size(actual);
    
    % 计算MSE预测指标
    err_mse = MSE_prediction_result - actual;
    mse_mse = mean(err_mse.^2);
    mse_mae = mean(abs(err_mse));
    mse_mope = mean(max(0, err_mse)./actual)*100;
    mse_mupe = mean(max(0, -err_mse)./actual)*100;
    
    % 计算SPO预测指标
    err_spo = SPO_prediction_result - actual;
    spo_mse = mean(err_spo.^2);
    spo_mae = mean(abs(err_spo));
    spo_mope = mean(max(0, err_spo)./actual)*100;
    spo_mupe = mean(max(0, -err_spo)./actual)*100;

    % 转换为结构体存储
    Statistics = struct(...
        'MSE_MSE', mse_mse,...
        'MSE_MAE', mse_mae,...
        'MSE_MOPE', mse_mope,...
        'MSE_MUPE', mse_mupe,...
        'SPO_MSE', spo_mse,...
        'SPO_MAE', spo_mae,...
        'SPO_MOPE', spo_mope,...
        'SPO_MUPE', spo_mupe...
    );

    % 创建并显示表格
    metric_table = table(...
        metrics,...
        [mse_mse; mse_mae; mse_mope; mse_mupe],...
        [spo_mse; spo_mae; spo_mope; spo_mupe],...
        'VariableNames', {'Metric', 'MSE_Pred', 'SPO_Pred'});
    
    disp('Statistical Metrics Comparison:');
    disp(metric_table);
end
