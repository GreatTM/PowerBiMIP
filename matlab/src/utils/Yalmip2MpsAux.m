function Yalmip2MpsAux(bimip_model, case_name)
% 输入：Bimip_model结构体
%       bimip_model  - A struct with STRICTLY the following fields:
%           .var_upper   : Upper-level variables (sdpvar, struct, or cell)
%           .var_lower   : Lower-level variables (sdpvar, struct, or cell)
%           .cons_upper  : Upper-level constraints
%           .cons_lower  : Lower-level constraints
%           .obj_upper   : Upper-level objective
%           .obj_lower   : Lower-level objective
%       case_name
% 输出：在相同目录下输出mps和aux文件

    %% 先生成mps文件
    % The .mps file describes the MILP obtained by omitting the requirement of lower-level optimality.
    % In other words, it is the relaxation comprised of all upper- and lower-level variables, 
    % all upper- and lower-level constraints, and the upper-level objective function. 
    % This is the relaxation that is sometimes called the "high-point relaxation" in the literature
    
    ops = sdpsettings('verbose', 0, 'solver', 'gurobi', 'gurobi.ResultFile', sprintf('%s.mps', case_name));
    bimip_model.solution = optimize(bimip_model.cons_lower + bimip_model.cons_upper, bimip_model.obj_upper, ops);
    % 读取整个文件内容
    file_content = fileread(sprintf('%s.mps', case_name));
    
    % 使用正则替换第一行 (确保只替换开头的 NAME 行)
    % (?m)^ 匹配行首，\s+ 匹配空格
    new_content = regexprep(file_content, '^NAME\s+\S+', ['NAME ', case_name], 'once', 'lineanchors');
    
    % 重新写入文件
    fid = fopen(sprintf('%s.mps', case_name), 'w');
    if fid == -1
        error('无法打开 MPS 文件进行修改: %s', mps_filename);
    end
    fprintf(fid, '%s', new_content);
    fclose(fid);

    %% 再生成aux文件
    aux_filename = sprintf('%s.aux', case_name);
    fid_aux = fopen(aux_filename, 'w');
    if fid_aux == -1
        error('无法创建 AUX 文件: %s', aux_filename);
    end

    % --- 1. 准备数据：变量排序与映射 ---
    % 获取模型中涉及的所有变量并排序 (这对应 MPS 中的 C0, C1, C2...)
    all_vars = unique([getvariables(bimip_model.cons_lower), getvariables(bimip_model.cons_upper), ...
                       getvariables(bimip_model.obj_upper), getvariables(bimip_model.obj_lower)]);
    all_vars = sort(all_vars); 
    
    % 获取下层变量的内部 ID 用于比对
    lower_vars_idx = unique(get_vars_recursive(bimip_model.var_lower));

    % --- 2. 准备数据：下层目标函数系数 ---
    % 提取下层目标的线性系数 (假设下层目标是线性的)
    % getbase 返回的向量第一个元素是常数项，后面对应 getvariables 里的变量
    L_obj_base = getbase(bimip_model.obj_lower);
    L_obj_vars = getvariables(bimip_model.obj_lower);
    
    % 建立一个简单的映射: 变量ID -> 系数
    % 使用 sparse 数组或 map 都可以，这里用 map 直观一点
    coeff_map = containers.Map('KeyType','double','ValueType','double');
    for k = 1:length(L_obj_vars)
        coeff_map(L_obj_vars(k)) = L_obj_base(k+1); % 跳过常数项
    end
    
    % --- 3. 准备数据：计算下层约束行数 ---
    exported_L = export(bimip_model.cons_lower);
    num_lower_rows = size(exported_L.A, 1);

    % 统计下层变量个数 (出现在 all_vars 中的才算，避免定义了没用到的变量干扰)
    num_lower_vars_in_model = sum(ismember(all_vars, lower_vars_idx));

    % ================== 开始写入 AUX 文件 ==================
    
    % @NUMVARS
    fprintf(fid_aux, '@NUMVARS\n');
    fprintf(fid_aux, '%d\n', num_lower_vars_in_model);
    
    % @NUMCONSTRS
    fprintf(fid_aux, '@NUMCONSTRS\n');
    fprintf(fid_aux, '%d\n', num_lower_rows);
    
    % @VARSBEGIN
    fprintf(fid_aux, '@VARSBEGIN\n');
    for i = 1:length(all_vars)
        v_idx = all_vars(i);
        
        % 如果当前变量属于下层变量
        if ismember(v_idx, lower_vars_idx)
            % 变量名: C + (索引-1)
            var_name = sprintf('C%d', i-1);
            
            % 获取系数，默认为 0
            if isKey(coeff_map, v_idx)
                val = coeff_map(v_idx);
            else
                val = 0;
            end
            
            % 格式化系数：整数加点，非整数保留精度
            if mod(val, 1) == 0
                val_str = sprintf('%d.', val);
            else
                val_str = sprintf('%.12g', val);
            end
            
            fprintf(fid_aux, '%s %s\n', var_name, val_str);
        end
    end
    fprintf(fid_aux, '@VARSEND\n');
    
    % @CONSTRSBEGIN
    % 因为 cons_lower 写在最前，所以从 R0 开始的前 num_lower_rows 行都是下层约束
    fprintf(fid_aux, '@CONSTRSBEGIN\n');
    for j = 0 : (num_lower_rows - 1)
        fprintf(fid_aux, 'R%d\n', j);
    end
    fprintf(fid_aux, '@CONSTRSEND\n');
    
    % @NAME
    fprintf(fid_aux, '@NAME\n');
    fprintf(fid_aux, '%s\n', case_name);
    
    % @MPS
    fprintf(fid_aux, '@MPS\n');
    fprintf(fid_aux, '%s.mps\n', case_name);
    
    fclose(fid_aux);
    fprintf('AUX 文件生成完毕: %s\n', aux_filename);
end

%% 辅助函数：递归提取变量索引 (支持 struct, cell, sdpvar)
function indices = get_vars_recursive(obj)
    indices = [];
    if isa(obj, 'sdpvar')
        % 如果是 sdpvar，直接获取索引
        indices = getvariables(obj);
    elseif isstruct(obj)
        % 如果是结构体，遍历所有字段
        fields = fieldnames(obj);
        for i = 1:length(fields)
            indices = [indices, get_vars_recursive(obj.(fields{i}))]; %#ok<AGROW>
        end
    elseif iscell(obj)
        % 如果是 cell 数组，遍历所有元素
        for i = 1:length(obj)
            indices = [indices, get_vars_recursive(obj{i})]; %#ok<AGROW>
        end
    end
    % 如果是 double 或其他类型，返回空即可
end

% -------------------------------------------------------------------------
% Helper Function: Recursively extract sdpvars from structs/cells
% -------------------------------------------------------------------------
function flat_vars = extract_flat_sdpvar(input_obj)
    flat_vars = [];
    
    if isa(input_obj, 'sdpvar')
        % Base case: It's an sdpvar (scalar, vector, or matrix)
        flat_vars = input_obj(:); % Force column vector
        
    elseif isstruct(input_obj)
        % Recursive case: It's a struct
        fields = fieldnames(input_obj);
        for i = 1:length(fields)
            field_content = input_obj.(fields{i});
            flat_vars = [flat_vars; extract_flat_sdpvar(field_content)];
        end
        
    elseif iscell(input_obj)
        % Recursive case: It's a cell array
        for i = 1:numel(input_obj)
            flat_vars = [flat_vars; extract_flat_sdpvar(input_obj{i})];
        end
        
    elseif isnumeric(input_obj)
        % Ignore numeric constants (empty variables) logic, 
        % or treat as error depending on strictness. 
        % Here we largely ignore or assume user didn't put constants in var list.
    else
        % Unknown type (e.g. strings inside var struct), ignore or warn
    end
end