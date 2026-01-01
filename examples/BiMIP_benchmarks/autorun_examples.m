%% 1. 初始化设置
clear; clc;

% --- 新增：设置超时时间 (秒) ---
timeLimit = 15000; 

% 定义输出 Excel 文件名
outputFileName = 'BiMIP_Benchmark_Results_WithTimeout.xlsx';

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

configPrefixes = {'KKT_Cplex', 'Quick_Cplex', 'SD_Gurobi', 'KKT_Gurobi'};

%% 2. 检查并行环境
% 获取当前并形池
p = gcp('nocreate');

% 逻辑：如果不为空且 Worker 数量不是 1，则关闭重建
if ~isempty(p) && p.NumWorkers ~= 1
    delete(p);
    p = [];
end

if isempty(p)
    fprintf('正在启动单核并行池 (以确保严格串行并支持超时)...\n');
    % 核心修改：强制只开启 1 个 Worker
    parpool(1); 
else
    fprintf('使用现有的并行池 (Workers: %d)\n', p.NumWorkers);
end

%% 3. 准备数据结构
numCases = length(funcNames);
numConfigs = size(runConfigs, 1);
numOutputs = 4; % time, iter, obj, gap

totalCols = 1 + (numConfigs * numOutputs) + 1;
resultData = cell(numCases, totalCols);

% 初始化
for i = 1:numCases
    for j = 2:(totalCols-1)
        resultData{i, j} = NaN;
    end
    resultData{i, end} = ''; 
end

% 构建表头
varNames = {'CaseName'};
for k = 1:numConfigs
    p = configPrefixes{k};
    varNames = [varNames, ...
        {[p, '_Time']}, {[p, '_Iter']}, {[p, '_Obj']}, {[p, '_Gap']}]; %#ok<AGROW>
end
varNames = [varNames, {'Notes'}];

%% 4. 循环执行算例
fprintf('开始执行，单次求解超时限制: %d 秒\n', timeLimit);

for i = 1:numCases
    currentFuncName = funcNames{i};
    resultData{i, 1} = currentFuncName;
    
    fprintf('\n======================================================\n');
    fprintf('算例 [%d/%d]: %s\n', i, numCases, currentFuncName);
    
    try
        % 准备函数句柄
        fHandle = str2func(currentFuncName);
        
        for k = 1:numConfigs
            method = runConfigs{k, 1};
            solver = runConfigs{k, 2};
            cfgName = configPrefixes{k};
            
            fprintf('  > 配置 %d [%-20s]... ', k, [method, '+', solver]);
            
            try
                % --- 核心修改：使用 parfeval 异步执行 ---
                % 参数说明: parfeval(函数句柄, 输出参数个数, 输入1, 输入2)
                future = parfeval(fHandle, 4, method, solver);
                
                % 等待结果，直到 timeLimit 秒
                % wait 返回 true 表示完成，false 表示超时
                isFinished = wait(future, 'finished', timeLimit);
                
                if isFinished
                    % --- 正常完成 ---
                    if ~isempty(future.Error)
                        % 如果函数内部报错 (如 MPS 文件找不到)
                        rethrow(future.Error); 
                    end
                    
                    % 获取结果
                    [t, iter, obj, gap] = fetchOutputs(future);
                    
                    % 记录数据
                    startCol = 1 + (k-1)*numOutputs + 1;
                    resultData{i, startCol}     = t;
                    resultData{i, startCol + 1} = iter;
                    resultData{i, startCol + 2} = obj;
                    resultData{i, startCol + 3} = gap;
                    
                    fprintf('成功 (Time=%.2f)\n', t);
                    
                else
                    % --- 超时 ---
                    cancel(future); % 强制杀死后台任务
                    fprintf(2, '超时 ( > %ds) ! \n', timeLimit);
                    
                    % 记录超时信息
                    currentNote = resultData{i, end};
                    newNote = sprintf('[%s: Timeout(%ds)] ', cfgName, timeLimit);
                    resultData{i, end} = [currentNote, newNote];
                    
                    % 数据格保持 NaN，表示未获取到结果
                end
                
            catch ME
                % --- 捕获报错 (无论是函数内报错还是 parfeval 报错) ---
                fprintf('出错! (%s)\n', ME.message);
                currentNote = resultData{i, end};
                newNote = sprintf('[%s Err: %s] ', cfgName, ME.message);
                resultData{i, end} = [currentNote, newNote];
            end
        end
        
    catch ME_Main
        fprintf(2, '无法加载函数: %s\n', ME_Main.message);
        resultData{i, end} = sprintf('Critical: %s', ME_Main.message);
    end
    
    % --- 实时保存 ---
    try
        T = cell2table(resultData, 'VariableNames', varNames);
        writetable(T, outputFileName);
        fprintf('  >> (已保存)\n');
    catch ME_File
        warning(ME_File.identifier, '保存Excel失败: %s', ME_File.message);
    end
end

fprintf('\n全部完成。\n');