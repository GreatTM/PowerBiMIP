function model_final = transform_pessimistic_to_optimistic(model)
%TRANSFORM_PESSIMISTIC_TO_OPTIMISTIC
% Convert a pessimistic model with coupling constraints into an equivalent optimistic model with coupling constraints.

% --- 1. Accurately Identify Coupling Constraints ---
    [~, coupled_info] = has_coupled_constraints(model);
    m_ineq_c = coupled_info.num_ineq; 
    m_eq_c = coupled_info.num_eq;
    num_constraints = m_ineq_c + m_eq_c;

    if m_ineq_c == 0 && m_eq_c == 0
        fprintf('Warning: No coupled constraints found to transform.\n');
        return;
    end

    if ops.verbose >= 1
        fprintf('Identified %d coupled inequalities and %d coupled equalities to transform.\n', m_ineq_c, m_eq_c);
    end
    idx_ineq_c = coupled_info.ineq_idx; idx_ineq_nc = ~idx_ineq_c;
    idx_eq_c = coupled_info.eq_idx;   idx_eq_nc = ~idx_eq_c;
    
    % Extract upper-level non-coupling constraints x \in \mathcal{X}
    if ~isempty(model.A_u); model_p.A_u = model.A_u(idx_ineq_nc,:); else; model_p.A_u = []; end
    if ~isempty(model.B_u); model_p.B_u = model.B_u(idx_ineq_nc,:); else; model_p.B_u = []; end
    if ~isempty(model.C_u); model_p.C_u = model.C_u(idx_ineq_nc,:); else; model_p.C_u = []; end
    if ~isempty(model.D_u); model_p.D_u = model.D_u(idx_ineq_nc,:); else; model_p.D_u = []; end
    if ~isempty(model.b_u); model_p.b_u = model.b_u(idx_ineq_nc);   else; model_p.b_u = []; end
    if ~isempty(model.E_u); model_p.E_u = model.E_u(idx_eq_nc,:); else; model_p.E_u = []; end
    if ~isempty(model.F_u); model_p.F_u = model.F_u(idx_eq_nc,:); else; model_p.F_u = []; end
    if ~isempty(model.G_u); model_p.G_u = model.G_u(idx_eq_nc,:); else; model_p.G_u = []; end
    if ~isempty(model.H_u); model_p.H_u = model.H_u(idx_eq_nc,:); else; model_p.H_u = []; end
    if ~isempty(model.f_u); model_p.f_u = model.f_u(idx_eq_nc);   else; model_p.f_u = []; end
    % Extract upper-level coupling constraints Ax + By + Cz <= b
    if ~isempty(model.A_u); A_u_c = model.A_u(idx_ineq_c,:); else; A_u_c = []; end
    if ~isempty(model.B_u); B_u_c = model.B_u(idx_ineq_c,:); else; B_u_c = []; end
    if ~isempty(model.C_u); C_u_c = model.C_u(idx_ineq_c,:); else; C_u_c = []; end
    if ~isempty(model.D_u); D_u_c = model.D_u(idx_ineq_c,:); else; D_u_c = []; end
    if ~isempty(model.b_u); b_u_c = model.b_u(idx_ineq_c);   else; b_u_c = []; end
    if ~isempty(model.E_u); E_u_c = model.E_u(idx_eq_c,:); else; E_u_c = []; end
    if ~isempty(model.F_u); F_u_c = model.F_u(idx_eq_c,:); else; F_u_c = []; end
    if ~isempty(model.G_u); G_u_c = model.G_u(idx_eq_c,:); else; G_u_c = []; end
    if ~isempty(model.H_u); H_u_c = model.H_u(idx_eq_c,:); else; H_u_c = []; end
    if ~isempty(model.f_u); f_u_c = model.f_u(idx_eq_c);   else; f_u_c = []; end

    % --- 2. Create new variables (YALMIP) ---
    % Auxiliary variable eta
    eta = sdpvar(1, 1, 'full');
    
    % Copy m+2 sets of lower-level variables
        fields_to_copy_x_l = {'c3_vars', 'C_l_vars', 'C_u_vars',...
                          'G_l_vars', 'G_u_vars', 'c5_vars'};
        for field = fields_to_copy_x_l
            x_l_orig_subsets_struct.(field{1}) = model.(field{1});
        end
        fields_to_copy_z_l = {'c4_vars', 'D_l_vars', 'D_u_vars', ...
                          'H_l_vars', 'H_u_vars', 'c6_vars'};
        for field = fields_to_copy_z_l
            z_l_orig_subsets_struct.(field{1}) = model.(field{1});
        end
    
        % Preallocate cell arrays for better performance
        var_x_l_reps = cell(1, num_constraints);
        model_p_x_l_reps = cell(1, num_constraints);
        var_z_l_reps = cell(1, num_constraints);
        model_p_z_l_reps = cell(1, num_constraints);
        % 这里有点bug，待修复
        % 使用循环代替重复的代码块
        for i = 1:num_constraints
            [var_x_l_reps{i}, model_p_x_l_reps{i}] = ...
                replicateVariables(model.var_x_l, x_l_orig_subsets_struct, true, false, false);
            [var_z_l_reps{i}, model_p_z_l_reps{i}] = ...
                replicateVariables(model.var_z_l, z_l_orig_subsets_struct, false, false, true);
        end
        [var_x_l_bar, model_p_x_l_bar] = ...
            replicateVariables(model.var_x_l, x_l_orig_subsets_struct, true, false, false);
        [var_z_l_bar, model_p_z_l_bar] = ...
            replicateVariables(model.var_z_l, z_l_orig_subsets_struct, false, false, true);
        
        % 合并与拆分
        % 1. 合并 (Merge)
        % 创建一个临时的、包含所有源结构体的元胞列表
        all_struct_sources = {model_p_x_l_reps, model_p_z_l_reps};
        model_p_temp = struct();
        
        for k = 1:length(all_struct_sources)
            struct_cell_array = all_struct_sources{k};
            
            % 检查元胞数组是否为空
            if isempty(struct_cell_array) || isempty(struct_cell_array{1})
                continue;
            end
            
            % 获取第一个结构体的所有字段名
            field_names = fieldnames(struct_cell_array{1});
            
            % 遍历每一个字段
            for i = 1:length(field_names)
                fn = field_names{i};
                
                % @(s) s.(fn) 是一个匿名函数，用于提取每个结构体 s 的字段 fn 的值
                concatenated_field = cellfun(@(s) s.(fn), struct_cell_array, 'UniformOutput', false);
                
                % 将串联后的矩阵存入 model_p_temp
                model_p_temp.(fn) = horzcat(concatenated_field{:});
            end
        end
        
        % 2. 拆分 (Split)
        model_p_i_ineq = struct();
        model_p_i_eq = struct();
        
        % 获取 model_p_temp 的所有字段名
        all_fields_in_temp = fieldnames(model_p_temp);
        
        for i = 1:length(all_fields_in_temp)
            fn = all_fields_in_temp{i};
            
            % 获取合并后的矩阵
            merged_matrix = model_p_temp.(fn);
            
            % 按列进行切片
            % 前 m_ineq_c 列划分给 model_p_i_ineq
            model_p_i_ineq.(fn) = merged_matrix(:, 1:m_ineq_c);
            
            % 后 m_eq_c 列划分给 model_p_i_eq
            model_p_i_eq.(fn) = merged_matrix(:, m_ineq_c+1:end);
        end
        
%         % 清理临时变量 (可选)
%         clear model_p_temp all_struct_sources struct_cell_array field_names all_fields_in_temp;
%         clear fn i k concatenated_field merged_matrix;
    % --- 3. 构建变量向量 ---
        relax1 = sdpvar(m_ineq_c,1,'full');
        relax2 = sdpvar(m_eq_c,1,'full');

    var_x_u = [model.var_x_u; eta; var_x_l_bar];
    var_z_u = [model.var_z_u; var_z_l_bar];
    var_x_l = [model.var_x_l; vertcat(var_x_l_reps{:}); relax1; relax2];
    var_z_l = [model.var_z_l; vertcat(var_z_l_reps{:})];

    % --- 4. 构建新的上层问题 ---
    % 4.1 新的上层目标函数: min eta
    obj_upper = eta;

    % 4.2 构建新的上层约束
        cons_upper = [];
        % \eta >= f^Tx + g^Ty^0 + h^Tz^0
            cons_upper = cons_upper + ...
                (eta >= [model.c1', model.c2', model.c3', model.c4'] * ...
                [model.c1_vars; model.c2_vars; model.c3_vars; model.c4_vars]);
        
        % P\bar y + N\bar z<= R-Kx
            % lower level
            % inequality
            if isempty(model.b_l)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    ([model.A_l, model.B_l, ...
                    model.C_l, model.D_l] * ...
                    [model.A_l_vars; model.B_l_vars; ...
                    model_p_x_l_bar.C_l_vars; model_p_z_l_bar.D_l_vars] <= ...
                    model.b_l);
            end
            % equality
            if isempty(model.f_l)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    ([model.E_l, model.F_l, ...
                    model.G_l, model.H_l] * ...
                    [model.E_l_vars; model.F_l_vars; ...
                    model_p_x_l_bar.G_l_vars; model_p_z_l_bar.H_l_vars] == ...
                    model.f_l);
            end
        % x\in \mathcal X
            % 不等式
            if isempty(model_p.b_u)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    ([model_p.A_u, model_p.B_u, ...
                    model_p.C_u, model_p.D_u] * ...
                    [model.A_u_vars; model.B_u_vars; ...
                    model.C_u_vars; model.D_u_vars] <= ...
                    model_p.b_u);
            end
        
            % 等式
            if isempty(model_p.f_u)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    ([model_p.E_u, model_p.F_u, ...
                    model_p.G_u, model_p.H_u] * ...
                    [model.E_u_vars; model.F_u_vars; ...
                    model.G_u_vars; model.H_u_vars] == ...
                    model_p.f_u);
            end
        % Ax + By^0 + Cz^0 <= b
            % 不等式
            if isempty(b_u_c)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    ([A_u_c, B_u_c, ...
                    C_u_c, D_u_c] * ...
                    [model.A_u_vars; model.B_u_vars; ...
                    model.C_u_vars; model.D_u_vars] <= ...
                    b_u_c);
            end
            % 等式
            if isempty(f_u_c)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    ([E_u_c, F_u_c, ...
                    G_u_c, H_u_c] * ...
                    [model.E_u_vars; model.F_u_vars; ...
                    model.G_u_vars; model.H_u_vars] == ...
                    f_u_c);
            end

        % A_ix + B_iy^i +C_iz^i <= b_i
            % 拓展上层变量的维度
            if ~isempty(model.A_u_vars)
                model.A_u_vars = model.A_u_vars*ones(1,m_ineq_c);
            end
            if ~isempty(model.B_u_vars)
                model.B_u_vars = model.B_u_vars*ones(1,m_ineq_c);
            end
            if ~isempty(model.E_u_vars)
                model.E_u_vars = model.E_u_vars*ones(1,m_eq_c);
            end
            if ~isempty(model.F_u_vars)
                model.F_u_vars = model.F_u_vars*ones(1,m_eq_c);
            end

            % 不等式
            if isempty(b_u_c)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    (sum([A_u_c, B_u_c, ...
                    C_u_c, D_u_c] .* ...
                    [model.A_u_vars', model.B_u_vars', ...
                    model_p_i_ineq.C_u_vars', model_p_i_ineq.D_u_vars'], 2) <= ...
                    b_u_c);
            end
            % 等式
            if isempty(f_u_c)
                cons_upper = cons_upper + [];
            else
                cons_upper = cons_upper + ...
                    (sum([E_u_c, F_u_c, ...
                    G_u_c, H_u_c] .* ...
                    [model.E_u_vars', model.F_u_vars', ...
                    model_p_i_eq.G_u_vars', model_p_i_eq.H_u_vars'], 2) == ...
                    f_u_c);
            end

    % --- 5. 构建新的下层问题 ---

    % 5.1 新的下层目标函数
        obj_lower = (-[model.c3', model.c4'] * ...
                [model.c3_vars; model.c4_vars]) + ...
                (sum(-[C_u_c, D_u_c] .* ...
                [model_p_i_ineq.C_u_vars', model_p_i_ineq.D_u_vars'], "all")) + 10000 * sum(relax1,'all') + 10000 * sum(relax2,"all");
    % 5.2 新的下层约束
        cons_lower = [];
        % Py^j + Nz^j <= R - Kx
            % 不等式
            if isempty(model.b_l)
                cons_lower = cons_lower + [];
            else
                cons_lower = cons_lower + ...
                    ([model.A_l, model.B_l, ...
                    model.C_l, model.D_l] * ...
                    [model.A_l_vars; model.B_l_vars; model.C_l_vars; model.D_l_vars] <= ...
                    model.b_l);
            end
            % 等式
            if isempty(model.f_l)
                cons_lower = cons_lower + [];
            else
                cons_lower = cons_lower + ...
                    ([model.E_l, model.F_l, ...
                    model.G_l, model.H_l] * ...
                    [model.E_l_vars; model.F_l_vars; model.G_l_vars; model.H_l_vars] == ...
                    model.f_l);
            end
            
            for t = 1 : m_ineq_c
                % 不等式
                if isempty(model.b_l)
                    cons_lower = cons_lower + [];
                else
                    cons_lower = cons_lower + ...
                        ([model.A_l, model.B_l, ...
                        model.C_l, model.D_l] * ...
                        [model.A_l_vars; model.B_l_vars; model_p_i_ineq.C_l_vars(:,t); model_p_i_ineq.D_l_vars(:,t)] <= ...
                        model.b_l);
                end
            end
            
            for t = 1 : m_eq_c
                % 等式
                if isempty(model.f_l)
                    cons_lower = cons_lower + [];
                else
                    cons_lower = cons_lower + ...
                        ([model.E_l, model.F_l, ...
                        model.G_l, model.H_l] * ...
                        [model.E_l_vars; model.F_l_vars; model_p_i_eq.G_l_vars(:,t); model_p_i_eq.H_l_vars(:,t)] == ...
                        model.f_l);
                end
            end

        % w^Ty^j + v^Tz^j <= w^T\bar y + v^T\bar z
            cons_lower = cons_lower + ...
                ([model.c5', model.c6'] * ...
                 [model.c5_vars; model.c6_vars] <= ...
                 [model.c5', model.c6'] * ...
                 [model_p_x_l_bar.c5_vars; model_p_z_l_bar.c6_vars]);
            for t = 1 : m_ineq_c
                cons_lower = cons_lower + ...
                    ([model.c5', model.c6'] * ...
                     [model_p_i_ineq.c5_vars(:,t); model_p_i_ineq.c6_vars(:,t)] - relax1(t) <= ...
                     [model.c5', model.c6'] * ...
                     [model_p_x_l_bar.c5_vars; model_p_z_l_bar.c6_vars]);
            end
            for t = 1 : m_eq_c
                cons_lower = cons_lower + ...
                    ([model.c5', model.c6'] * ...
                     [model_p_i_eq.c5_vars(:,t); model_p_i_eq.c6_vars(:,t)] - relax2(t) <= ...
                     [model.c5', model.c6'] * ...
                     [model_p_x_l_bar.c5_vars; model_p_z_l_bar.c6_vars]);
            end
            cons_lower = cons_lower + ...
                (relax1 >= 0);
            cons_lower = cons_lower + ...
                (relax2 >= 0);

    model_final = extract_coefficients_and_variables(var_x_u, ...
        var_z_u, var_x_l, var_z_l, cons_upper, cons_lower, obj_upper, obj_lower);
    model_final.var = model.var;
end