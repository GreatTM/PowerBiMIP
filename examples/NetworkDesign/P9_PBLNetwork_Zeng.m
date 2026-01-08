function P9_PBLNetwork_Zeng(num_nodes, num_links, budget, num_candidates)
% RUN_VSP_ZENG_FINAL 求解 VSP 双层网络设计模型 (带 MPS/AUX 导出功能)
%
%   输入参数 (可选):
%       num_nodes      : 节点总数 (默认 22)
%       num_links      : 路段总数 (默认 77)
%       budget         : 预算 (默认 200)
%       num_candidates : 候选站点数 (默认 9)

    %% 1. 初始化与参数处理
    if nargin < 4, num_candidates = 9; end
    if nargin < 3, budget = 200; end
    if nargin < 2, num_links = 78; end
    if nargin < 1, num_nodes = 23; end

    % 修正候选数
    num_candidates = min(num_candidates, num_nodes);

    dbstop if error;
    yalmip('clear');
    clc;
    
    fprintf('=== 初始化 VSP 模型 (GRID 拓扑) ===\n');
    fprintf('  参数: N=%d, L=%d, B=%.0f, C=%d\n', num_nodes, num_links, budget, num_candidates);

    % 生成数据
    data = generate_GRID_data(num_nodes, num_links, budget, num_candidates);
    N = data.N; A = data.num_arcs; K = data.num_od;     

    %% 2. 定义变量
    % 上层
    model.var_upper.x = binvar(N, 1, 'full'); 
    model.var_upper.y = intvar(N, 1, 'full');
    model.var_upper.z = intvar(N, 1, 'full');
    % 下层
    model.var_lower.v = sdpvar(A, K, 'full'); 
    model.var_lower.w = sdpvar(N, K, 'full');

    %% 3. 约束条件
    model.cons_upper = [];
    model.cons_lower = [];

    % ---------------------------------------------------------
    % 上层约束 (Upper Level)
    % ---------------------------------------------------------

    % [约束 1] 非候选点强制为0 (修改：用 <= 0 和 >= 0 代替 == 0)
    not_candidates = ~data.is_candidate;
    if any(not_candidates)
        % 强制 x, y, z 为 0。
        % 原式: x == 0
        % 新式: x <= 0 且 x >= 0
        model.cons_upper = [model.cons_upper, ...
            model.var_upper.x(not_candidates) <= 0, model.var_upper.x(not_candidates) >= 0, ...
            model.var_upper.y(not_candidates) <= 0, model.var_upper.y(not_candidates) >= 0, ...
            model.var_upper.z(not_candidates) <= 0, model.var_upper.z(not_candidates) >= 0];
    end

    % [约束 2] 预算约束 (保持不变，原本就是不等式)
    cost_term = data.Cs .* model.var_upper.x + ...
                data.Cp .* model.var_upper.y + ...
                data.Cv .* model.var_upper.z;
    model.cons_upper = [model.cons_upper, sum(cost_term) <= data.Budget];

    % [约束 3] 容量逻辑 (保持不变，原本就是不等式)
    M_cap = data.y_ub; 
    model.cons_upper = [model.cons_upper, M_cap * model.var_upper.x >= model.var_upper.y];
    model.cons_upper = [model.cons_upper, model.var_upper.z <= model.var_upper.y];
    model.cons_upper = [model.cons_upper, model.var_upper.y <= data.y_ub];
    
    % 非负约束 (保持不变)
    model.cons_upper = [model.cons_upper, model.var_upper.y >= 0, model.var_upper.z >= 0];

    % ---------------------------------------------------------
    % 下层约束 (Lower Level)
    % ---------------------------------------------------------

    % [约束 4] 流量守恒 (修改：用 <= 和 >= 代替 ==)
    % 原式: Incidence * v == demand
    % 新式: Incidence * v <= demand 且 Incidence * v >= demand
    for k = 1:K
        demand_vec = sparse([data.OD(k,1), data.OD(k,2)], [1, 1], ...
                            [data.OD(k,3), -data.OD(k,3)], N, 1);
        
        % 计算左端项 (Flow Balance LHS)
        flow_lhs = data.NodeArcIncidence * model.var_lower.v(:, k);
        
        % 添加两个方向的不等式
        model.cons_lower = [model.cons_lower, flow_lhs <= demand_vec];
        model.cons_lower = [model.cons_lower, flow_lhs >= demand_vec];
    end
    
    % [约束 5] 公交频率 (保持不变)
    transit_indices = find(data.is_transit);
    for idx = transit_indices'
        u = data.arcs(idx, 1); 
        f_ij = data.freq(idx);
        if f_ij > 0
            model.cons_lower = [model.cons_lower, ...
                model.var_lower.v(idx, :) <= f_ij * model.var_lower.w(u, :)];
        end
    end
    
    % [约束 6] 耦合约束 (保持不变)
    vsp_indices = find(data.is_vsp);
    BigM_Flow = sum(data.OD(:,3)); 
    for idx = vsp_indices'
        u = data.arcs(idx, 1); v = data.arcs(idx, 2);
        flow_sum = sum(model.var_lower.v(idx, :));
        model.cons_lower = [model.cons_lower, flow_sum <= BigM_Flow * model.var_upper.x(u)];
        model.cons_lower = [model.cons_lower, flow_sum <= BigM_Flow * model.var_upper.x(v)];
    end
    
    % [约束 7 & 8] 借还车约束 (保持不变)
    for i = 1:N
        out_vsp = intersect(find(data.arcs(:,1) == i), vsp_indices);
        if ~isempty(out_vsp)
            model.cons_lower = [model.cons_lower, sum(sum(model.var_lower.v(out_vsp, :))) <= model.var_upper.z(i)];
        end
        in_vsp = intersect(find(data.arcs(:,2) == i), vsp_indices);
        if ~isempty(in_vsp)
            model.cons_lower = [model.cons_lower, sum(sum(model.var_lower.v(in_vsp, :))) <= 1.0 * (model.var_upper.y(i) - model.var_upper.z(i))];
        end
    end
    
    % 变量非负 (保持不变)
    model.cons_lower = [model.cons_lower, model.var_lower.v >= 0, model.var_lower.w >= 0];

    %% 4. 目标函数
    % 下层 (最小化成本)
    model.obj_lower = sum(data.arc_costs' * model.var_lower.v) + sum(sum(model.var_lower.w));
    % 上层 (最大化收益 -> 最小化负收益)
    model.obj_upper = -sum(data.arc_revenues' * model.var_lower.v);

    %% 6. 求解 (可选，如果只需导出可注释掉)
    ops = BiMIPsettings('perspective', 'pessimistic', ... % 'optimistic''pessimistic'
        'method', 'exact_KKT', ...
        'solver', 'cplex', ...
        'verbose', 3, ...
        'optimal_gap', 1e-4);

    ops.ops_MP.cplex.preprocessing.reduce = 1;
    
    fprintf('正在调用求解器...\n');
    [Solution, ~] = solve_BiMIP(model, ops);
    
    if ~isempty(Solution)
        fprintf('求解成功: Obj_Upper = %.2f\n', -value(model.obj_upper));
    else
        fprintf('未找到最优解\n');
    end

    %% 6. 结果输出
    if ~isempty(Solution)
        fprintf('\n====== 求解结果 ======\n');
        fprintf('上层目标 (最大化收益): %.2f\n', -value(model.obj_upper));
        fprintf('下层目标 (最小化成本): %.2f\n', value(model.obj_lower));
        
        built_idx = find(round(value(model.var_upper.x)));
        if isempty(built_idx)
            fprintf('警告: 未建设任何站点。\n');
        else
            fprintf('建设站点列表 (共 %d 个):\n', length(built_idx));
            for i = built_idx'
                cap = round(value(model.var_upper.y(i)));
                veh = round(value(model.var_upper.z(i)));
                is_cand = data.is_candidate(i);
                cand_str = '';
                if ~is_cand, cand_str = '(异常: 非候选点)'; end % 理论上不应发生
                fprintf('  Node %02d %s: 容量 = %d, 初始车辆 = %d\n', i, cand_str, cap, veh);
            end
        end
    else
        fprintf('\n未能找到最优解。\n');
    end

    % % %% 5. 导出 MPS 和 AUX 文件 (新增功能)
    % % % 文件名构造
    % case_name = sprintf('VSP_N%d_L%d_B%.0f_C%d', num_nodes, num_links, budget, num_candidates);
    % Yalmip2MpsAux(model, case_name)

end

% 辅助函数：生成 GRID 结构数据 (与之前相同)
function data = generate_GRID_data(N, num_links_target, budget, num_candidates)
    rng(42); 
    data.N = N; data.Budget = budget;
    cols = floor(sqrt(N)); rows = ceil(N / cols);
    sources = []; targets = [];
    for r = 1:rows
        for c = 1:cols
            u = (r-1)*cols + c; if u > N, continue; end
            if c < cols, v = u+1; if v<=N, sources=[sources, u, v]; targets=[targets, v, u]; end; end
            if r < rows, v = u+cols; if v<=N, sources=[sources, u, v]; targets=[targets, v, u]; end; end
        end
    end
    current_links = length(sources);
    if current_links < num_links_target
        for k = 1:(num_links_target-current_links)
            s = randi(N); t = randi(N); while s==t, t=randi(N); end; sources(end+1)=s; targets(end+1)=t;
        end
    elseif current_links > num_links_target
        sources = sources(1:num_links_target); targets = targets(1:num_links_target);
    end
    data.num_arcs = length(sources); data.arcs = [sources', targets'];
    I = zeros(N, data.num_arcs); for k=1:data.num_arcs, I(sources(k),k)=1; I(targets(k),k)=-1; end
    data.NodeArcIncidence = I;
    num_candidates = min(num_candidates, N); perm = randperm(N);
    data.is_candidate = false(N, 1); data.is_candidate(perm(1:num_candidates)) = true;
    types = rand(data.num_arcs, 1);
    data.is_vsp = types < 0.3; data.is_transit = (types >= 0.3) & (types < 0.7); 
    data.arc_costs = 5 + 10 * rand(data.num_arcs, 1); data.arc_costs(data.is_transit) = data.arc_costs(data.is_transit) * 0.4;
    data.arc_revenues = zeros(data.num_arcs, 1); data.arc_revenues(data.is_vsp) = 8 + 5*rand(sum(data.is_vsp), 1);
    data.freq = zeros(data.num_arcs, 1); data.freq(data.is_transit) = 0.2 + 0.3*rand(sum(data.is_transit), 1);
    data.Cs = 40 + 10*rand(N,1); data.Cp = 2 + 2*rand(N,1); data.Cv = 5 + 3*rand(N,1); data.y_ub = 15;              
    data.num_od = 5; data.OD = zeros(data.num_od, 3);
    for k = 1:data.num_od, tmp = randperm(N, 2); data.OD(k, :) = [tmp(1), tmp(2), 10 + randi(10)]; end
end