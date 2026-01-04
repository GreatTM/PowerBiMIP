% 函数功能：工具函数，用于纯电力系统机组组合模型第一阶段建模
% 输入：参数、系统数据、新能源负荷数据、0-1变量（var_u_input, var_v_input, var_w_input）、新能源预测值
% 输出：yalmip变量、约束、目标函数
function [var, cons, obj] = EPS_UC_model_stage1(parameter, system_data, data, pres_forecast)
    %% 基础校验
    assert(mod(data.Ntime,24)==0, '时间维度必须是24的整数倍');
    num_blocks = data.Ntime / 24;
    history_length = 10; % 历史状态初始化长度
    %% 定义外部输入变量
    var.u = binvar(system_data.Ngen,data.Ntime,'full');
    var.v = binvar(system_data.Ngen,data.Ntime,'full');
    var.w = binvar(system_data.Ngen,data.Ntime,'full');
         
    %% 其他变量定义
    var.pgen = sdpvar(system_data.Ngen,data.Ntime,'full');
    var.ru = sdpvar(system_data.Ngen,data.Ntime,'full');
    var.rd = sdpvar(system_data.Ngen,data.Ntime,'full');
    % 新能源机组
    % 定义新能源机组弃风量（Nrenewablegen*Ntime）
    var.rescurtailment = sdpvar(system_data.Nrenewablegen,data.Ntime,'full');
    % 切负荷
    var.loadshedding = sdpvar(system_data.Nload,data.Ntime,'full');

    %% 约束定义
    cons = [];
    % 变量上下限约束
    cons = cons + (var.pgen >= 0);
    % cons = cons + (var.ru >= 0);
    % cons = cons + (var.rd >= 0);
    % % 旋转备用上下限
    % cons = cons + ...
    %     (var.ru <= var.u .* (system_data.ramplimit.up * ones(1,data.Ntime)));
    % cons = cons + ...
    %     (var.rd <= var.u .* (system_data.ramplimit.down * ones(1,data.Ntime)));
    % 出力上下限约束
    % cons = cons + ...
    %     (var.pgen + var.ru <= var.u .* (system_data.plimit.upper * ones(1, data.Ntime)));
    % cons = cons + ...
    %     (var.pgen - var.rd >= var.u .* (system_data.plimit.lower * ones(1, data.Ntime)));
    cons = cons + ...
        (var.pgen <= var.u .* (system_data.plimit.upper * ones(1, data.Ntime)));
    cons = cons + ...
        (var.pgen >= var.u .* (system_data.plimit.lower * ones(1, data.Ntime)));
    % 新能源机组弃风上下限
    if parameter.res_curtailment
        cons = cons + ...
            (var.rescurtailment >= 0);
        cons = cons + ...
            (var.rescurtailment <= pres_forecast');
    end
    % 切负荷上下限
    if parameter.load_shedding
        cons = cons + ...
            (var.loadshedding >= 0);
        cons = cons + ...
            (var.loadshedding <= data.pload_realization_data');
    end
    
    %% 时间耦合约束（分周期处理）
    for block = 1:num_blocks
        t_start = (block-1)*24 + 1;
        t_end = block*24;
        t_range = t_start:t_end;
        
        % ====== 启停逻辑约束 ======
        % 为当前周期创建带历史状态的变量
        u_history = [zeros(system_data.Ngen, history_length), var.u(:,t_range)];
        v_history = [zeros(system_data.Ngen, history_length), var.v(:,t_range)];
        w_history = [zeros(system_data.Ngen, history_length), var.w(:,t_range)];
        
        % 启停关系式
        for t = 1:24
            cons = cons + (u_history(:, history_length + t) - u_history(:, history_length + t - 1)...
                == v_history(:, history_length + t) - w_history(:, history_length + t));
        end
        
        % % ====== 最小启停时间约束 ======
        % for i = 1:system_data.Ngen
        %     % 开机时间约束
        %     for t = 1:24
        %         start_t = max(1, t - system_data.mintime.on(i) + 1);
        %         cons = cons + (sum(v_history(i, history_length + start_t : history_length + t)) <= u_history(i, history_length + t));
        %     end
        % 
        %     % 停机时间约束
        %     for t = 1:24
        %         start_t = max(1, t - system_data.mintime.off(i) + 1);
        %         cons = cons + (sum(w_history(i, history_length + start_t : history_length + t)) <= 1 - u_history(i, history_length + t));
        %     end
        % end
        % 
        % % ====== 爬坡约束 ======
        % block_pgen = var.pgen(:, t_range);
        % delta_pgen = diff(block_pgen, 1, 2);
        % cons = cons + ...
        %     ((-system_data.ramplimit.down * ones(1, 23)) <= delta_pgen);
        % cons = cons + ...
        %     (delta_pgen <= (system_data.ramplimit.up * ones(1, 23)));
    end
    
    %% 旋转备用约束
    % % ====== 旋转备用约束(每时段备用覆盖负荷15%) ======
    % cons = cons + ...
    %     (sum(var.ru,1) >= 0.05 * sum(data.pload_realization_data,2)');
    % cons = cons + ...
    %     (sum(var.rd,1) >= 0.05 * sum(data.pload_realization_data,2)');

    %% 能量平衡与潮流
    renewable_power = pres_forecast' - var.rescurtailment.*parameter.res_curtailment;
    load_power = data.pload_realization_data' - var.loadshedding.*parameter.load_shedding;
    
    % 能量平衡
    cons = cons + ...
        (sum(var.pgen,1) + sum(renewable_power,1) == sum(load_power,1));
    
    % 直流潮流
    branch_flow = system_data.PTDF.gen * var.pgen + ...
                 system_data.PTDF.renewablegen * renewable_power - ...
                 system_data.PTDF.load * load_power;
    cons = cons + ...
        ((system_data.pbranchlimit.lower * ones(1, data.Ntime)) <= branch_flow);
    cons = cons + ...
        (branch_flow <= (system_data.pbranchlimit.upper * ones(1, data.Ntime)));

    %% 目标函数
    var.cost_terms = [
        sum((system_data.cost.c1 * ones(1,data.Ntime)) .* var.pgen, 'all')    % 燃料成本
        sum((system_data.cost.c0 * ones(1,data.Ntime)) .* var.u, 'all')       % 空载成本
        sum((system_data.cost.startup * ones(1,data.Ntime)) .* var.v, 'all')       % 启停成本
        sum((system_data.cost.shutdown * ones(1,data.Ntime)) .* var.w, 'all')
        200 * sum(var.rescurtailment, 'all') .* parameter.res_curtailment
        1000 * sum(var.loadshedding, 'all') .* parameter.load_shedding
    ];
    obj = sum(var.cost_terms);
end