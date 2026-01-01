%% -------------------------HELLO-------------------------- %%
% 功能说明：本函数用于导入比利时真实的负荷和风电光伏预测、实际数据，可以实现自动选择要导入数据的日期范围和时间步长

% 输入：data_starttime(数据集起始日期,数据格式：'2023-01-01 00:00:00')
%      data_lasttime(数据集结束日期,数据格式：'2023-12-31 23:45:00')
%      loading_starttime（加载数据的起始日,数据格式：'2023-01-01 00:00:00'）
%      loading_endtime（加载数据的结束日,数据格式：'2023-01-07 23:45:00'）
%       *******************************************************************
%       *     注意，1、代码将输入的时间统一转换为了UTC+1时区                  *
%       *          2、输入的数据集起始日期和结束日期必须确保与载入的数据集一致！*
%       *******************************************************************
%      time_resolution（时间分辨率，可以选择15min、30min、1h）

% 输出：load_data_normalized（要加载时间范围的负荷数据）（Ntime*1）
%      RES_feature_data_normalized（要加载时间范围的所有RES特征向量）（Ntime*20）（按照先风电后光伏、offshore、flanders、wallonias的顺序排列）
%      RES_realization_data_normalized（要加载时间范围的所有RES实际功率）（Ntime*1）（所有新能源机组的功率之和）
%      offshore_wind_feature_data_normalized（要加载时间范围的offshore风电预测数据）（Ntime*4）
%      flanders_wind_feature_data_normalized（要加载时间范围的flanders风电预测数据）（Ntime*4）
%      wallonias_wind_feature_data_normalized（要加载时间范围的wallonias风电预测数据）（Ntime*4）
%      offshore_wind_realization_data_normalized（要加载时间范围的offshore风电实际数据）（Ntime*1）
%      flanders_wind_realization_data_normalized（要加载时间范围的flanders风电实际数据）（Ntime*1）
%      wallonias_wind_realization_data_normalized（要加载时间范围的wallonias风电实际数据）（Ntime*1）
%      flanders_solar_feature_data_normalized（要加载时间范围的flanders光伏预测数据）（Ntime*4）
%      wallonias_solar_feature_data_normalized（要加载时间范围的wallonias光伏预测数据）（Ntime*4）
%      flanders_solar_realization_data_normalized（要加载时间范围的flanders光伏实际数据）（Ntime*1）
%      wallonias_solar_realization_data_normalized（要加载时间范围的wallonias光伏实际数据）（Ntime*1）

% 调用示例：
%          [load_data,...
%           RES_feature_data,...
%           RES_realization_data,...
%           offshore_wind_feature_data,...
%           flanders_wind_feature_data,...
%           wallonias_wind_feature_data,...
%           offshore_wind_realization_data,...
%           flanders_wind_realization_data,...
%           wallonias_wind_realization_data,...
%           flanders_solar_feature_data,...
%           wallonias_solar_feature_data,...
%           flanders_solar_realization_data,...
%           wallonias_solar_realization_data] =  Belgium_load_RES_dataload('2023-01-01 00:00:00',...
%                                                                          '2023-12-31 23:45:00',...
%                                                                          '2023-01-01 00:00:00',...
%                                                                          '2023-01-07 23:45:00',...
%                                                                          0.25,...
%                                                                          '2023Belguim_load_data.xlsx',...
%                                                                          '2023Belguim_wind_data.xlsx',...
%                                                                          '2023Belguim_solar_data.xlsx');

% 版本更新：
%          [2024-07-24]加入归一化
%          [2024-04-25]加入负荷和风电缩放系数选取规则：
%                      如果不考虑弃风和切负荷，1、负荷的最大值最好<=常规机组出力上限之和
%                      2、风电的最大值 + pchp的最大值 + 0.03totalload最大值<=负荷的最小值（防止功率不平衡、旋转备用不够）
%          [2024-04-23]添加功能：可以调整输入数据的时间分辨率
%          [2024-04-03]changeEXCEL代码配套更新，输入数据改为每个RES机组一个mat，行标签为时间，列标签为真实值和4个特征向量
%          [2024-03]完成第一版，特征向量为1个
%% -------------------------START-------------------------- %%
function [load_feature_data,...
          load_realization_data,...
          RES_feature_data,...
          RES_realization_data,...
          offshore_wind_feature_data,...
          flanders_wind_feature_data,...
          wallonias_wind_feature_data,...
          offshore_wind_realization_data,...
          flanders_wind_realization_data,...
          wallonias_wind_realization_data,...
          flanders_solar_feature_data,...
          wallonias_solar_feature_data,...
          flanders_solar_realization_data,...
          wallonias_solar_realization_data,...
          temperature_data] = Belgium_load_RES_dataload(data_starttime,...
                                                        data_lasttime,...
                                                        loading_starttime,...
                                                        loading_endtime,...
                                                        time_resolution,... 
                                                        filename_Belguimload,...
                                                        filename_Belguimwind,...
                                                        filename_Belguimsolar,...
                                                        filename_Belguimtemperature)
    %% ------------------------数据载入------------------------- %%
    % 调用 changeEXCEL 函数将 Excel 文件转换为 .mat 格式
    changeEXCEL(filename_Belguimload, filename_Belguimwind, filename_Belguimsolar, filename_Belguimtemperature);
    load('Belguimload.mat');
    load('Belguimoffshore_wind.mat');
    load('BelguimFlanders_wind.mat');
    load('BelguimWallonias_wind.mat');
    load('BelguimFlanders_solar.mat');
    load('BelguimWallonias_solar.mat');
    load('Belguimtemperature.mat');
    
    %% ------------------------数据归一化----------------------- %%
    % load_mat数据
    load_mat_normalized = zeros(size(load_mat));
    for i = 1:size(load_mat, 2)
        load_mat_normalized(:,i) = (load_mat(:,i) - min(min(load_mat))) / (max(max(load_mat)) - min(min(load_mat)));
    end

    % offshore_wind_mat数据
    offshore_wind_mat_normalized = zeros(size(offshore_wind_mat)); 
    for i = 1:size(offshore_wind_mat, 2)
        offshore_wind_mat_normalized(:,i) = (offshore_wind_mat(:,i) - min(min(offshore_wind_mat))) / (max(max(offshore_wind_mat)) - min(min(offshore_wind_mat)));
    end

    % Flanders_wind_mat数据
    Flanders_wind_mat_normalized = zeros(size(Flanders_wind_mat)); 
    for i = 1:size(Flanders_wind_mat, 2)
        Flanders_wind_mat_normalized(:,i) = (Flanders_wind_mat(:,i) - min(min(Flanders_wind_mat))) / (max(max(Flanders_wind_mat)) - min(min(Flanders_wind_mat)));
    end
    % Wallonias_wind_mat数据
    Wallonias_wind_mat_normalized = zeros(size(Wallonias_wind_mat)); 
    for i = 1:size(Wallonias_wind_mat, 2)
        Wallonias_wind_mat_normalized(:,i) = (Wallonias_wind_mat(:,i) - min(min(Wallonias_wind_mat))) / (max(max(Wallonias_wind_mat)) - min(min(Wallonias_wind_mat)));
    end
    % Flanders_solar_mat数据
    Flanders_solar_mat_normalized = zeros(size(Flanders_solar_mat)); 
    for i = 1:size(Flanders_solar_mat, 2)
        Flanders_solar_mat_normalized(:,i) = (Flanders_solar_mat(:,i) - min(min(Flanders_solar_mat))) / (max(max(Flanders_solar_mat)) - min(min(Flanders_solar_mat)));
    end
    % Wallonias_solar_mat数据
    Wallonias_solar_mat_normalized = zeros(size(Wallonias_solar_mat)); 
    for i = 1:size(Wallonias_solar_mat, 2)
        Wallonias_solar_mat_normalized(:,i) = (Wallonias_solar_mat(:,i) - min(min(Wallonias_solar_mat))) / (max(max(Wallonias_solar_mat)) - min(min(Wallonias_solar_mat)));
    end

    %% ---------------------计算日期对应的行数------------------- %%
    % 定义原始步长为15分钟
    base_step_duration = duration(0, 15, 0);

    % 将输入日期转换为 datetime 类型
    data_starttime = datetime(data_starttime);
    data_lasttime = datetime(data_lasttime);
    loading_starttime = datetime(loading_starttime);
    loading_endtime = datetime(loading_endtime);

    % 计算原始数据范围内的总步数
    total_base_steps = floor((data_lasttime - data_starttime) / base_step_duration) + 1;

    % 计算加载数据范围内的原始步数
    % 计算输入日期与起始日期之间的时间差
    time_difference_loading_starttime = loading_starttime - data_starttime;
    time_difference_loading_endtime = loading_endtime - data_starttime;
    % 计算输入日期对应的数据行索引
    loading_starttime_index = floor(time_difference_loading_starttime / base_step_duration) + 1;
    loading_endtime_index = floor(time_difference_loading_endtime / base_step_duration) + 1;
    
    % 如果输入日期超出范围，则返回 NaN
    if loading_starttime_index < 1 || loading_starttime_index > total_base_steps
        loading_starttime_index = NaN;
    end
    if loading_endtime_index < 1 || loading_endtime_index > total_base_steps
        loading_endtime_index = NaN;
    end

    % 根据时间分辨率调整时间索引
    switch time_resolution
         case 0.25
             aggregation_factor = 1; % 不做聚合
         case 0.5
             aggregation_factor = 2;
         case 1
             aggregation_factor = 4;
         otherwise
             error('Invalid time resolution. Please choose between ''0.25'', ''0.5'' and ''1''.');
     end
        
    %% --------------------------输出----------------------------- %%
    % 获取负载特征数据
    load_feature_data = load_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 2:5);
    % 获取负载实现数据
    load_realization_data = load_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 1);
    % 获取offshore风电特征数据
    offshore_wind_feature_data = offshore_wind_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 2:5);
    % 获取offshore风电实现数据
    offshore_wind_realization_data = offshore_wind_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 1);

    % 获取flanders风电特征数据
    flanders_wind_feature_data = Flanders_wind_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 2:5);
    % 获取flanders风电实现数据
    flanders_wind_realization_data = Flanders_wind_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 1);

    % 获取wallonias风电特征数据
    wallonias_wind_feature_data = Wallonias_wind_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 2:5);
    % 获取wallonias风电实现数据
    wallonias_wind_realization_data = Wallonias_wind_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 1);

    % 获取flanders光伏特征数据
    flanders_solar_feature_data = Flanders_solar_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 2:5);
    % 获取flanders光伏实现数据
    flanders_solar_realization_data = Flanders_solar_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 1);

    % 获取wallonias光伏特征数据
    wallonias_solar_feature_data = Wallonias_solar_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 2:5);
    % 获取wallonias光伏实现数据
    wallonias_solar_realization_data = Wallonias_solar_mat_normalized(loading_starttime_index:aggregation_factor:loading_endtime_index, 1);

    % 获取所有RES的特征数据
    RES_feature_data = [offshore_wind_feature_data, flanders_wind_feature_data, wallonias_wind_feature_data,...
        flanders_solar_feature_data, wallonias_solar_feature_data];
    % 获取所有RES的实现数据
    RES_realization_data = offshore_wind_realization_data + flanders_wind_realization_data + wallonias_wind_realization_data + ...
        flanders_solar_realization_data + wallonias_solar_realization_data;

    % 获取温度数据（新增输出）
    temperature_data = temperature_mat(loading_starttime_index:aggregation_factor:loading_endtime_index, 1);

end