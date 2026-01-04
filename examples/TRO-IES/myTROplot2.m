%% ========================================================================
% Main Script: 4 Subplots Vertical Layout (Shared Legend/Labels)
% =========================================================================

clear; clc; close all;

% 1. 载入数据
% -------------------------------------------------------------------------
dataFile = "E:\3. Toolbox\PowerBiMIP\results\figures\matlab.mat";
if isfile(dataFile)
    load(dataFile);
else
    error('文件未找到: %s', dataFile);
end

% 2. 创建画布与布局
% -------------------------------------------------------------------------
% 画布变高一点，容纳4张图 [100, 50, 800, 800]
figHandle = figure('NumberTitle', 'off', 'Position', [100, 50, 800, 800], 'Color', 'w');

% 使用 tiledlayout (4行 1列)
% 'TileSpacing', 'compact' 让子图之间紧凑一些
% 'Padding', 'compact' 让图表边缘留白少一些
t = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% 3. 循环绘图
% -------------------------------------------------------------------------
num_RD_iterations = 4; % 强制画4张，或者用 Robust_record.cuts_count

% 用于存储图例句柄
hLegLines = []; 

for k = 1:num_RD_iterations
    % === 获取当前图块 (Next Tile) ===
    ax = nexttile; 
    
    % === 数据提取 (同之前逻辑) ===
    if k <= length(Robust_record.subproblem_solution)
        current_cell = Robust_record.subproblem_solution{1, k};
        if isempty(current_cell) || ~isfield(current_cell, 'sp_solution')
            continue;
        end
        sp_sol = current_cell.sp_solution;
        obj1 = -sp_sol.padm1_objectives;
        % 处理 obj2 (可能不存在)
        if isfield(sp_sol, 'padm2_objectives')
            obj2 = -sp_sol.padm2_objectives;
        else
            obj2 = nan(size(obj1));
        end
        gap = sp_sol.padm_gap;
        iters = 1:length(obj1);
        
        % === 数据清洗：隐藏第一个离群点 ===
        if abs(obj1(1)) > 100 * mean(abs(obj1(2:end)))
            obj1(1) = NaN;
            obj2(1) = NaN;
        end
    else
        continue; 
    end

    % =====================================================================
    % 绘图操作
    % =====================================================================
    
    % --- 左轴 (Linear) ---
    yyaxis left;
    axLeft = gca;
    hold on;
    
    l1 = plot(iters, obj1, 'rs-', 'LineWidth', 1, 'MarkerSize', 5, ...
        'DisplayName', '\fontname{SimSun}子问题 1');
    l2 = plot(iters, obj2, 'b^-', 'LineWidth', 1, 'MarkerSize', 5, ...
        'DisplayName', '\fontname{SimSun}子问题 2');
    
    % Y轴标签 (每个图都留着，不然看不清数值对应的物理意义)
    ylabel('\fontname{SimSun}目标函数值', 'FontName', 'Times New Roman', 'FontSize', 10);
    set(axLeft, 'YColor', 'k', 'YScale', 'linear');
    
    % --- 右轴 (Log) ---
    yyaxis right;
    axRight = gca;
    
    l3 = plot(iters, gap, 'ko--', 'LineWidth', 1, 'MarkerSize', 5, ...
        'DisplayName', 'Gap (%)');
    
    ylabel('Gap (%)', 'FontName', 'Times New Roman', 'FontSize', 10);
    set(axRight, 'YColor', 'k', 'YScale', 'log');

    % --- 坐标轴通用设置 ---
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, 'LineWidth', 0.75);
    grid on; box on; grid minor;
    
    % --- 关键：X轴标签控制 ---
    % 只有最下面一张图 (k=4) 显示 "PADM 迭代次数"
    % 上面的图 (k=1,2,3) 保持X轴刻度数字，但不显示文字标签，节省空间
    if k == num_RD_iterations
        xlabel('PADM \fontname{SimSun}迭代次数', 'FontName', 'Times New Roman', 'FontSize', 11);
    else
        xlabel(''); % 上面的图不要标签
    end
    
    % (可选) 给每个子图加个小序号 (a), (b), (c), (d)
    % text(0.02, 0.9, sprintf('(%c)', 96+k), 'Units', 'normalized', ...
    %      'FontName', 'Times New Roman', 'FontSize', 11, 'FontWeight', 'bold');

    % --- 收集图例句柄 (只收集第一次) ---
    if k == 1
        hLegLines = [l1, l2, l3];
    end
    
    hold off;
end

% 4. 添加共享图例 (顶部)
% -------------------------------------------------------------------------
% 这里的 Layout.Tile = 'north' 会把图例放在所有子图的顶端外部
lgd = legend(hLegLines, 'Orientation', 'horizontal');
lgd.Layout.Tile = 'north'; 
lgd.Box = 'off';
lgd.FontName = 'Times New Roman';
lgd.FontSize = 10;

% 5. 保存
% -------------------------------------------------------------------------
saveDir = 'results\figures\PADM_Plots_Combined\';
if ~exist(saveDir, 'dir'), mkdir(saveDir); end
exportgraphics(figHandle, fullfile(saveDir, 'PADM_Convergence_Combined.png'), 'Resolution', 300);
savefig(figHandle, fullfile(saveDir, 'PADM_Convergence_Combined.fig'));

fprintf('组合图已保存。\n');