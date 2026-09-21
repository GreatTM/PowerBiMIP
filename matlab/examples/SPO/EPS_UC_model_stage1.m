% 函数功能：电力系统机组组合模型第一阶段建模 (日前调度)
% 输入：系统数据、负荷/新能源数据、新能源预测值
% 输出：yalmip变量、约束、目标函数
function [var, cons, obj] = EPS_UC_model_stage1(system_data, data, pres_forecast)
    %% 硬编码参数
    RES_CURTAILMENT = 0;  % 不允许弃风
    LOAD_SHEDDING = 1;    % 允许切负荷
    
    %% 基础校验
    assert(mod(data.Ntime, 24) == 0, '时间维度必须是24的整数倍');
    num_blocks = data.Ntime / 24;
    history_length = 10;
    
    %% 定义决策变量
    var.u = binvar(system_data.Ngen, data.Ntime, 'full');  % 机组状态
    var.v = binvar(system_data.Ngen, data.Ntime, 'full');  % 启动
    var.w = binvar(system_data.Ngen, data.Ntime, 'full');  % 停机
    var.pgen = sdpvar(system_data.Ngen, data.Ntime, 'full');  % 出力
    var.ru = sdpvar(system_data.Ngen, data.Ntime, 'full');  % 上备用
    var.rd = sdpvar(system_data.Ngen, data.Ntime, 'full');  % 下备用
    var.rescurtailment = sdpvar(system_data.Nrenewablegen, data.Ntime, 'full');  % 弃风
    var.loadshedding = sdpvar(system_data.Nload, data.Ntime, 'full');  % 切负荷

    %% 约束定义
    cons = [];
    
    % 出力非负
    cons = cons + (var.pgen >= 0);
    
    % 出力上下限
    cons = cons + (var.pgen <= var.u .* (system_data.plimit.upper * ones(1, data.Ntime)));
    cons = cons + (var.pgen >= var.u .* (system_data.plimit.lower * ones(1, data.Ntime)));
    
    % 弃风约束
    if RES_CURTAILMENT
        cons = cons + (var.rescurtailment >= 0);
        cons = cons + (var.rescurtailment <= pres_forecast');
    end
    
    % 切负荷约束
    if LOAD_SHEDDING
        cons = cons + (var.loadshedding >= 0);
        cons = cons + (var.loadshedding <= data.pload_realization_data');
    end
    
    %% 时间耦合约束（分周期处理）
    for block = 1:num_blocks
        t_start = (block - 1) * 24 + 1;
        t_end = block * 24;
        t_range = t_start:t_end;
        
        % 带历史状态的变量
        u_history = [zeros(system_data.Ngen, history_length), var.u(:, t_range)];
        v_history = [zeros(system_data.Ngen, history_length), var.v(:, t_range)];
        w_history = [zeros(system_data.Ngen, history_length), var.w(:, t_range)];
        
        % 启停逻辑: u(t) - u(t-1) = v(t) - w(t)
        for t = 1:24
            cons = cons + (u_history(:, history_length + t) - u_history(:, history_length + t - 1) ...
                == v_history(:, history_length + t) - w_history(:, history_length + t));
        end
    end

    %% 能量平衡与潮流
    renewable_power = pres_forecast' - var.rescurtailment .* RES_CURTAILMENT;
    load_power = data.pload_realization_data' - var.loadshedding .* LOAD_SHEDDING;
    
    % 功率平衡
    cons = cons + (sum(var.pgen, 1) + sum(renewable_power, 1) == sum(load_power, 1));
    
    % 直流潮流
    branch_flow = system_data.PTDF.gen * var.pgen + ...
                  system_data.PTDF.renewablegen * renewable_power - ...
                  system_data.PTDF.load * load_power;
    cons = cons + ((system_data.pbranchlimit.lower * ones(1, data.Ntime)) <= branch_flow);
    cons = cons + (branch_flow <= (system_data.pbranchlimit.upper * ones(1, data.Ntime)));

    %% 目标函数
    var.cost_terms = [
        sum((system_data.cost.c1 * ones(1, data.Ntime)) .* var.pgen, 'all')       % 燃料成本
        sum((system_data.cost.c0 * ones(1, data.Ntime)) .* var.u, 'all')          % 空载成本
        sum((system_data.cost.startup * ones(1, data.Ntime)) .* var.v, 'all')     % 启动成本
        sum((system_data.cost.shutdown * ones(1, data.Ntime)) .* var.w, 'all')    % 停机成本
        200 * sum(var.rescurtailment, 'all') * RES_CURTAILMENT                    % 弃风惩罚
        1000 * sum(var.loadshedding, 'all') * LOAD_SHEDDING                       % 切负荷惩罚
    ];
    obj = sum(var.cost_terms);
end
