%% 1. 数据生成 (保持不变)
clear; clc;
rng(42); % 固定种子
N = 15;  % 物品数量
budget = 5;

% 使用之前 Python 生成的同一组数据以便对比
values = [83; 48; 93; 58; 97; 72; 79; 30; 33; 33; 30; 34; 18; 12; 47];
weights = [19; 14; 19; 17; 14; 16; 6; 6; 7; 11; 19; 14; 6; 13; 13];
capacity = sum(weights) * 0.5; 

fprintf('--- 问题规模: %d 个物品, 预算: %d, 容量: %.1f ---\n', N, budget, capacity);

%% 2. YALMIP 建模
% 定义变量
x = binvar(N, 1, 'full'); % 上层 0-1
y = binvar(N, 1, 'full'); % 下层 0-1

% --- 上层约束 ---
C_upper = [sum(x) <= budget];

% --- 下层约束 ---
C_lower = [sum(weights .* y) <= capacity];
C_lower = [C_lower, y <= 1 - x]; % 阻断约束

% --- 目标函数 ---
% 原始下层目标是 Maximize Value
% PowerBiMIP (像大多数求解器一样) 通常默认处理最小化 Min
% 所以我们传入 -Value
Obj_lower_expression = sum(values .* y); 
Obj_lower_for_solver = -Obj_lower_expression; % 转化为 Min

% 上层目标: 防御者想最小化(攻击者的最大收益)
% 注意: 在 PowerBiMIP 中，上层目标通常也是 Min
Obj_upper_for_solver = Obj_lower_expression; 

%% 3. 准备 PowerBiMIP 输入参数
% 这一步非常关键，需要把变量严格分类

% 所有原始变量 (用于最后结果映射)
original_var = [x; y];

% 上层变量分类
var_x_u = [];  % 上层连续变量 (无)
var_z_u = x;   % 上层离散变量 (x)

% 下层变量分类
var_x_l = [];  % 下层连续变量 (无)
var_z_l = y;   % 下层离散变量 (y)

% 求解器选项
ops = BiMIPsettings( ...
    'perspective', 'optimistic', ...    % Perspective: 'optimistic' or 'pessimistic'
    'method', 'exact_strong_duality', ...                % Method: 'exact_KKT', 'exact_strong_duality', or 'quick'
    'solver', 'gurobi', ...             % Specify the underlying MIP solver
    'verbose', 2, ...                   % Verbosity level [0:silent, 1:summary, 2:summary+plots]
    'max_iterations', 100, ...           % Set the maximum number of iterations
    'optimal_gap', 1e-4 ...             % Set the desired optimality gap
    );
% 如果 PowerBiMIP 支持自定义参数，可以在这里加
% ops.custom_params.algorithm = 'CCG'; 

%% 4. 调用 solve_BiMIP 求解
fprintf('\n🚀 正在调用 PowerBiMIP (solve_BiMIP) ...\n');

try
    [Solution, BiMIP_record] = solve_BiMIP(...
        original_var, ...
        var_x_u, var_z_u, ...   % 上层变量
        var_x_l, var_z_l, ...   % 下层变量
        C_upper, C_lower, ...   % 约束
        Obj_upper_for_solver, ... % 上层目标
        Obj_lower_for_solver, ... % 下层目标
        ops ...
    );

    %% 5. 输出结果
    fprintf('\n✅ 求解完成!\n');
    fprintf('上层目标值 (Obj): %.2f\n', Solution.obj);
    
    % 提取数值
    x_val = round(value(x)); 
    y_val = round(value(y));
    
    % 如果 Solution.var 里已经包含了数值，也可以直接用:
    % x_val = round(Solution.var.x); (取决于你的提取函数实现)

    interdicted = find(x_val);
    fprintf('🛡️ 上层阻断了: %s\n', mat2str(interdicted'));
    
    taken = find(y_val);
    fprintf('🎒 下层拿走了: %s\n', mat2str(taken'));
    
    real_attacker_value = sum(values .* y_val);
    fprintf('💰 攻击者实际获得价值: %.1f\n', real_attacker_value);
    
catch ME
    fprintf('\n❌ 调用 solve_BiMIP 失败。\n');
    fprintf('错误信息: %s\n', ME.message);
end