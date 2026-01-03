function run_T1_3_1()
%==========================================================================
% run_T1-3-1
%--------------------------------------------------------------------------
% 作用：
%   求解算例 T1-3-1（由 .mps + .aux 定义的 BiMIP）。
%   流程：
%     1) yalmip('clear') 清理环境（PowerBiMIP 强制要求）
%     2) 调用 mpsaux2yalmip(mps_path, aux_path) 转换为 YALMIP 双层对象
%     3) 组装 bimip_model（严格字段）并调用 solve_BiMIP
%     4) 打印 Solution 与 BiMIP_record，并尝试打印变量值与目标值
%
% 输入：
%   无（路径在脚本内写死；如需批量求解可改成函数入参）
%
% 输出：
%   无（命令行输出；可按需保存 mat 结果）
%
% 依赖：
%   - YALMIP 已安装并 addpath
%   - PowerBiMIP 已 addpath（solve_BiMIP / BiMIPsettings 等）
%   - mpsaux2yalmip.m 已在 MATLAB path（包含你已修复的 RHS 段识别 bug）
%==========================================================================

    clc; clearvars;

    %---------------------------
    % 0) 清理 YALMIP 环境（必须）
    %---------------------------
    yalmip('clear');

    this_dir = fileparts(mfilename('fullpath'));
    
    aux_path = fullfile(this_dir, "T1-3-1.aux");
    mps_path = fullfile(this_dir, "T1-3-1.mps");

    if ~isfile(aux_path)
        error('找不到 AUX 文件：%s', aux_path);
    end
    if ~isfile(mps_path)
        error('找不到 MPS 文件：%s', mps_path);
    end

    %---------------------------
    % 2) 转换：MPS+AUX -> YALMIP 双层结构体（model_raw）
    %---------------------------
    model_raw = mpsaux2yalmip(mps_path, aux_path);

    % PowerBiMIP 的输入结构体必须"严格字段"
    bimip_model = struct();
    bimip_model.var_upper  = model_raw.var_upper;
    bimip_model.var_lower  = model_raw.var_lower;
    bimip_model.cons_upper = model_raw.cons_upper;
    bimip_model.cons_lower = model_raw.cons_lower;
    bimip_model.obj_upper  = model_raw.obj_upper;
    bimip_model.obj_lower  = model_raw.obj_lower;

    %---------------------------
    % 3) 求解参数设置（按需改）
    %---------------------------
    % 你也可以将 method 改为 'exact_strong_duality' 或 'quick'
    ops = BiMIPsettings( ...
        'perspective',    'optimistic', ...
        'method',         'exact_strong_duality', ...
        'solver',         'gurobi', ...
        'max_iterations', 200, ...
        'optimal_gap',    1e-6, ...
        'verbose',        3, ...
        'plot.verbose',   0);

    %---------------------------
    % 4) 调用 PowerBiMIP 求解
    %---------------------------
    fprintf('\n============================================================\n');
    fprintf('Solving instance: T1-3-1\n');
    fprintf('MPS: %s\nAUX: %s\n', mps_path, aux_path);
    fprintf('============================================================\n');

    try
        [Solution, BiMIP_record] = solve_BiMIP(bimip_model, ops);
    catch ME
        fprintf(2, '\nPowerBiMIP 求解失败：%s\n', ME.message);
        rethrow(ME);
    end

    %---------------------------
    % 5) 输出结果
    %---------------------------
    fprintf('\n====================  Solution Summary  ====================\n');
    disp(Solution);

    fprintf('\n====================  Solver Record  ========================\n');
    disp(BiMIP_record);

    %---------------------------
    % 6)（可选）打印变量值与目标值（兜底）
    %---------------------------
    try
        xu = value(bimip_model.var_upper);
        xl = value(bimip_model.var_lower);

        fprintf('\nUpper-level vars value (first 20 entries):\n');
        disp(xu(1:min(end,20)));

        fprintf('Lower-level vars value (first 20 entries):\n');
        disp(xl(1:min(end,20)));

        fprintf('Upper-level objective value: %.16g\n', value(bimip_model.obj_upper));
        fprintf('Lower-level objective value: %.16g\n', value(bimip_model.obj_lower));
    catch
        fprintf('(提示) 未能通过 value() 直接读取变量值/目标值，请查看 Solution 结构体。\n');
    end

    %---------------------------
    % 7)（可选）保存结果
    %---------------------------
    % out_dir = fullfile(pwd, "results");
    % if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    % save(fullfile(out_dir, "neos-3754480-nidda_0_100_solution.mat"), ...
    %     "Solution", "BiMIP_record", "ops");

    fprintf('\nDone.\n');

end
