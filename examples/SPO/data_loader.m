function [system_data, training_data, test_data] = data_loader(~)
%DATA_LOADER Loads system data and preprocessed training/test data for SPO example.
%
%   Description:
%       Simplified data loader that loads the IEEE 118-bus system data from
%       Excel file and preprocessed training/test datasets from mat files.
%
%   Input:
%
%   Output:
%       system_data   - struct: IEEE 118-bus system parameters
%       training_data - struct: Training dataset
%       test_data     - struct: Test dataset

    %% 从Excel加载118节点系统数据
    excelFile = 'system_data_118bus.xlsx';
    
    % 读取基础系统参数
    systemInfo = readtable(excelFile, 'Sheet', 'SystemInfo');
    system_data.Sbase = systemInfo.Value(strcmp(systemInfo.Parameter, 'Sbase'));
    system_data.Nbus = systemInfo.Value(strcmp(systemInfo.Parameter, 'Nbus'));
    system_data.Ngen = systemInfo.Value(strcmp(systemInfo.Parameter, 'Ngen'));
    system_data.Nrenewablegen = systemInfo.Value(strcmp(systemInfo.Parameter, 'Nrenewablegen'));
    system_data.Nload = systemInfo.Value(strcmp(systemInfo.Parameter, 'Nload'));
    
    % 读取发电机数据 (MATPOWER格式 + 扩展列)
    genData = readtable(excelFile, 'Sheet', 'Gen');
    system_data.gen_bus = genData.bus;
    system_data.plimit.upper = genData.Pmax / system_data.Sbase;
    system_data.plimit.lower = genData.Pmin / system_data.Sbase;
    % 爬坡限制基于出力上限计算
    system_data.ramplimit.up = 0.2 * system_data.plimit.upper;
    system_data.ramplimit.down = 0.2 * system_data.plimit.upper;
    system_data.ramplimit.sup = 0.5 * (system_data.plimit.upper + system_data.plimit.lower);
    system_data.ramplimit.sdown = 0.5 * (system_data.plimit.upper + system_data.plimit.lower);
    system_data.mintime.on = genData.mintime_on;
    system_data.mintime.off = genData.mintime_off;
    
    % 读取支路数据 (MATPOWER格式 + 扩展列)
    branchData = readtable(excelFile, 'Sheet', 'Branch');
    system_data.pbranchlimit.upper = branchData.pbranchlimit_upper;
    system_data.pbranchlimit.lower = branchData.pbranchlimit_lower;
    
    % 读取发电机成本数据 (MATPOWER格式 + 扩展列)
    gencostData = readtable(excelFile, 'Sheet', 'GenCost');
    system_data.cost.c0 = gencostData.cost_c0 / system_data.Sbase;
    system_data.cost.c1 = gencostData.cost_c1;
    system_data.cost.c2 = gencostData.cost_c2;
    system_data.cost.startup = gencostData.startup / system_data.Sbase;
    system_data.cost.shutdown = gencostData.shutdown / system_data.Sbase;
    system_data.cost.compensation_up = gencostData.compensation_up;
    system_data.cost.compensation_down = gencostData.compensation_down;
    
    % 读取新能源机组参数
    renewableData = readtable(excelFile, 'Sheet', 'RenewableGen');
    system_data.renewablegen_bus = renewableData.renewablegen_bus;
    system_data.RES_weight = renewableData.RES_weight;
    system_data.resplimit.upper = renewableData.resplimit_upper;
    
    % 读取负荷参数
    loadData = readtable(excelFile, 'Sheet', 'Load');
    system_data.load_bus = loadData.load_bus;
    system_data.load_weight = loadData.load_weight;
    
    % 读取PTDF矩阵
    system_data.PTDF.gen = readmatrix(excelFile, 'Sheet', 'PTDF_Gen');
    system_data.PTDF.renewablegen = readmatrix(excelFile, 'Sheet', 'PTDF_RenewableGen');
    system_data.PTDF.load = readmatrix(excelFile, 'Sheet', 'PTDF_Load');
    
    %% 加载训练和测试数据
    training_data = load('SPO_training_data.mat');
    test_data = load('SPO_test_data.mat');
end
