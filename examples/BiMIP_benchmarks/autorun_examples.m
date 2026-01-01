%% 1. 初始化设置
clear; clc;

% 定义输出 Excel 文件名
outputFileName = 'BiMIP_Benchmark_Results.xlsx';

% 定义你要运行的函数列表
funcNames = { ...
    'run_neos5_0_100', ...
    'run_exp_1_500_5_5_50_50', ...
    'run_bmilplib_360_1', ...
    'run_general20_20_10_20_20_3', ...
    'run_neos17_0_100', ...
    'run_neos_3754480_nidda_0_100', ...
    'run_nexp_150_20_8_5_0_100', ...
    'run_noswot_0_100', ...
    'run_xuLarge500_1', ...
    'run_xuLarge1000_1', ...
    'run_50v_10_0_100', ...
    'run_biella1_0_100', ...
    'run_fiball_0_100', ...
    'run_binkar10_1_0_100' ...
};

% 定义 4 种输入配置 (Method, Solver)
runConfigs = {
    'exact_KKT',            'cplex';   % Config 1
    'quick',                'cplex';   % Config 2
    'exact_strong_duality', 'gurobi';  % Config 3
    'exact_KKT',            'gurobi'   % Config 4
};

% 定义配置对应的前缀 (Excel表头用)
configPrefixes = {'KKT_Cplex', 'Quick_Cplex', 'SD_Gurobi', 'KKT_Gurobi'};

%% 2. 准备表头
numCases = length(funcNames);
numConfigs = size(runConfigs, 1);
numOutputs = 4; % time, iter, obj, gap
% 计算总列数：1(函数名) + 配置数*4输出 + 1(备注信息)
totalCols = 1 + (numConfigs * numOutputs) + 1;

% --- 构建表头 ---
varNames = {'CaseName'};
for k = 1:numConfigs
    p = configPrefixes{k};
    varNames = [varNames, ...
        {[p, '_Time']}, {[p, '_Iter']}, {[p, '_Obj']}, {[p, '_Gap']}]; %#ok<AGROW>
end
varNames = [varNames, {'Notes'}];

% 为了在Workspace里也能看到完整结果，保留这个大矩阵（可选）
% 但写入Excel时我们不再使用它，而是使用单行变量
fullResultData = cell(numCases, totalCols);

%% 3. 循环执行算例并实时追加写入 (Append Mode)
fprintf('开始执行 %d 个算例，结果将追加至: %s\n', numCases, outputFileName);

for i = 1:numCases
    currentFuncName = funcNames{i};
    
    % --- 初始化当前行的临时数据 ---
    % 每一行初始化为 NaN，最后一位为空字符串
    currentRow = cell(1, totalCols);
    for c = 2:totalCols-1
        currentRow{c} = NaN; 
    end
    currentRow{1} = currentFuncName; % 第一列填名字
    currentRow{end} = '';            % 最后一列初始化 Note
    
    fprintf('\n------------------------------------------------------\n');
    fprintf('正在处理算例 [%d/%d]: %s\n', i, numCases, currentFuncName);
    
    try
        % 加载函数句柄
        f = str2func(currentFuncName);
        
        % 内部循环：依次执行 4 种配置
        for k = 1:numConfigs
            method = runConfigs{k, 1};
            solver = runConfigs{k, 2};
            cfgName = configPrefixes{k};
            
            fprintf('  > 配置 %d [%s + %s]... ', k, method, solver);
            
            try
                % --- 执行函数 ---
                [t, iter, obj, gap] = f(method, solver);
                
                % --- 填入当前行数据 ---
                % 计算列索引：1(名字) + (k-1)*4 + 1(偏移)
                startCol = 1 + (k-1)*numOutputs + 1; 
                
                currentRow{startCol}     = t;
                currentRow{startCol + 1} = iter;
                currentRow{startCol + 2} = obj;
                currentRow{startCol + 3} = gap;
                
                fprintf('成功 (Time=%.2f)\n', t);
                
            catch ME
                % --- 捕获单个配置错误 ---
                fprintf('失败! (%s)\n', ME.message);
                % 追加错误信息到 Note 列
                currentNote = currentRow{end};
                newNote = sprintf('[%s Err: %s] ', cfgName, ME.message);
                currentRow{end} = [currentNote, newNote];
            end
        end
        
    catch ME_Main
        % 函数本身加载失败
        fprintf(2, '无法运行函数 %s: %s\n', currentFuncName, ME_Main.message);
        currentRow{end} = sprintf('Critical: %s', ME_Main.message);
    end
    
    % 将当前行存入总结果（仅用于Workspace查看，不影响Excel写入）
    fullResultData(i, :) = currentRow;
    
    % ==========================================================
    % 核心修改：每跑完一个算例，构建单行 Table 并追加写入
    % ==========================================================
    try
        % 1. 将当前行的 cell 转换为 table
        T_row = cell2table(currentRow, 'VariableNames', varNames);
        
        % 2. 判断文件是否存在
        if exist(outputFileName, 'file')
            % --- 情况 A: 文件已存在，使用追加模式 (Append) ---
            % 'WriteMode', 'append' 会自动写在最后一行下面
            writetable(T_row, outputFileName, 'WriteMode', 'append');
            fprintf('  >> (已追加写入 Excel)\n');
        else
            % --- 情况 B: 文件不存在，创建新文件 ---
            % 第一次写入时，默认会包含表头
            writetable(T_row, outputFileName);
            fprintf('  >> (新建文件并写入 Excel)\n');
        end
        
    catch ME_File
        warning('SaveError:Excel', '写入 Excel 失败 (请确保文件未被打开): %s', ME_File.message);
    end
end

fprintf('\n------------------------------------------------------\n');
fprintf('全部完成。请检查: %s\n', outputFileName);