% 注意：请先将本工具箱添加到路径中（添加并包含子文件夹）
% 函数功能：用户自定义主函数示例，由用户完成建模后，调用BiMIP求解工具包求解
% min -x - 10z
% s.t. x >= 0
%      -25x+20z <= 30
%      x+2z     <= 10
%      2x-z     <= 15
%      2x+10z   >= 15
%    min  z + 1000y
%    s.t. -25x+20z <= 30+y_1
%         x+2z     <= 10+y_2
%         2x-z     <= 15+y_3
%         2x+10z   >= 15-y_4
%         z        >= 0
%         y        >= 0
% 最优解x=2，z=2（整数变量），obj=-22

%% 环境初始化
dbstop if error
clear; close all; clc; yalmip('clear');
%% 参数加载
% BiMIP求解工具包配置
ops = BiMIPsettings( ...
    'method', 'strong_duality', ...     % 选择求解方法[KKT|strong_duality]
    'solver', 'gurobi', ...      % 选择求解器
    'verbose', 2, ...            % 选择可视化程度：0完全不输出 1命令行输出（不包含ADMM迭代过程） 2命令行+图 3命令行+图+求解器日志
    'RD_max_iterations', 10, ... % 算法最大迭代次数
    'RD_optimal_gap', 1e-4 ... % 算法收敛阈值
    );

%% Variables definition
model.var.x = intvar(1,1,'full');
model.var.z = intvar(1,1,'full');
model.var.y = sdpvar(4,1,'full');

%% Constraints building
% upper-level constraints
model.constraints_upper = [];
model.constraints_upper = model.constraints_upper + ...
    (model.var.x >= 0);
model.constraints_upper = model.constraints_upper + ...
    (-25 * model.var.x + 20 * model.var.z <= 30);
model.constraints_upper = model.constraints_upper + ...
    (model.var.x + 2 * model.var.z <= 10);
model.constraints_upper = model.constraints_upper + ...
    (2 * model.var.x - model.var.z <= 15);
model.constraints_upper = model.constraints_upper + ...
    (2 * model.var.x + 10 * model.var.z >= 15);

% lower-level constraints
model.constraints_lower = [];
model.constraints_lower = model.constraints_lower + ...
    (-25 * model.var.x + 20 * model.var.z <= 30 + model.var.y(1,1) );
model.constraints_lower = model.constraints_lower + ...
    (model.var.x + 2 * model.var.z <= 10 + model.var.y(2,1) );
model.constraints_lower = model.constraints_lower + ...
    (2 * model.var.x - model.var.z <= 15 + model.var.y(3,1) );
model.constraints_lower = model.constraints_lower + ...
    (2 * model.var.x + 10 * model.var.z >= 15 - model.var.y(4,1) );
model.constraints_lower = model.constraints_lower + ...
    (model.var.z >=0 );
model.constraints_lower = model.constraints_lower + ...
    (model.var.y >= 0);

%% Objective building
% ***Note that if the objective function is a maximization problem, it
% should be converted into a minimization problem by taking the
% negative value.***
% upper-level objective
model.objective_upper = -model.var.x - 10 * model.var.z;
% lower-level objective
model.objective_lower = model.var.z + 1e3*sum(model.var.y,'all');

%% 变量
model.var_xu = [];
model.var_zu = [reshape(model.var.x, [], 1)];
model.var_xl = [reshape(model.var.y, [], 1)];
model.var_zl = [reshape(model.var.z, [], 1)];

%% 调用BiMILP求解器
[Solution, BiMILP_record, coefficients] = solve_BiMILP(model.var, ...
    model.var_xu, model.var_zu, model.var_xl, model.var_zl, ...
    model.constraints_upper, model.constraints_lower, ...
    model.objective_upper, model.objective_lower, ops);