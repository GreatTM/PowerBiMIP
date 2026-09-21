function P2_VSP_N22_L77_B200_C14()
%==========================================================================
% run_VSP_N22_L77_B200_C14
%==========================================================================
    clc; clearvars;
    %---------------------------
    % 1) 清理 YALMIP 环境
    %---------------------------
    yalmip('clear');
    this_dir = fileparts(mfilename('fullpath'));
    
    aux_path = fullfile(this_dir, "VSP_N22_L77_B200_C14.aux");
    mps_path = fullfile(this_dir, "VSP_N22_L77_B200_C14.mps");
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
    % 3) 求解参数设置
    %---------------------------
    % 你也可以将 method 改为 'exact_strong_duality' 或 'quick'
    ops = BiMIPsettings( ...
        'perspective',    'optimistic', ...
        'method',         'exact_KKT', ...
        'solver',         'gurobi', ...
        'max_iterations', 200, ...
        'optimal_gap',    1e-6, ...
        'verbose',        2, ...
        'plot.verbose',   0);
    %---------------------------
    % 4) 调用 PowerBiMIP 求解
    %---------------------------
    fprintf('\n============================================================\n');
    fprintf('Solving instance: VSP_N22_L77_B200_C14\n');
    fprintf('MPS: %s\nAUX: %s\n', mps_path, aux_path);
    fprintf('============================================================\n');
    try
        [Solution, BiMIP_record] = solve_BiMIP(bimip_model, ops);
    catch ME
        fprintf(2, '\nPowerBiMIP 求解失败：%s\n', ME.message);
        rethrow(ME);
    end
end