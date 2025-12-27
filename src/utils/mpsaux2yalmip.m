function model = mpsaux2yalmip(mps_path, aux_path)
%==========================================================================
% mpsaux2yalmip
%--------------------------------------------------------------------------
% 作用：
%   将标准 .mps（MILP Relaxation，高点松弛/ MILP relax）与 .aux（下层归属信息）
%   转换为指定格式的 MATLAB/YALMIP 建模对象，并输出结构体 model：
%
%   model.var_upper  : 上层变量列向量（元素可为 sdpvar/intvar/binvar）
%   model.var_lower  : 下层变量列向量（元素可为 sdpvar/intvar/binvar）
%   model.cons_upper : 上层约束（YALMIP constraints 集合）
%   model.cons_lower : 下层约束（YALMIP constraints 集合）
%   model.obj_upper  : 上层目标函数（YALMIP expression）
%   model.obj_lower  : 下层目标函数（YALMIP expression）
%
% 输入：
%   mps_path : .mps 文件的完整路径（可与本代码不在同一目录）
%   aux_path : .aux 文件的完整路径（可与本代码不在同一目录）
%
% 输出：
%   model    : 结构体，字段如上
%
% 依赖：
%   需要已安装 YALMIP，并已 addpath
%
% 注意：
%   1) 仅解析 MPS 的 ROWS/COLUMNS/RHS/BOUNDS/ENDATA 核心段。
%   2) 不处理 RANGES 段（若出现会 warning）。
%   3) bounds 归属规则：
%        - 若变量属于 aux 指定的下层变量，则其 bounds 默认加入下层约束；
%        - 否则加入上层约束。
%      若你希望某个下层变量 bounds 属于上层，请在 MPS 中显式写成命名 ROW 约束
%      并且不要把该约束列入 aux 的下层约束列表。
%==========================================================================

    %---------------------------
    % 1) 解析文件
    %---------------------------
    mps = parse_mps_file(mps_path);
    aux = parse_aux_file(aux_path);

    %---------------------------
    % 2) 构建全量 YALMIP 变量向量（与 mps.var_names 对齐）
    %---------------------------
    [allVars, varType] = build_yalmip_vars(mps.var_names, mps.is_integer, mps.is_binary);

    %---------------------------
    % 3) 上下层变量拆分（列向量）
    %---------------------------
    isLowerVar = ismember(mps.var_names, aux.lower_var_names);
    model.var_lower = allVars(isLowerVar);
    model.var_upper = allVars(~isLowerVar);

    %---------------------------
    % 4) 构建目标函数
    %---------------------------
    % 上层目标：来自 MPS objective row（N 行）
    model.obj_upper = mps.c_obj(:)' * allVars;

    % 下层目标：来自 AUX 的变量系数（只对 aux.lower_var_names）
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

    %---------------------------
    % 5) 构建约束（ROWS 中 L/G/E，按 aux.lower_constr_names 划分）
    %---------------------------
    model.cons_upper = [];
    model.cons_lower = [];

    isLowerRow = ismember(mps.constr_names, aux.lower_constr_names);

    for i = 1:numel(mps.constr_names)
        rowName = mps.constr_names{i};
        sense   = mps.constr_sense{i}; % '<=' , '>=' , '=='
        arow    = mps.A(i,:);          % 1-by-n sparse
        rhs     = mps.b(i);

        lhsExpr = arow * allVars;

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

    %---------------------------
    % 6) 将变量 bounds 转换为约束，并按规则归属上下层
    %---------------------------
    % MPS 中默认 lower bound=0, upper bound=+inf（除非 FR/MI/PL 等）
    for j = 1:numel(mps.var_names)
        x = allVars(j);
        lb = mps.lb(j);
        ub = mps.ub(j);

        % 对 binvar/intvar，YALMIP 会自带整数/0-1属性；
        % 这里仍然将有限 bounds 显式添加为约束（更清晰也更稳妥）
        cons_bnd = [];
        if ~isinf(lb)
            cons_bnd = [cons_bnd, (x >= lb)];
        end
        if ~isinf(ub)
            cons_bnd = [cons_bnd, (x <= ub)];
        end

        if isempty(cons_bnd)
            continue;
        end

        if isLowerVar(j)
            model.cons_lower = [model.cons_lower, cons_bnd];
        else
            model.cons_upper = [model.cons_upper, cons_bnd];
        end
    end

    %---------------------------
    % 7)（可选）给出一点调试信息
    %---------------------------
    % disp(['Parsed vars = ', num2str(numel(mps.var_names)), ...
    %       ', constr = ', num2str(numel(mps.constr_names))]);

end

%==========================================================================
%                           子函数：解析 AUX
%==========================================================================
function aux = parse_aux_file(aux_path)
    lines = read_text_lines(aux_path);

    % 兼容大小写、兼容 @NUMCONSTR 与 @NUMCONSTRS、@CONSTRBEGIN 与 @CONSTRSBEGIN 等
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

            % section switches
            if any(strcmp(key, {'@VARSBEGIN'}))
                mode = "VARS";
                i = i + 1; continue;
            elseif any(strcmp(key, {'@VARSEND'}))
                mode = "";
                i = i + 1; continue;
            elseif any(strcmp(key, {'@CONSTRBEGIN','@CONSTRSBEGIN'}))
                mode = "CONSTR";
                i = i + 1; continue;
            elseif any(strcmp(key, {'@CONSTREND','@CONSTRSEND'}))
                mode = "";
                i = i + 1; continue;
            else
                % 其它关键字（@NUMVARS/@NUMCONSTRS/@NAME/@MPS/@LP）这里不强依赖
                i = i + 1; continue;
            end
        end

        if mode == "VARS"
            % 每行：varName + coeff（允许出现"C0002-1."这种无空格情况）
            [vname, coeff] = parse_name_coeff(s);
            aux.lower_var_names{end+1,1} = vname; %#ok<AGROW>
            aux.lower_obj_coeff(end+1,1) = coeff; %#ok<AGROW>
        elseif mode == "CONSTR"
            aux.lower_constr_names{end+1,1} = strtrim(s); %#ok<AGROW>
        else
            % ignore
        end

        i = i + 1;
    end

end

function [name, coeff] = parse_name_coeff(line)
    % 兼容：
    %  1) "C0002 -1."
    %  2) "C0002-1."
    %  3) "x12  3.5"
    % 思路：抓取末尾数值 token，其前面部分作为 name
    line = strtrim(line);

    % 末尾数值（支持科学计数）
    expr = '([+-]?\d+(\.\d*)?|\.\d+)([eEdD][+-]?\d+)?\s*$';
    m = regexp(line, expr, 'match');
    if isempty(m)
        error('AUX 变量行无法解析系数："%s"', line);
    end
    numStr = m{1};
    coeff = str2double(strrep(lower(numStr), 'd', 'e'));

    % name 是去掉末尾数值后剩余部分
    namePart = regexprep(line, expr, '');
    namePart = strtrim(namePart);

    % 如果 namePart 为空，说明类似 "-1." 单独出现，不合法
    if isempty(namePart)
        error('AUX 变量行无法解析变量名："%s"', line);
    end
    name = namePart;
end

%==========================================================================
%                           子函数：解析 MPS
%==========================================================================
function mps = parse_mps_file(mps_path)
    lines = read_text_lines(mps_path);

    section = "";
    rowNames = {};
    rowTypes = {}; % 'N','L','G','E'
    objRowName = '';

    % 用 map 管理索引
    rowIndex = containers.Map();
    varIndex = containers.Map();

    varNames = {};
    isInt = [];
    isBin = [];
    % 系数暂存：用 triplet (iRow, jVar, val)
    I = [];
    J = [];
    V = [];

    % RHS 与 bounds
    rhsMap = containers.Map(); % rowName -> rhs
    % 默认 bounds：0 <= x <= inf
    lb = [];
    ub = [];

    inIntBlock = false;

    for k = 1:numel(lines)
        raw = lines{k};
        s = strtrim(raw);
        if isempty(s) || startsWith(s, '*')
            continue;
        end

    %------------------------------------------------------------
    % 识别 section（修复版）
    % 说明：
    %   不能用"首 token"判断 section，因为 RHS 段的数据行常以 rhs 开头，
    %   upper(rhs)=RHS 会误判为 section 行，导致 RHS 数据被跳过。
    %   正确做法：仅当整行等于关键字（或 NAME 行特殊处理）才切换 section。
    %------------------------------------------------------------
    
    sU = upper(strtrim(s));
    
    % NAME 行特殊：通常为 "NAME  instance"
    if startsWith(sU, 'NAME', 'IgnoreCase', true)
        section = 'NAME';
        % 这里不 continue 也行，但为了统一逻辑，直接 continue
        continue;
    end
    
    % 其它 section 行：通常整行就是关键字
    if any(strcmp(sU, {'ROWS','COLUMNS','RHS','BOUNDS','RANGES','ENDATA'}))
        section = sU;
        if strcmp(section, 'RANGES')
            warning('检测到 RANGES 段：当前代码未处理该段，将忽略。');
        end
        continue;
    end


        switch section
            case 'ROWS'
                % 格式：<type> <rowName>
                toks = split_ws(s);
                if numel(toks) < 2
                    continue;
                end
                rtype = upper(toks{1});
                rname = toks{2};

                rowNames{end+1,1} = rname; %#ok<AGROW>
                rowTypes{end+1,1} = rtype; %#ok<AGROW>
                rowIndex(rname) = numel(rowNames);

                if strcmp(rtype, 'N') && isempty(objRowName)
                    objRowName = rname;
                end

            case 'COLUMNS'
                % 可能出现 marker 行：MARKxxxx 'MARKER' 'INTORG'/'INTEND'
                if contains(s, 'MARKER', 'IgnoreCase', true) && ...
                   (contains(s, 'INTORG', 'IgnoreCase', true) || contains(s, 'INTEND', 'IgnoreCase', true))
                    if contains(s, 'INTORG', 'IgnoreCase', true)
                        inIntBlock = true;
                    elseif contains(s, 'INTEND', 'IgnoreCase', true)
                        inIntBlock = false;
                    end
                    continue;
                end

                toks = split_ws(s);
                if numel(toks) < 3
                    continue;
                end

                vname = toks{1};
                if ~isKey(varIndex, vname)
                    varNames{end+1,1} = vname; %#ok<AGROW>
                    varIndex(vname) = numel(varNames);

                    % 初始化类型与 bounds
                    isInt(end+1,1) = inIntBlock; %#ok<AGROW>
                    isBin(end+1,1) = false;      %#ok<AGROW>
                    lb(end+1,1) = 0;             %#ok<AGROW>
                    ub(end+1,1) = inf;           %#ok<AGROW>
                else
                    % 若之前见过，若当前在整数块内，也将其标为整数
                    if inIntBlock
                        isInt(varIndex(vname)) = true;
                    end
                end

                j = varIndex(vname);

                % 后续按 (row, val) 成对出现，最多两对
                pairs = toks(2:end);
                if mod(numel(pairs),2) ~= 0
                    % 容错：有些 MPS 行可能不规范
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
                % 格式：rhsName row val [row val]
                toks = split_ws(s);
                if numel(toks) < 3
                    continue;
                end
                % rhsName = toks{1}; % 可忽略
                pairs = toks(2:end);
                if mod(numel(pairs),2) ~= 0
                    pairs = pairs(1:end-1);
                end
                for p = 1:2:numel(pairs)
                    rname = pairs{p};
                    val   = str2double_mps(pairs{p+1});
                    rhsMap(rname) = val; % 覆盖式
                end

            case 'BOUNDS'
                % 格式：btype bndName varName value?
                toks = split_ws(s);
                if numel(toks) < 3
                    continue;
                end
                btype = upper(toks{1});
                vname = toks{3};

                if ~isKey(varIndex, vname)
                    % 如果 bounds 出现新变量名，按标准也允许：这里补建变量
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
                    otherwise
                        warning('未处理的 BOUNDS 类型 "%s"（变量=%s），将忽略该行。', btype, vname);
                end

            case 'RANGES'
                % 忽略
            otherwise
                % ignore
        end
    end

    if isempty(objRowName)
        error('MPS 中未找到 objective row（ROWS 段需要至少一个 N 行）。');
    end

    % 将 triplet 组装为 sparse 系数矩阵（ROWS全体 x VARS全体）
    Aall = sparse(I, J, V, numel(rowNames), numel(varNames));

    % 分离 objective 与 constraints
    objRowIdx = rowIndex(objRowName);
    c_obj = full(Aall(objRowIdx,:)); % 1-by-n

    % constraints 是除 objective row 外的 ROWS 中 L/G/E
    constrNames = {};
    constrSense = {};
    Arows = [];
    brows = [];

    for i = 1:numel(rowNames)
        if i == objRowIdx
            continue;
        end

        rtype = rowTypes{i};
        rname = rowNames{i};

        if strcmp(rtype, 'L')
            sense = '<=';
        elseif strcmp(rtype, 'G')
            sense = '>=';
        elseif strcmp(rtype, 'E')
            sense = '==';
        else
            % 额外 N 行：通常表示自由行/额外目标，不纳入约束
            continue;
        end

        constrNames{end+1,1} = rname; %#ok<AGROW>
        constrSense{end+1,1} = sense; %#ok<AGROW>

        Arows(end+1,:) = Aall(i,:); %#ok<AGROW>
        if isKey(rhsMap, rname)
            brows(end+1,1) = rhsMap(rname); %#ok<AGROW>
        else
            brows(end+1,1) = 0; %#ok<AGROW>
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
%                       子函数：构建 YALMIP 变量
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

    % 拼成列向量
    allVars = vertcat(varCells{:});
end

%==========================================================================
%                           工具函数：读文本
%==========================================================================
function lines = read_text_lines(path)
    fid = fopen(path, 'r');
    if fid < 0
        error('无法打开文件：%s', path);
    end
    c = onCleanup(@() fclose(fid));
    lines = {};
    while true
        tline = fgetl(fid);
        if ~ischar(tline)
            break;
        end
        lines{end+1,1} = tline; %#ok<AGROW>
    end
end

function tok = first_token(s)
    toks = split_ws(s);
    if isempty(toks)
        tok = '';
    else
        tok = toks{1};
    end
end

function toks = split_ws(s)
    % 按空白分割，去掉空 token
    toks = regexp(strtrim(s), '\s+', 'split');
    toks = toks(~cellfun('isempty', toks));
end

function v = str2double_mps(s)
    % MPS 里可能出现 D 指数：1.0D+03
    s = strtrim(s);
    s = regexprep(s, '[dD]', 'e');
    v = str2double(s);
    if isnan(v)
        error('无法解析数值："%s"', s);
    end
end
