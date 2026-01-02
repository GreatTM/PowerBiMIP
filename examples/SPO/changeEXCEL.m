%% ----------------------------HELLO------------------------------ %%
% 版本更新log:[v2024-04-03]每个新能源机组都输出一个mat，纵坐标将改为：第一列为实际值、第二列为最近预测值、第三列为日前6pm的预测值、第四列为日前11am的预测值、第五列为一周前的预测值

% 功能说明：可以把Elia网站上的风电、光伏、负荷数据转换成便于处理的mat格式数据，可以处理任意日期范围

% 调用示例：changeEXCEL('2023Belguim_load_data.xlsx',...
%                      '2023Belguim_solar_data.xlsx',...
%                      '2023Belguim_wind_data.xlsx')

% 输入：任意从Elia网站上下载的xlsx格式负荷、风电、光伏数据

% 输出：
% ----------------------------load_mat------------------------- %
%                  Total Load
% Time（间隔15分钟）    ***
% ------------------------------------------------------------- %

% -------------------------offshorewind_mat-------------------- %
%                  Measured_Upscaled   Most_recent_forecast   Dayahead_6pm_forecast   Dayahead_11am_forecast   Weekahead_forecast
% Time（间隔15分钟）       ***                   ***                   ***                     ***                      ***
% ------------------------------------------------------------- %

% -------------------------Flanderswind_mat-------------------- %
%                  Measured_Upscaled   Most_recent_forecast   Dayahead_6pm_forecast   Dayahead_11am_forecast   Weekahead_forecast
% Time（间隔15分钟）       ***                   ***                   ***                     ***                      ***
% ------------------------------------------------------------- %

% -------------------------Walloniaswind_mat-------------------- %
%                  Measured_Upscaled   Most_recent_forecast   Dayahead_6pm_forecast   Dayahead_11am_forecast   Weekahead_forecast
% Time（间隔15分钟）       ***                   ***                   ***                     ***                      ***
% ------------------------------------------------------------- %

% -------------------------Flanderssolar_mat-------------------- %
%                  Measured_Upscaled   Most_recent_forecast   Dayahead_6pm_forecast   Dayahead_11am_forecast   Weekahead_forecast
% Time（间隔15分钟）       ***                   ***                   ***                     ***                      ***
% ------------------------------------------------------------- %

% -------------------------Walloniassolar_mat-------------------- %
%                  Measured_Upscaled   Most_recent_forecast   Dayahead_6pm_forecast   Dayahead_11am_forecast   Weekahead_forecast
% Time（间隔15分钟）       ***                   ***                   ***                     ***                      ***
% ------------------------------------------------------------- %
% filename_Belguimload = '2023Belguim_load_data.xlsx'
% filename_Belguimwind = '2023Belguim_wind_data.xlsx'
% filename_Belguimsolar = '2023Belguim_solar_data.xlsx'
%% ----------------------------START------------------------------ %%
function changeEXCEL(filename_Belguimload,...
                     filename_Belguimwind,...
                     filename_Belguimsolar, ...
                     filename_Belguimtemperature)
    %% ----------------------------温度-------------------------------- %%
    % 检查路径中是否存在温度mat文件
    if exist('Belguimtemperature.mat', 'file')
        % disp('比利时温度数据mat文件已存在，无需重新生成。');
    else
        % 读取 Excel 文件中的数据
        data_temperature = readtable(filename_Belguimtemperature);
        
        % 缺省值填补
        data_temperature(:, 3:end) = fillmissing(data_temperature(:, 3:end), 'linear');

        % 第三列数据作为实际值，后面四列作为预测值
        data_temperature = data_temperature(:,3:end);
        
        % 表格转数组
        temperature_mat = table2array(data_temperature);
        
        % 保存数据为.mat文件
        save('Belguimtemperature.mat', 'temperature_mat');

        disp('比利时温度数据mat文件已生成。');
    end

    %% ----------------------------负荷-------------------------------- %%
    % 检查路径中是否存在负荷mat文件
    if exist('Belguimload.mat', 'file')
        % disp('比利时负荷数据mat文件已存在，无需重新生成。');
    else
        % 读取 Excel 文件中的数据
        data_load = readtable(filename_Belguimload);
        
        % 缺省值填补
        data_load(:, 3:end) = fillmissing(data_load(:, 3:end), 'linear');

        % 将数据倒序
        load_mat = flipud(data_load);
        
        % 第三列数据作为实际值，后面四列作为预测值
        load_mat = load_mat(:,3:7);
        
        % 表格转数组
        load_mat = table2array(load_mat);
        
        % 保存数据为.mat文件
        save('Belguimload.mat', 'load_mat');

        disp('比利时负荷数据mat文件已生成。');
    end

    %% -------------------------风电--------------------------- %%
    % 检查路径中是否存在风电mat文件
    if exist('Belguimoffshore_wind.mat', 'file') &&...
            exist('BelguimFlanders_wind.mat', 'file') &&...
            exist('BelguimWallonias_wind.mat', 'file') % 如果三个文件都存在
        % disp('比利时风电数据mat文件已存在，无需重新生成。');
    else
        % 读取原始Excel文件
        data_wind = readtable(filename_Belguimwind);
        
        % 统一时区（原数据中有一段时间采用夏令时，需要统一时区）
        data_wind.Datetime = datetime(data_wind.Datetime,...
            'InputFormat', 'yyyy-MM-dd''T''HH:mm:ssXXX', 'TimeZone', 'UTC+01:00');
        
        % 缺省值填充
        data_wind(:, 6:20) = fillmissing(data_wind(:, 6:20), 'linear');
        
        % 获取唯一的时间点
        unique_times = unique(data_wind.Datetime);
        
        % 初始化offshore_wind新表
        offshore_wind_mat = zeros(length(unique_times),5); % 1个实际值+4个不同时段的预测值，因此是5个
        % 初始化Flanders_wind新表
        Flanders_wind_mat = zeros(length(unique_times),5); % 1个实际值+4个不同时段的预测值，因此是5个
        % 初始化Wallonias_wind新表
        Wallonias_wind_mat = zeros(length(unique_times),5); % 1个实际值+4个不同时段的预测值，因此是5个           

        % 循环处理每个时间点
        for i = 1:length(unique_times)
            % 选择当前时间点的数据
            current_data = data_wind(data_wind.Datetime == unique_times(i), :);

            % 合并当前时间点的数据并添加到新表
            offshore_meas_upscaled = current_data(strcmp(current_data.Offshore_onshore, "Offshore"), :).Measured_Upscaled;
            onshore_flanders_meas_upscaled = current_data(strcmp(current_data.Region, "Flanders"), :).Measured_Upscaled;
            onshore_wallonia_meas_upscaled = current_data(strcmp(current_data.Region, "Wallonia"), :).Measured_Upscaled;
            
            % 合并当前时间点的数据并添加到新表
            offshore_MostRecentForecast = current_data(strcmp(current_data.Offshore_onshore, "Offshore"), :).MostRecentForecast;
            onshore_flanders_MostRecentForecast = current_data(strcmp(current_data.Region, "Flanders"), :).MostRecentForecast;
            onshore_wallonia_MostRecentForecast = current_data(strcmp(current_data.Region, "Wallonia"), :).MostRecentForecast;
           
            % 合并当前时间点的数据并添加到新表
            offshore_MostRecentP10 = current_data(strcmp(current_data.Offshore_onshore, "Offshore"), :).MostRecentP10;
            onshore_flanders_MostRecentP10 = current_data(strcmp(current_data.Region, "Flanders"), :).MostRecentP10;
            onshore_wallonia_MostRecentP10 = current_data(strcmp(current_data.Region, "Wallonia"), :).MostRecentP10;

            % 合并当前时间点的数据并添加到新表
            offshore_MostRecentP90 = current_data(strcmp(current_data.Offshore_onshore, "Offshore"), :).MostRecentP90;
            onshore_flanders_MostRecentP90 = current_data(strcmp(current_data.Region, "Flanders"), :).MostRecentP90;
            onshore_wallonia_MostRecentP90 = current_data(strcmp(current_data.Region, "Wallonia"), :).MostRecentP90;

            % 合并当前时间点的数据并添加到新表
            offshore_DayAhead11AMForecast = current_data(strcmp(current_data.Offshore_onshore, "Offshore"), :).DayAhead11AMForecast;
            onshore_flanders_DayAhead11AMForecast = current_data(strcmp(current_data.Region, "Flanders"), :).DayAhead11AMForecast;
            onshore_wallonia_DayAhead11AMForecast = current_data(strcmp(current_data.Region, "Wallonia"), :).DayAhead11AMForecast;

            offshore_wind_mat(i,1) = sum(offshore_meas_upscaled);
            offshore_wind_mat(i,2) = sum(offshore_MostRecentForecast);
            offshore_wind_mat(i,3) = sum(offshore_MostRecentP10);
            offshore_wind_mat(i,4) = sum(offshore_MostRecentP90);
            offshore_wind_mat(i,5) = sum(offshore_DayAhead11AMForecast);

            Flanders_wind_mat(i,1) = sum(onshore_flanders_meas_upscaled);
            Flanders_wind_mat(i,2) = sum(onshore_flanders_MostRecentForecast);
            Flanders_wind_mat(i,3) = sum(onshore_flanders_MostRecentP10);
            Flanders_wind_mat(i,4) = sum(onshore_flanders_MostRecentP90);
            Flanders_wind_mat(i,5) = sum(onshore_flanders_DayAhead11AMForecast);

            Wallonias_wind_mat(i,1) = sum(onshore_wallonia_meas_upscaled);
            Wallonias_wind_mat(i,2) = sum(onshore_wallonia_MostRecentForecast);
            Wallonias_wind_mat(i,3) = sum(onshore_wallonia_MostRecentP10);
            Wallonias_wind_mat(i,4) = sum(onshore_wallonia_MostRecentP90);
            Wallonias_wind_mat(i,5) = sum(onshore_wallonia_DayAhead11AMForecast);            
        end
        
        % 保存数据为.mat文件
        save('Belguimoffshore_wind.mat', 'offshore_wind_mat');
        disp('比利时offshore风电数据mat文件已生成。');
        save('BelguimFlanders_wind.mat', 'Flanders_wind_mat');
        disp('比利时Flanders风电数据mat文件已生成。');
        save('BelguimWallonias_wind.mat', 'Wallonias_wind_mat');
        disp('比利时Wallonias风电数据mat文件已生成。');
    end

    %% -----------------------------光伏------------------------------- %%
    if exist('BelguimFlanders_solar.mat', 'file') &&...
            exist('BelguimWallonias_solar.mat', 'file')  % 如果两个文件都存在
        % disp('比利时光伏数据mat文件已存在，无需重新生成。');
    else
        % 读取原始Excel文件
        data_solar = readtable(filename_Belguimsolar);
        
        % 统一时区（原数据中有一段时间采用夏令时，需要统一时区）
        data_solar.Datetime = datetime(data_solar.Datetime,...
            'InputFormat', 'yyyy-MM-dd''T''HH:mm:ssXXX', 'TimeZone', 'UTC+01:00');

        % 缺省值补填充
        data_solar(:, 4:end) = fillmissing(data_solar(:, 4:end), 'linear');
        
        % 获取唯一的时间点
        unique_times = unique(data_solar.Datetime);
        
        % 初始化flanders_solar新表
        Flanders_solar_mat = zeros(length(unique_times),5);
        % 初始化wallonias_solar新表
        Wallonias_solar_mat = zeros(length(unique_times),5);

        % 循环处理每个时间点
        for i = 1:length(unique_times)
            % 选择当前时间点的数据
            current_data = data_solar(data_solar.Datetime == unique_times(i), :);

            % 合并当前时间点的数据并添加到新表
            Flanders_Measured_Upscaled = current_data(strcmp(current_data.Region, "Flanders"), :).Measured_Upscaled;
            Wallonias_Measured_Upscaled = current_data(strcmp(current_data.Region, "Wallonia"), :).Measured_Upscaled;
 
            Flanders_MostRecentForecast = current_data(strcmp(current_data.Region, "Flanders"), :).MostRecentForecast;
            Wallonias_MostRecentForecast = current_data(strcmp(current_data.Region, "Wallonia"), :).MostRecentForecast;
            
            Flanders_MostRecentP10 = current_data(strcmp(current_data.Region, "Flanders"), :).MostRecentP10;
            Wallonias_MostRecentP10 = current_data(strcmp(current_data.Region, "Wallonia"), :).MostRecentP10;

            Flanders_MostRecentP90 = current_data(strcmp(current_data.Region, "Flanders"), :).MostRecentP90;
            Wallonias_MostRecentP90 = current_data(strcmp(current_data.Region, "Wallonia"), :).MostRecentP90;

            Flanders_DayAhead11AMForecast = current_data(strcmp(current_data.Region, "Flanders"), :).DayAhead11AMForecast;
            Wallonias_DayAhead11AMForecast = current_data(strcmp(current_data.Region, "Wallonia"), :).DayAhead11AMForecast;

            Flanders_solar_mat(i,1) = sum(Flanders_Measured_Upscaled);
            Flanders_solar_mat(i,2) = sum(Flanders_MostRecentForecast);
            Flanders_solar_mat(i,3) = sum(Flanders_MostRecentP10);
            Flanders_solar_mat(i,4) = sum(Flanders_MostRecentP90);
            Flanders_solar_mat(i,5) = sum(Flanders_DayAhead11AMForecast);

            Wallonias_solar_mat(i,1) = sum(Wallonias_Measured_Upscaled);
            Wallonias_solar_mat(i,2) = sum(Wallonias_MostRecentForecast);
            Wallonias_solar_mat(i,3) = sum(Wallonias_MostRecentP10);
            Wallonias_solar_mat(i,4) = sum(Wallonias_MostRecentP90);
            Wallonias_solar_mat(i,5) = sum(Wallonias_DayAhead11AMForecast);

        end
        
        % 保存数据为.mat文件
        save('BelguimFlanders_solar.mat', 'Flanders_solar_mat');
        disp('比利时Flanders光伏数据mat文件已生成。');
        save('BelguimWallonias_solar.mat', 'Wallonias_solar_mat');
        disp('比利时Wallonias光伏数据mat文件已生成。');
    end
end