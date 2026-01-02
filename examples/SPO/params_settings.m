function params = params_settings(varargin)
    % 默认参数设置
    default_params = struct();
    
    %% 数据输入模块参数
    default_params.system_kind = 'eps';       % 系统类型 [eps|ies]
    default_params.system_scale = 'big';      % 系统规模 [small|medium|big]
    default_params.train_start_time = '2023-02-07 00:00:00';
    default_params.train_end_time = '2023-02-13 23:45:00';
    default_params.test_start_time = '2023-02-08 00:00:00';
    default_params.test_end_time = '2023-02-08 23:45:00';
    
    %% 模型参数设置
    default_params.res_curtailment = 1;       % 允许弃风 [0|1]
    default_params.load_shedding = 1;         % 允许切负荷 [0|1]
    default_params.regularization_coefficient = 1e3;  % 正则化系数
    default_params.regularization_selection = 2;      % 正则化类型 [0|1|2]
    default_params.results_record = 0;
    
    % 初始化参数为默认值
    params = default_params;
    
    % 处理用户自定义参数
    if nargin > 0
        % 验证参数对数量
        if mod(nargin, 2) ~= 0
            error('输入参数必须为键值对形式，例如：(''system_kind'', ''ies'')');
        end
        
        % 遍历并覆盖参数
        for i = 1:2:nargin
            param_name = varargin{i};
            param_value = varargin{i+1};
            
            % 参数存在性检查
            if isfield(default_params, param_name)
                params.(param_name) = param_value;
            else
                % 添加新参数并警告
                params.(param_name) = param_value;
                warning('检测到非标准参数: "%s"，已添加到参数列表', param_name);
            end
        end
    end
end
