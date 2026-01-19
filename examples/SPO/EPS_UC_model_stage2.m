% 函数功能：电力系统机组组合模型第二阶段建模 (实时再调度)
% 输入：系统数据、负荷/新能源数据、第一阶段变量
% 输出：yalmip变量、约束、目标函数
function [var, cons, obj] = EPS_UC_model_stage2(system_data, data, first_stage_var)
    %% 硬编码参数
    RES_CURTAILMENT = 0;  % 不允许弃风
    LOAD_SHEDDING = 1;    % 允许切负荷
    
    %% 基础校验
    assert(mod(data.Ntime, 24) == 0, '时间维度必须是24的整数倍');

    %% 定义决策变量
    var.pgen_up = sdpvar(system_data.Ngen, data.Ntime, 'full');    % 上调出力
    var.pgen_down = sdpvar(system_data.Ngen, data.Ntime, 'full');  % 下调出力
    var.ru_2stage = sdpvar(system_data.Ngen, data.Ntime, 'full');
    var.rd_2stage = sdpvar(system_data.Ngen, data.Ntime, 'full');
    var.rescurtailment_2stage = sdpvar(system_data.Nrenewablegen, data.Ntime, 'full');
    var.loadshedding_2stage = sdpvar(system_data.Nload, data.Ntime, 'full');

    %% 约束定义
    cons = [];
    
    % 非负约束
    cons = cons + (var.pgen_up >= 0);
    cons = cons + (var.pgen_down >= 0);
    
    % 调整后出力的上下限
    adjusted_pgen = first_stage_var.pgen + var.pgen_up - var.pgen_down;
    cons = cons + (adjusted_pgen <= first_stage_var.u .* (system_data.plimit.upper * ones(1, data.Ntime)));
    cons = cons + (adjusted_pgen >= first_stage_var.u .* (system_data.plimit.lower * ones(1, data.Ntime)));

    % 弃风约束
    if RES_CURTAILMENT
        cons = cons + (var.rescurtailment_2stage >= 0);
        cons = cons + (var.rescurtailment_2stage <= data.pres_realization_data');
    end
    
    % 切负荷约束
    if LOAD_SHEDDING
        cons = cons + (var.loadshedding_2stage >= 0);
        cons = cons + (var.loadshedding_2stage <= data.pload_realization_data');
    end

    %% 能量平衡与潮流
    renewable_power = data.pres_realization_data' - var.rescurtailment_2stage .* RES_CURTAILMENT;
    load_power = data.pload_realization_data' - var.loadshedding_2stage .* LOAD_SHEDDING;
    
    % 功率平衡
    cons = cons + (sum(adjusted_pgen, 1) + sum(renewable_power, 1) == sum(load_power, 1));
    
    % 直流潮流
    branch_flow = system_data.PTDF.gen * adjusted_pgen + ...
                  system_data.PTDF.renewablegen * renewable_power - ...
                  system_data.PTDF.load * load_power;
    cons = cons + ((system_data.pbranchlimit.lower * ones(1, data.Ntime)) <= branch_flow);
    cons = cons + (branch_flow <= (system_data.pbranchlimit.upper * ones(1, data.Ntime)));
    
    %% 目标函数
    cost_term = [
        sum((system_data.cost.c1 * ones(1, data.Ntime)) .* first_stage_var.pgen, 'all')            % 燃料成本
        sum((system_data.cost.c0 * ones(1, data.Ntime)) .* first_stage_var.u, 'all')               % 空载成本
        sum((system_data.cost.startup * ones(1, data.Ntime)) .* first_stage_var.v, 'all')         % 启动成本
        sum((system_data.cost.shutdown * ones(1, data.Ntime)) .* first_stage_var.w, 'all')        % 停机成本
        sum((system_data.cost.compensation_up * ones(1, data.Ntime)) .* var.pgen_up, 'all')       % 上调补偿
        sum((system_data.cost.compensation_down * ones(1, data.Ntime)) .* var.pgen_down, 'all')   % 下调补偿
        200 * sum(var.rescurtailment_2stage, 'all') * RES_CURTAILMENT                             % 弃风惩罚
        1000 * sum(var.loadshedding_2stage, 'all') * LOAD_SHEDDING                                % 切负荷惩罚
    ];
    obj = sum(cost_term);
    
    var.cost_terms = [
        sum((system_data.cost.compensation_up * ones(1, data.Ntime)) .* var.pgen_up, 'all')
        sum((system_data.cost.compensation_down * ones(1, data.Ntime)) .* var.pgen_down, 'all')
        200 * sum(var.rescurtailment_2stage, 'all') * RES_CURTAILMENT
        1000 * sum(var.loadshedding_2stage, 'all') * LOAD_SHEDDING
    ];
end
