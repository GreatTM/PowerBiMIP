function ReadData()
fprintf('%-40s\t\t', '- Reading data');
t0 = clock;
global data;
% % reading data ...
if exist([cd '\mydata.mat'])
    mydata = load('mydata.mat');
    data = mydata.data;
    clear mydata;
else
    FileName = 'testdata_33bus.xlsx';
    [sheet_bus, sheet_branch, sheet_device, sheet_cost, ...
        sheet_pipe, sheet_node, sheet_buildings, sheet_profiles, ...
        sheet_building_tau_act] = ...
        deal(1,2,3,4,5,6,7,8, 9);
    data_bus = xlsread(FileName,sheet_bus,'C3:AZ1000');
    data_branch = xlsread(FileName,sheet_branch,'C3:AZ1000');
    data_device = xlsread(FileName,sheet_device,'C3:AZ1000');
    data_cost = xlsread(FileName,sheet_cost,'C3:AZ1000');
    data_cost = data_cost(~isnan(data_cost(:,1)),:);
    data_pipe = xlsread(FileName,sheet_pipe,'C3:AZ1000');
    data_node = xlsread(FileName,sheet_node,'C3:AZ1000');
    data_buildings = xlsread(FileName,sheet_buildings,'C3:AZ1000');
    data_profiles = xlsread(FileName,sheet_profiles,'C3:AZ1000');
    data_buildings_tau_act = xlsread(FileName,sheet_building_tau_act, 'C3:AZ1000');
    data.grid.bus = data_bus;
    data.grid.branch = data_branch;
    data.grid.price = data_cost(end-1:end,:);
    %     data.grid.baseMVA = 100; % MVA
    data.device.param = data_device;
    data.device.cost = data_cost(1:end-2,:);
    data.heatingnetwork.pipe = data_pipe;
    data.heatingnetwork.node = data_node;
    data.buildings.param = data_buildings;
    data.buildings.Tau_act = data_buildings_tau_act(:,3:end);
    data.profiles.bus = data_profiles(:,1:2);
    data.profiles.basevalue = data_profiles(:,3);
    data.profiles.data = data_profiles(:,4:end);
    data.interval.electricity = 1;
    data.interval.heat = 1;
    data.period = 24;
    
    data.profiles.data = data.profiles.basevalue*ones(1,data.period).* ...
        data.profiles.data;
    save('mydata.mat','data');
end
t1 = clock;
fprintf('%8.2f%s\n', etime(t1,t0), 's');
end