%% ========================================================================
% Main Script: Plot PADM Convergence (Mixed Fonts & Half Width)
% =========================================================================
clc; clear; close all;

% 1. 设置路径并载入数据
filePath = "E:\3. Toolbox\PowerBiMIP\results\20260104_223609\workspace_variables.mat";

if exist(filePath, 'file')
    fprintf('正在载入数据: %s ...\n', filePath);
    load(filePath);
else
    error('错误: 找不到文件 %s', filePath);
end

% 2. 准备绘图保存目录
saveDir = 'results/figures/';
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

total_rd_iterations = BiMIP_record.iteration_num;
fprintf('开始生成优化后的 PADM 迭代图 (宽度减半，TeX字体)...\n');

%% 3. 循环绘图
for i = 2 : total_rd_iterations
    
    % --- 数据读取 ---
    try
        current_sol = BiMIP_record.master_problem_solution{1, i};
        
        if isfield(current_sol, 'padm1_objectives')
            raw_obj1 = current_sol.padm1_objectives;
        else
            continue; 
        end
        
        if isfield(current_sol, 'padm2_objectives')
            raw_obj2 = current_sol.padm2_objectives;
        else
            raw_obj2 = nan(size(raw_obj1));
        end
        
        % 获取或计算 Gap
        if isfield(current_sol, 'padm_gaps')
            raw_gaps = current_sol.padm_gaps;
        elseif isfield(current_sol, 'gap')
            raw_gaps = current_sol.gap;
        else
            raw_gaps = abs(raw_obj1 - raw_obj2) ./ (abs(raw_obj1) + eps) * 100;
        end
        
        % --- 数据切片：去除第一个点 ---
        if length(raw_obj1) < 2
            continue;
        end
        
        % 从第2个点开始截取
        obj1 = raw_obj1(2:end);
        obj2 = raw_obj2(2:end);
        gaps = raw_gaps(2:end);
        iters = 2 : length(raw_obj1); 
        
    catch ME
        warning('处理第 %d 次迭代数据时出错: %s', i, ME.message);
        continue;
    end
    
    % --- 绘图设置 ---
    
    % 【关键修改1】调整图形尺寸
    % 原尺寸 [100, 100, 800, 200] -> 宽度减半改为 400
    figHandle = figure('Name', sprintf('RD_Iter_%d', i), ...
        'NumberTitle', 'off', ...
        'Position', [100, 100, 400, 200], ... % Width=400, Height=200
        'Color', 'w');
    
    % --- 左侧 Y 轴: 目标函数值 ---
    yyaxis left;
    axLeft = gca;
    hold on;
    
    % 绘制线条
    h1 = plot(iters, obj1, 'rs-', 'LineWidth', 1, 'MarkerSize', 3);
    h2 = plot(iters, obj2, 'b^-', 'LineWidth', 1, 'MarkerSize', 3);
    
    % 【关键修改2】使用 TeX 语法设置字体
    ylabel('\fontname{SimSun}目标函数值', 'FontSize', 12);
    set(axLeft, 'YColor', 'k'); 
    
    % --- 右侧 Y 轴: Gap ---
    yyaxis right;
    axRight = gca;
    
    h3 = plot(iters, gaps, 'ko--', 'LineWidth', 1, 'MarkerSize', 3);
    
    ylabel('\fontname{Times New Roman}Gap (%)', 'FontSize', 12);
    set(axRight, 'YColor', 'k');
    
    % --- 通用设置 ---
    % 【关键修改2】X轴混合字体
    xlabel('\fontname{Times New Roman}PADM\fontname{SimSun}迭代次数', 'FontSize', 12);
    
    % 刻度本身用 Times New Roman (保持数字美观)
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    grid on;
    box on;
    set(gca, 'LineWidth', 0.75);
    
    % 调整 X 轴范围
    xlim([min(iters), max(iters)]);
    if length(iters) <= 5 % 因为图变窄了，刻度稍微稀疏一点
        xticks(iters);
    else
         xticks(floor(linspace(min(iters), max(iters), 5)));
    end

    % --- 图例设置 ---
    % 在图例中也应用字体设置，确保统一
    lgdStr1 = '\fontname{SimSun}子问题\fontname{Times New Roman}1';
    lgdStr2 = '\fontname{SimSun}子问题\fontname{Times New Roman}2';
    lgdStr3 = '\fontname{Times New Roman}Gap (%)';
    
    lgd = legend([h1, h2, h3], {lgdStr1, lgdStr2, lgdStr3}, 'Location', 'best','FontSize', 5);
    set(lgd, 'Box', 'on');
    set(lgd, 'FontSize', 10); % 图变小了，字号微调以防遮挡
    
    % --- 保存图片 ---
    fileName = sprintf('RD_Iter_%d_PADM_Convergence_HalfWidth.png', i);
    fullSavePath = fullfile(saveDir, fileName);
    
    if exist('exportgraphics', 'file')
        exportgraphics(figHandle, fullSavePath, 'Resolution', 300);
    else
        saveas(figHandle, fullSavePath);
    end
    
    fprintf('  已保存: %s\n', fileName);
    % close(figHandle);
end

fprintf('绘图完成。\n');