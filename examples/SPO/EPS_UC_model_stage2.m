function [var, cons, obj] = EPS_UC_model_stage2(parameter, system_data, data, first_stage_var)
    %% 基础校验
    assert(mod(data.Ntime,24)==0, '时间维度必须是24的整数倍');
    num_blocks = data.Ntime / 24;

    %% 定义决策变量
    var.pgen_up = sdpvar(system_data.Ngen,data.Ntime,'full');
    var.pgen_down = sdpvar(system_data.Ngen,data.Ntime,'full');
    var.ru_2stage = sdpvar(system_data.Ngen,data.Ntime,'full');
    var.rd_2stage = sdpvar(system_data.Ngen,data.Ntime,'full');
    
    % 使用参数开关定义可选变量
    var.rescurtailment_2stage = sdpvar(system_data.Nrenewablegen, data.Ntime, 'full');
    var.loadshedding_2stage = sdpvar(system_data.Nload, data.Ntime, 'full');

    %% 变量上下限约束
    cons = [];
    % 非负约束
    cons = cons + (var.pgen_up >= 0);
    cons = cons + (var.pgen_down >= 0);
    cons = cons + (var.ru_2stage >= 0);
    cons = cons + (var.rd_2stage >= 0);
    % % 旋转备用上下限
    % cons = cons + ...
    %     (var.ru_2stage <= first_stage_var.u .* (system_data.ramplimit.up * ones(1,data.Ntime)));
    % cons = cons + ...
    %     (var.rd_2stage <= first_stage_var.u .* (system_data.ramplimit.down * ones(1,data.Ntime)));
    % 出力上下限约束
    adjusted_pgen = first_stage_var.pgen + var.pgen_up - var.pgen_down;
    % cons = cons + ...
    %     (adjusted_pgen + var.ru_2stage <= first_stage_var.u .* (system_data.plimit.upper * ones(1,data.Ntime)));
    % cons = cons + ...
    %     (adjusted_pgen - var.rd_2stage >= first_stage_var.u .* (system_data.plimit.lower * ones(1,data.Ntime)));
    cons = cons + ...
        (adjusted_pgen <= first_stage_var.u .* (system_data.plimit.upper * ones(1,data.Ntime)));
    cons = cons + ...
        (adjusted_pgen >= first_stage_var.u .* (system_data.plimit.lower * ones(1,data.Ntime)));

   % 新能源弃风约束
    if parameter.res_curtailment
        cons = cons + (var.rescurtailment_2stage >= 0);
        cons = cons + (var.rescurtailment_2stage <= data.pres_realization_data');
    end
    
    % 切负荷约束
    if parameter.load_shedding
        cons = cons + (var.loadshedding_2stage >= 0);
        cons = cons + (var.loadshedding_2stage <= data.pload_realization_data');
    end

    % %% 爬坡约束（分周期处理）
    % for block = 1:num_blocks
    %     t_start = (block-1)*24 + 1;
    %     t_end = block*24;
    %     t_range = t_start:t_end;
    % 
    %     % 当前块出力变量
    %     block_pgen = first_stage_var.pgen(:,t_range) + var.pgen_up(:,t_range) - var.pgen_down(:,t_range);
    % 
    %     % ====== 爬坡约束 ======
    %     delta_pgen = diff(block_pgen, 1, 2);
    %     cons = cons + ((-system_data.ramplimit.down * ones(1, 23)) <= delta_pgen);
    %     cons = cons + (delta_pgen <= (system_data.ramplimit.up * ones(1, 23)));
    % end

    % %% 旋转备用约束
    % cons = cons + ...
    %     (sum(var.ru_2stage,1) >= 0.05 * sum(data.pload_realization_data,2)');
    % cons = cons + ...
    %     (sum(var.rd_2stage,1) >= 0.05 * sum(data.pload_realization_data,2)');

    %% 统一能量平衡与潮流约束
    renewable_power = data.pres_realization_data' - var.rescurtailment_2stage.*parameter.res_curtailment;
    load_power = data.pload_realization_data' - var.loadshedding_2stage.*parameter.load_shedding;
    
    % 能量平衡
    cons = cons + ...
        (sum(first_stage_var.pgen + var.pgen_up - var.pgen_down,1) + sum(renewable_power,1) == sum(load_power,1));
    
    % 直流潮流
    branch_flow = system_data.PTDF.gen * (first_stage_var.pgen + var.pgen_up - var.pgen_down) + ...
                 system_data.PTDF.renewablegen * renewable_power - ...
                 system_data.PTDF.load * load_power;
    cons = cons + ((system_data.pbranchlimit.lower * ones(1,data.Ntime)) <= branch_flow);
    cons = cons + ((branch_flow <= system_data.pbranchlimit.upper * ones(1,data.Ntime)));
    
    %% 统一目标函数
    cost_term = [
        sum((system_data.cost.c1 * ones(1,data.Ntime)) .* first_stage_var.pgen, 'all')      % 燃料成本
        sum((system_data.cost.c0 * ones(1,data.Ntime)) .* first_stage_var.u, 'all')         % 空载成本
        sum((system_data.cost.startup * ones(1,data.Ntime)) .* first_stage_var.v, 'all')         % 启停成本（新增）
        sum((system_data.cost.shutdown * ones(1,data.Ntime)) .* first_stage_var.w, 'all')        % 启停成本（新增）
        sum((system_data.cost.compensation_up * ones(1,data.Ntime)) .* var.pgen_up, 'all')  % 上调补偿
        sum((system_data.cost.compensation_down * ones(1,data.Ntime)) .* var.pgen_down, 'all') % 下调补偿
        200 * sum(var.rescurtailment_2stage, 'all') .* parameter.res_curtailment
        1000 * sum(var.loadshedding_2stage, 'all') .* parameter.load_shedding
    ];
    obj = sum(cost_term);
    var.cost_terms = [
        sum((system_data.cost.compensation_up * ones(1,data.Ntime)) .* var.pgen_up, 'all')  % 上调补偿
        sum((system_data.cost.compensation_down * ones(1,data.Ntime)) .* var.pgen_down, 'all') % 下调补偿
        200 * sum(var.rescurtailment_2stage, 'all') .* parameter.res_curtailment
        1000 * sum(var.loadshedding_2stage, 'all') .* parameter.load_shedding
    ];
end