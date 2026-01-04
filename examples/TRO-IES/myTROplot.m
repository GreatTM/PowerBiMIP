%% ========================================================================
% Main Script: Plot PADM Convergence (强制宋体中文 + TNR英文)
% =========================================================================
clear; clc; close all;
% 1. 设置路径与载入数据
% -------------------------------------------------------------------------
dataFile = "E:\3. Toolbox\PowerBiMIP\results\figures\matlab.mat";
if isfile(dataFile)
    load(dataFile);
    fprintf('数据载入成功: %s\n', dataFile);
else
    error('文件未找到: %s\n请检查路径。', dataFile);
end

% 2. 准备存储路径
% -------------------------------------------------------------------------
saveDir = 'results\figures\PADM_Plots_FinalFont_HalfWidth\'; % 修改文件夹名以区分
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

% 3. 读取数据并绘图
% -------------------------------------------------------------------------
num_RD_iterations = Robust_record.cuts_count;
fprintf('检测到 R&D 迭代次数: %d\n', num_RD_iterations);

for k = 1:num_RD_iterations
    current_cell = Robust_record.subproblem_solution{1, k};
    
    if isempty(current_cell) || ~isfield(current_cell, 'sp_solution')
        continue;
    end
    
    sp_sol = current_cell.sp_solution;
    
    % 提取数据
    if isfield(sp_sol, 'padm1_objectives')
        obj1 = -sp_sol.padm1_objectives;
    else
        obj1 = [];
    end
    
    if isfield(sp_sol, 'padm2_objectives')
        obj2 = -sp_sol.padm2_objectives;
    else
        obj2 = nan(size(obj1)); 
    end
    
    if isfield(sp_sol, 'padm_gap')
        gap = sp_sol.padm_gap;
    else
        gap = [];
    end
    
    % 确定X轴
    if ~isempty(obj1)
        iters = 1:length(obj1);
    elseif ~isempty(gap)
        iters = 1:length(gap);
    else
        continue;
    end
    
    % 构建绘图数据
    plotData.iteration = iters;
    plotData.obj1 = obj1;
    plotData.obj2 = obj2;
    plotData.gap = gap;
    
    % 绘图 (调用修改后的子函数)
    figHandle = plotSinglePADM(plotData);
    
    % 保存
    fileName = sprintf('PADM_Convergence_Iter_%d_HalfWidth', k);
    fullPath = fullfile(saveDir, fileName);
    
    % 建议：对于窄图，exportgraphics 的分辨率可以适当提高，或者使用 trim 裁剪空白
    exportgraphics(figHandle, [fullPath '.png'], 'Resolution', 300);
    savefig(figHandle, [fullPath '.fig']);
    
    fprintf('图片已保存: %s\n', fileName);
    
    % close(figHandle); % 批量处理建议关闭窗口，防止内存溢出
end
fprintf('所有绘图已完成。\n');

%% ========================================================================
% 子函数: 绘制单张收敛图 (修改版：窄图、小点、图例内置)
% =========================================================================
function figHandle = plotSinglePADM(data)
    % === 修改1：减小图片宽度 ===
    % 原来是 [100, 100, 800, 220]，宽度减半改为 400
    figHandle = figure('NumberTitle', 'off', 'Position', [100, 100, 400, 220], ...
        'Color', 'w');
    
    % === 数据预处理：隐藏第一个离群点 ===
    if abs(data.obj1(1)) > 100 * mean(abs(data.obj1(2:end)))
        data.obj1(1) = NaN; 
        if ~isempty(data.obj2)
            data.obj2(1) = NaN;
        end
    end
    
    % === 左 Y 轴：目标函数 ===
    yyaxis left;
    axLeft = gca;
    hold on;
    
    % === 修改2：减小 MarkerSize (从6改为3) ===
    if ~isempty(data.obj1)
        plot(data.iteration, data.obj1, 'rs-', ...
            'LineWidth', 1, 'MarkerSize', 3, ... % 改小
            'DisplayName', '\fontname{SimSun}子问题 \fontname{TimesNewRoman}1'); 
    end
    
    if ~isempty(data.obj2) && ~all(isnan(data.obj2))
        plot(data.iteration, data.obj2, 'b^-', ...
            'LineWidth', 1, 'MarkerSize', 3, ... % 改小
            'DisplayName', '\fontname{SimSun}子问题 \fontname{TimesNewRoman}2');
    end
    
    ylabel('\fontname{SimSun}目标函数值', 'FontSize', 12);
    set(axLeft, 'YColor', 'k');
    
    % === 右 Y 轴：Gap ===
    yyaxis right;
    axRight = gca;
    
    if ~isempty(data.gap)
        plot(data.iteration, data.gap, 'ko--', ...
            'LineWidth', 1, 'MarkerSize', 3, ... % 改小
            'DisplayName', 'Gap (%)');
    end
    
    ylabel('Gap (%)', 'FontSize', 12);
    set(axRight, 'YColor', 'k');
    set(axRight, 'YScale', 'log');
    
    % === 通用设置 ===
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    xlabel('PADM \fontname{SimSun}迭代次数', 'FontSize', 12);
    
    grid on; 
    box on;
    set(gca, 'LineWidth', 0.75);
    % grid minor; % 窄图建议关闭 minor grid，否则显得太乱
    
    % === 修改3：图例内置且加框 ===
    % Location: 'best' 会自动避开曲线；或者用 'northeast' 固定右上角
    lgd = legend('Location', 'best', 'Orientation', 'vertical'); 
    lgd.Box = 'on';           % 开启边框
    lgd.LineWidth = 0.5;      % 细框
    lgd.EdgeColor = 'k';      % 黑色边框
    lgd.FontName = 'Times New Roman'; % 保持字体
    lgd.FontSize = 10;        % 窄图里图例字体可以稍微改小一点点，或者保持12
    
    hold off;
end