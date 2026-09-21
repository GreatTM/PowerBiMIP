function model = mpsaux2yalmip(mps_path, aux_path, add_slack)
%==========================================================================
% mpsaux2yalmip
%--------------------------------------------------------------------------
% 作用：
%   将标准 .mps（MILP Relaxation）与 .aux（下层归属信息）
%   转换为指定格式的 MATLAB/YALMIP 双层优化建模对象 model：
%
%   model.var_upper  : 上层变量列向量
%   model.var_lower  : 下层变量列向量
%   model.cons_upper : 上层约束（YALMIP constraints）
%   model.cons_lower : 下层约束（YALMIP constraints）
%   model.obj_upper  : 上层目标（YALMIP expression）
%   model.obj_lower  : 下层目标（YALMIP expression）
%
% 输入：
%   mps_path   : .mps 文件路径
%   aux_path   : .aux 文件路径（新/旧格式都支持）
%   add_slack  : 是否对所有下层约束加松弛变量并在下层目标惩罚（默认 false）
%
% 说明：
%   - 松弛变量只加在"下层约束"，并加入 model.var_lower
%   - 惩罚项 rho*sum(slack) 加到 model.obj_lower（下层目标）
%==========================================================================

    if nargin < 3
        add_slack = false;
    end
    rho = 1e4;

    % 1) 解析 MPS / AUX
    mps = parse_mps_file(mps_path);
    aux = parse_aux_file(aux_path, mps);  % 支持新/旧 aux

    % 2) 构建全量 YALMIP 变量（与 mps.var_names 对齐）
    [allVars, ~] = build_yalmip_vars(mps.var_names, mps.is_integer, mps.is_binary);

    % 3) 上下层变量拆分
    isLowerVar = ismember(mps.var_names, aux.lower_var_names);
    model.var_lower = allVars(isLowerVar);
    model.var_upper = allVars(~isLowerVar);

    % 4) 目标函数
    model.obj_upper = mps.c_obj(:)' * allVars;

    model.obj_lower = 0;
    for k = 1:numel(aux.lower_var_names)
        vname = aux.lower_var_names{k};
        coeff = aux.lower_obj_coeff(k);
        idx = find(strcmp(mps.var_names, vname), 1);
        if isempty(idx)
            error('AUX 中下层变量 "%s" 未在 MPS 变量列表中找到。', vname);
        end
        model.obj_lower = model.obj_lower + coeff * allVars(idx);
    end

    % 5) 约束拆分 + （可选）下层约束加松弛
    model.cons_upper = [];
    model.cons_lower = [];

    isLowerRow = ismember(mps.constr_names, aux.lower_constr_names);

    slack_list = []; % 收集所有下层松弛变量（列向量）

    for i = 1:numel(mps.constr_names)
        rowName = mps.constr_names{i};
        sense   = mps.constr_sense{i}; % '<=' , '>=' , '=='
        arow    = mps.A(i,:);
        rhs     = mps.b(i);

        lhsExpr = arow * allVars;

        if isLowerRow(i) && add_slack
            % 对下层约束加松弛变量（属于下层）
            switch sense
                case '<='
                    s = sdpvar(1,1);
                    slack_list = [slack_list; s]; %#ok<AGROW>
                    ci = [lhsExpr <= rhs + s, s >= 0];

                case '>='
                    s = sdpvar(1,1);
                    slack_list = [slack_list; s]; %#ok<AGROW>
                    ci = [lhsExpr >= rhs - s, s >= 0];

                case '=='
                    s_pos = sdpvar(1,1);
                    s_neg = sdpvar(1,1);
                    slack_list = [slack_list; s_pos; s_neg]; %#ok<AGROW>
                    ci = [lhsExpr == rhs + s_pos - s_neg, s_pos >= 0, s_neg >= 0];

                otherwise
                    error('未知约束 sense: %s (row=%s)', sense, rowName);
            end

            model.cons_lower = [model.cons_lower, ci];

        else
            % 不加松弛：原始约束
            switch sense
                case '<='
                    ci = (lhsExpr <= rhs);
                case '>='
                    ci = (lhsExpr >= rhs);
                case '=='
                    ci = (lhsExpr == rhs);
                otherwise
                    error('未知约束 sense: %s (row=%s)', sense, rowName);
            end

            if isLowerRow(i)
                model.cons_lower = [model.cons_lower, ci];
            else
                model.cons_upper = [model.cons_upper, ci];
            end
        end
    end

    % 松弛变量加入下层变量 & 下层目标惩罚
    if add_slack && ~isempty(slack_list)
        slack_list = slack_list(:);
        model.slack_lower = slack_list; % 便于调试
        model.var_lower = [model.var_lower; slack_list];
        model.obj_lower = model.obj_lower + rho * sum(slack_list);
    else
        model.slack_lower = [];
    end

    % 6) bounds -> 约束，并按变量归属上下层
    for j = 1:numel(mps.var_names)
        x  = allVars(j);
        lb = mps.lb(j);
        ub = mps.ub(j);

        cons_bnd = [];
        if ~isinf(lb), cons_bnd = [cons_bnd, (x >= lb)]; end
        if ~isinf(ub), cons_bnd = [cons_bnd, (x <= ub)]; end
        if isempty(cons_bnd), continue; end

        if isLowerVar(j)
            model.cons_lower = [model.cons_lower, cons_bnd];
        else
            model.cons_upper = [model.cons_upper, cons_bnd];
        end
    end
end

%==========================================================================
% 子函数：解析 AUX（新/旧格式兼容）
%==========================================================================
function aux = parse_aux_file(aux_path, mps)
    lines = read_text_lines(aux_path);

    % 判断新格式：只要出现 @ 开头关键字，就按新格式（保持原逻辑）
    isNewStyle = false;
    for i = 1:numel(lines)
        s = strtrim(lines{i});
        if startsWith(s, '@')
            isNewStyle = true;
            break;
        end
    end

    if isNewStyle
        %------------------------------
        % 新格式解析（尽量不动你原逻辑）
        %------------------------------
        upperLines = lines;
        for i = 1:numel(upperLines)
            upperLines{i} = strtrim(upperLines{i});
        end

        aux.lower_var_names    = {};
        aux.lower_obj_coeff    = [];
        aux.lower_constr_names = {};

        mode = ""; % "VARS" or "CONSTR"
        i = 1;

        while i <= numel(upperLines)
            s = upperLines{i};
            if isempty(s) || startsWith(s, '*')
                i = i + 1; continue;
            end

            if startsWith(s, '@', 'IgnoreCase', true)
                key = upper(s);

                if any(strcmp(key, {'@VARSBEGIN'}))
                    mode = "VARS"; i = i + 1; continue;
                elseif any(strcmp(key, {'@VARSEND'}))
                    mode = ""; i = i + 1; continue;
                elseif any(strcmp(key, {'@CONSTRBEGIN','@CONSTRSBEGIN'}))
                    mode = "CONSTR"; i = i + 1; continue;
                elseif any(strcmp(key, {'@CONSTREND','@CONSTRSEND'}))
                    mode = ""; i = i + 1; continue;
                else
                    i = i + 1; continue;
                end
            end

            if mode == "VARS"
                [vname, coeff] = parse_name_coeff(s);
                aux.lower_var_names{end+1,1} = vname; %#ok<AGROW>
                aux.lower_obj_coeff(end+1,1) = coeff; %#ok<AGROW>
            elseif mode == "CONSTR"
                aux.lower_constr_names{end+1,1} = strtrim(s); %#ok<AGROW>
            end

            i = i + 1;
        end

        if numel(aux.lower_obj_coeff) ~= numel(aux.lower_var_names)
            error('AUX 新格式解析异常：lower_var_names 与 lower_obj_coeff 长度不一致。');
        end

    else
        %------------------------------
        % 旧格式解析（本次关键修复）
        %------------------------------
        aux = parse_aux_file_legacy(lines, mps);
    end
end

function aux = parse_aux_file_legacy(lines, mps)
%--------------------------------------------------------------------------
% 【修复点说明（对照你给的 loadMibSInstance）】
%   旧格式 aux 关键字段含义应为：
%     LC <idx> : 下层变量索引（0-based）
%     LR <idx> : 下层约束索引（0-based）
%     LO <val> : 下层目标系数序列（按出现顺序与 LC 一一对应）
%     N/M/OS   : 元信息（可选）
%
% 【我上一版错的地方】：
%   - 把 LO 当成"上层变量索引"，导致 lower_obj_coeff 构造错误。
%   - 还默认用 mps.c_obj(lc) 当下层系数，这与很多旧格式实例不一致。
%
% 【现在的做法】：
%   - LC_idx 收集下层变量索引（转 1-based）
%   - LR_idx 收集下层约束索引（转 1-based）
%   - LO_val 收集下层目标系数（按顺序）
%   - lower_obj_coeff：对每个 LC_idx(k)，系数取 LO_val(k)（不足则补 0）
%--------------------------------------------------------------------------

    LC_idx = []; % 1-based
    LR_idx = []; % 1-based
    LO_val = []; % 系数序列
    aux = struct();
    aux.lower_var_names = {};
    aux.lower_obj_coeff = [];
    aux.lower_constr_names = {};

    for i = 1:numel(lines)
        ln = strtrim(lines{i});
        if isempty(ln) || startsWith(ln, '*')
            continue;
        end

        parts = split_ws(ln);
        key = upper(parts{1});

        % 注意：旧格式行可能只有两个 token，如 "LC 0" 或 "LO 4"
        if numel(parts) < 2
            continue;
        end

        % 允许 parts{2:end}（但一般只有一个数）
        val = str2double(parts{2});
        if isnan(val)
            continue;
        end

        switch key
            case 'LC'
                LC_idx = [LC_idx; val + 1]; %#ok<AGROW> % 0->1
            case 'LR'
                LR_idx = [LR_idx; val + 1]; %#ok<AGROW>
            case 'LO'
                LO_val = [LO_val; val]; %#ok<AGROW>
            case 'N'
                aux.N = val;
            case 'M'
                aux.M = val;
            case 'OS'
                aux.OS = val;
        end
    end

    if isempty(LC_idx)
        error('旧格式 aux 解析失败：未找到任何 LC 行（下层变量索引）。');
    end

    % 越界检查（LC）
    if any(LC_idx < 1) || any(LC_idx > numel(mps.var_names))
        error('旧格式 aux：LC 索引越界。请确认 aux 是否为 0-based，或文件是否损坏。');
    end

    % 下层变量名
    aux.lower_var_names = mps.var_names(LC_idx);

    % 下层目标系数：按 LC 出现顺序匹配 LO（效仿你给的代码）
    coeff = zeros(numel(LC_idx), 1);
    cnt = min(numel(LC_idx), numel(LO_val));
    if cnt > 0
        coeff(1:cnt) = LO_val(1:cnt);
    end
    % 若 LO 数量不足：剩余下层变量系数默认为 0（与参考实现一致）
    aux.lower_obj_coeff = coeff;

    % 下层约束名（LR 指向的是"约束行"的顺序：与你 mps.constr_names 一致）
    if isempty(LR_idx)
        aux.lower_constr_names = {};
    else
        if any(LR_idx < 1) || any(LR_idx > numel(mps.constr_names))
            % 旧格式有时 LR 可能包含越界索引，参考实现里也做了 valid_mask
            valid_mask = (LR_idx >= 1) & (LR_idx <= numel(mps.constr_names));
            LR_idx = LR_idx(valid_mask);
        end
        aux.lower_constr_names = mps.constr_names(LR_idx);
    end
end

function [name, coeff] = parse_name_coeff(line)
    line = strtrim(line);
    expr = '([+-]?\d+(\.\d*)?|\.\d+)([eEdD][+-]?\d+)?\s*$';
    m = regexp(line, expr, 'match');
    if isempty(m)
        error('AUX 变量行无法解析系数："%s"', line);
    end
    numStr = m{1};
    coeff = str2double(strrep(lower(numStr), 'd', 'e'));
    namePart = regexprep(line, expr, '');
    namePart = strtrim(namePart);
    if isempty(namePart)
        error('AUX 变量行无法解析变量名："%s"', line);
    end
    name = namePart;
end

%==========================================================================
% 子函数：解析 MPS（你现有"修复版 section 识别 + BOUNDS 扩展 LI/UI/SC/SI"逻辑）
%==========================================================================
function mps = parse_mps_file(mps_path)
    lines = read_text_lines(mps_path);

    section = "";
    rowNames = {};
    rowTypes = {};
    objRowName = '';

    rowIndex = containers.Map();
    varIndex = containers.Map();

    varNames = {};
    isInt = [];
    isBin = [];

    I = []; J = []; V = [];

    rhsMap = containers.Map();

    lb = []; ub = [];

    inIntBlock = false;

    for k = 1:numel(lines)
        s = strtrim(lines{k});
        if isempty(s) || startsWith(s, '*')
            continue;
        end

        % section 识别（修复版）
        sU = upper(strtrim(s));
        if startsWith(sU, 'NAME', 'IgnoreCase', true)
            section = 'NAME';
            continue;
        end
        if any(strcmp(sU, {'ROWS','COLUMNS','RHS','BOUNDS','RANGES','ENDATA'}))
            section = sU;
            if strcmp(section, 'RANGES')
                warning('检测到 RANGES 段：当前代码未处理该段，将忽略。');
            end
            continue;
        end

        switch section
            case 'ROWS'
                toks = split_ws(s);
                if numel(toks) < 2, continue; end
                rtype = upper(toks{1});
                rname = toks{2};

                rowNames{end+1,1} = rname; %#ok<AGROW>
                rowTypes{end+1,1} = rtype; %#ok<AGROW>
                rowIndex(rname) = numel(rowNames);

                if strcmp(rtype, 'N') && isempty(objRowName)
                    objRowName = rname;
                end

            case 'COLUMNS'
                if contains(s, 'MARKER', 'IgnoreCase', true) && ...
                   (contains(s, 'INTORG', 'IgnoreCase', true) || contains(s, 'INTEND', 'IgnoreCase', true))
                    if contains(s, 'INTORG', 'IgnoreCase', true), inIntBlock = true; end
                    if contains(s, 'INTEND', 'IgnoreCase', true), inIntBlock = false; end
                    continue;
                end

                toks = split_ws(s);
                if numel(toks) < 3, continue; end

                vname = toks{1};
                if ~isKey(varIndex, vname)
                    varNames{end+1,1} = vname; %#ok<AGROW>
                    varIndex(vname) = numel(varNames);

                    isInt(end+1,1) = inIntBlock; %#ok<AGROW>
                    isBin(end+1,1) = false;      %#ok<AGROW>
                    lb(end+1,1) = 0;             %#ok<AGROW>
                    ub(end+1,1) = inf;           %#ok<AGROW>
                else
                    if inIntBlock, isInt(varIndex(vname)) = true; end
                end

                j = varIndex(vname);

                pairs = toks(2:end);
                if mod(numel(pairs),2) ~= 0
                    pairs = pairs(1:end-1);
                end

                for p = 1:2:numel(pairs)
                    rname = pairs{p};
                    val   = str2double_mps(pairs{p+1});
                    if ~isKey(rowIndex, rname)
                        error('COLUMNS 中出现未知 ROW "%s"（变量=%s）。', rname, vname);
                    end
                    irow = rowIndex(rname);

                    I(end+1,1) = irow; %#ok<AGROW>
                    J(end+1,1) = j;    %#ok<AGROW>
                    V(end+1,1) = val;  %#ok<AGROW>
                end

            case 'RHS'
                toks = split_ws(s);
                if numel(toks) < 3, continue; end
                pairs = toks(2:end);
                if mod(numel(pairs),2) ~= 0
                    pairs = pairs(1:end-1);
                end
                for p = 1:2:numel(pairs)
                    rname = pairs{p};
                    val   = str2double_mps(pairs{p+1});
                    rhsMap(rname) = val;
                end

            case 'BOUNDS'
                toks = split_ws(s);
                if numel(toks) < 3, continue; end

                btype = upper(toks{1});
                vname = toks{3};

                if ~isKey(varIndex, vname)
                    varNames{end+1,1} = vname; %#ok<AGROW>
                    varIndex(vname) = numel(varNames);
                    isInt(end+1,1) = false; %#ok<AGROW>
                    isBin(end+1,1) = false; %#ok<AGROW>
                    lb(end+1,1) = 0; %#ok<AGROW>
                    ub(end+1,1) = inf; %#ok<AGROW>
                end
                j = varIndex(vname);

                hasVal = (numel(toks) >= 4);
                if hasVal
                    val = str2double_mps(toks{4});
                else
                    val = NaN;
                end

                if ~hasVal && any(strcmp(btype, {'LO','UP','FX','LI','UI','SC','SI'}))
                    error('BOUNDS 类型 "%s" 需要 value，但该行缺少 value。变量=%s', btype, vname);
                end

                switch btype
                    case 'LO'
                        lb(j) = val;
                    case 'UP'
                        ub(j) = val;
                    case 'FX'
                        lb(j) = val; ub(j) = val;
                    case 'FR'
                        lb(j) = -inf; ub(j) = inf;
                    case 'MI'
                        lb(j) = -inf;
                    case 'PL'
                        ub(j) = inf;
                    case 'BV'
                        lb(j) = 0; ub(j) = 1;
                        isBin(j) = true;
                        isInt(j) = true;

                    case 'LI'  % integer lower bound
                        lb(j) = val;
                        isInt(j) = true;
                    case 'UI'  % integer upper bound
                        ub(j) = val;
                        isInt(j) = true;

                    case 'SC'
                        warning('BOUNDS 类型 "SC"(semi-continuous) 暂不支持析取语义，将近似为普通连续 bounds。变量=%s', vname);
                        lb(j) = val;

                    case 'SI'
                        warning('BOUNDS 类型 "SI"(semi-integer) 暂不支持析取语义，将近似为普通整数 bounds。变量=%s', vname);
                        lb(j) = val;
                        isInt(j) = true;

                    otherwise
                        warning('未处理的 BOUNDS 类型 "%s"（变量=%s），将忽略该行。', btype, vname);
                end
        end
    end

    if isempty(objRowName)
        error('MPS 中未找到 objective row（ROWS 段需要至少一个 N 行）。');
    end

    Aall = sparse(I, J, V, numel(rowNames), numel(varNames));

    objRowIdx = rowIndex(objRowName);
    c_obj = full(Aall(objRowIdx,:));

    constrNames = {};
    constrSense = {};
    Arows = [];
    brows = [];

    for i = 1:numel(rowNames)
        if i == objRowIdx, continue; end

        rtype = rowTypes{i};
        rname = rowNames{i};

        if strcmp(rtype, 'L'), sense = '<=';
        elseif strcmp(rtype, 'G'), sense = '>=';
        elseif strcmp(rtype, 'E'), sense = '==';
        else, continue; end

        constrNames{end+1,1} = rname; %#ok<AGROW>
        constrSense{end+1,1} = sense; %#ok<AGROW>

        Arows(end+1,:) = Aall(i,:); %#ok<AGROW>
        if isKey(rhsMap, rname), brows(end+1,1) = rhsMap(rname); %#ok<AGROW>
        else, brows(end+1,1) = 0; %#ok<AGROW>
        end
    end

    mps.var_names = varNames;
    mps.is_integer = logical(isInt);
    mps.is_binary  = logical(isBin);
    mps.lb = lb(:);
    mps.ub = ub(:);

    mps.obj_row_name = objRowName;
    mps.c_obj = c_obj(:);

    mps.constr_names = constrNames;
    mps.constr_sense = constrSense;
    mps.A = sparse(Arows);
    mps.b = brows(:);
end

%==========================================================================
% 构建 YALMIP 变量
%==========================================================================
function [allVars, varType] = build_yalmip_vars(varNames, isInt, isBin)
    n = numel(varNames);
    varCells = cell(n,1);
    varType  = strings(n,1);

    for j = 1:n
        if isBin(j)
            varCells{j} = binvar(1,1);
            varType(j) = "binvar";
        elseif isInt(j)
            varCells{j} = intvar(1,1);
            varType(j) = "intvar";
        else
            varCells{j} = sdpvar(1,1);
            varType(j) = "sdpvar";
        end
    end

    allVars = vertcat(varCells{:});
end

%==========================================================================
% 工具函数
%==========================================================================
function lines = read_text_lines(path)
    fid = fopen(path, 'r');
    if fid < 0
        error('无法打开文件：%s', path);
    end
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>
    lines = {};
    while true
        tline = fgetl(fid);
        if ~ischar(tline), break; end
        lines{end+1,1} = tline; %#ok<AGROW>
    end
end

function toks = split_ws(s)
    toks = regexp(strtrim(s), '\s+', 'split');
    toks = toks(~cellfun('isempty', toks));
end

function v = str2double_mps(s)
    s = strtrim(s);
    s = regexprep(s, '[dD]', 'e');
    v = str2double(s);
    if isnan(v)
        error('无法解析数值："%s"', s);
    end
end
