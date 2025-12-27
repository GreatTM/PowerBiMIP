function run_moore90_2()
%==========================================================================
% run_moore90_2
%--------------------------------------------------------------------------
% 作用：
%   读取 moore90_2.mps + moore90_2.aux 定义的双层混合整数规划(BiMIP)算例，
%   将其转换为 PowerBiMIP 所需的 bimip_model 结构体（严格字段格式），
%   然后调用 PowerBiMIP 主接口 solve_BiMIP 进行求解，并打印结果。
%
% 输入：
%   无（本脚本内部写死文件路径；如需批处理可改为函数参数）
%
% 输出：
%   无（在命令行打印 Solution 与 BiMIP_record，并可按需保存到本地）
%
% 依赖：
%   1) YALMIP 已安装并在 MATLAB path 中
%   2) PowerBiMIP 已 addpath（包含 solve_BiMIP 与 BiMIPsettings）
%   3) 已有 "mpsaux2yalmip.m" 转换器（上一问我给你的那个函数）
%==========================================================================

    clc; clearvars;

    %---------------------------
    % 0) 环境清理（PowerBiMIP 要求非常干净的 YALMIP 环境）
    %---------------------------
    yalmip('clear');

    %---------------------------
    % 1) 指定算例路径
    %---------------------------
    this_dir = fileparts(mfilename('fullpath'));
    
    aux_path = fullfile(this_dir, "moore90_2.aux");
    mps_path = fullfile(this_dir, "moore90_2.mps");

    if ~isfile(aux_path)
        error('找不到 AUX 文件：%s', aux_path);
    end
    if ~isfile(mps_path)
        error('找不到 MPS 文件：%s', mps_path);
    end

    %---------------------------
    % 2) 转换：MPS+AUX -> YALMIP 双层结构体
    %    注意：solve_BiMIP 要求 bimip_model 字段严格一致
    %---------------------------
    % 这里调用你上一问的转换器（请确保 mpsaux2yalmip.m 在 MATLAB path）
    model_raw = mpsaux2yalmip(mps_path, aux_path);

    % 将输出字段名对齐 PowerBiMIP 要求（严格字段）
    bimip_model = struct();
    bimip_model.var_upper  = model_raw.var_upper;
    bimip_model.var_lower  = model_raw.var_lower;
    bimip_model.cons_upper = model_raw.cons_upper;
    bimip_model.cons_lower = model_raw.cons_lower;
    bimip_model.obj_upper  = model_raw.obj_upper;
    bimip_model.obj_lower  = model_raw.obj_lower;

    %---------------------------
    % 3) 设置求解参数（可按需修改）
    %---------------------------
    % 说明：
    %   - method: exact_KKT / exact_strong_duality / quick
    %   - solver: gurobi（你也可以换 cplex 等，但需已安装）
    %   - verbose: 0~3
    ops = BiMIPsettings( ...
        'perspective',   'optimistic', ...
        'method',        'exact_strong_duality', ...
        'solver',        'gurobi', ...
        'max_iterations', 50, ...
        'optimal_gap',   1e-6, ...
        'verbose',       2, ...
        'plot.verbose',  0);

    %---------------------------
    % 4) 调用 PowerBiMIP 求解
    %---------------------------
    fprintf('\n============================================================\n');
    fprintf('Solving instance: moore90_2\n');
    fprintf('MPS: %s\nAUX: %s\n', mps_path, aux_path);
    fprintf('============================================================\n');

    try
        [Solution, BiMIP_record] = solve_BiMIP(bimip_model, ops);
    catch ME
        fprintf(2, '\nPowerBiMIP 求解失败：%s\n', ME.message);
        rethrow(ME);
    end

    %---------------------------
    % 5) 输出结果（Solution 的具体字段由 myFun_GetValue 决定）
    %---------------------------
    fprintf('\n====================  Solution Summary  ====================\n');
    disp(Solution);

    fprintf('\n====================  Solver Record  ========================\n');
    disp(BiMIP_record);

    %---------------------------
    % 6)（可选）进一步打印上层/下层变量数值
    %---------------------------
    % 如果 Solution 中不包含你想要的字段，也可以直接用 value()：
    % 注意：PowerBiMIP 末尾调用 myFun_GetValue(bimip_model)，
    %       通常会把 var_upper/var_lower 的 value 返回到 Solution。
    %
    % 这里做一个稳妥的兜底打印：
    try
        xu = value(bimip_model.var_upper);
        xl = value(bimip_model.var_lower);
        fprintf('\nUpper-level vars value:\n');
        disp(xu);
        fprintf('Lower-level vars value:\n');
        disp(xl);

        fprintf('Upper-level objective value: %.10g\n', value(bimip_model.obj_upper));
        fprintf('Lower-level objective value: %.10g\n', value(bimip_model.obj_lower));
    catch
        % 若 value() 不可用（例如某些情况下变量被 recover 重建不在同一空间），忽略
        fprintf('(提示) 未能通过 value() 直接读取变量值，建议查看 Solution 结构体内容。\n');
    end

    fprintf('\nDone.\n');

end
