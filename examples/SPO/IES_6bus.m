%% -------------------------HELLO-------------------------- %%
% 本函数是通用函数，IES6节点系统，可以自动加载case6_IES的数据并进行计算生成系统参数
% 主程序运行时只需运行此函数即可，无需导入excel表格
%% -------------------------START-------------------------- %%
function system_data = IES_6bus
    %% --------------------------loading----------------------- %%
    warning off
    if exist('mpc_IES6bus.mat', 'file')
        disp('IES6bus data found.');
    else
        % 读取 Excel 文件中的数据
        bus = readtable('IES_6bus_data.xlsx','Sheet','grid_bus');
        branch = readtable('IES_6bus_data.xlsx','Sheet','grid_branch');
        gen = readtable('IES_6bus_data.xlsx','Sheet','grid_generator');
        gencost = readtable('IES_6bus_data.xlsx','Sheet','grid_generator_cost');
        chp = readtable('IES_6bus_data.xlsx','Sheet','grid_CHP');
        chpcost = readtable('IES_6bus_data.xlsx','Sheet','grid_CHP_cost');
        REGcost = readtable('IES_6bus_data.xlsx','Sheet','redispatch_compensation');
        pipe = readtable('IES_6bus_data.xlsx','Sheet','heatingsys_pipe');
        node = readtable('IES_6bus_data.xlsx','Sheet','heatingsys_node');
        heatload = readtable('IES_6bus_data.xlsx','Sheet','heatingsys_buildings');
%         profiles_train = readtable('IES_6bus_data.xlsx','Sheet','profiles_train');
%         profiles_test = readtable('IES_6bus_data.xlsx','Sheet','profiles_test');
        % 表格转数组
        bus = table2array(bus);
        branch = table2array(branch);
        gen = table2array(gen);
        gencost = table2array(gencost);
        chp = table2array(chp);
        chpcost = table2array(chpcost);
        REGcost = table2array(REGcost);
        pipe = table2array(pipe);
        node = table2array(node);
        heatload = table2array(heatload);
%         profiles_train = table2array(profiles_train);
%         profiles_test = table2array(profiles_test);

        % 保存数据为.mat文件
        save('mpc_IES6bus.mat', "bus","branch","gen","gencost","chp","chpcost","REGcost","pipe","node","heatload");
        disp('IES6bus data not found, successfully generated.');
    end
    mpc = load('mpc_IES6bus.mat');
    mpc.baseMVA = 100;
    %% --------------------------data-------------------------- %%
    %% 电网
    system_data.Sbase = mpc.baseMVA; % 基准功率100MW
    system_data.eps_interval = 1;
    system_data.Nbus = 6; % 电网节点数
    system_data.Ngen = 2; % 常规机组数目
    system_data.Nbranch = 7; % 支路数目
    system_data.Nrenewablegen = 1; % 新能源机组数目
    system_data.Nchp = 1; % CHP机组数目
    system_data.Nload = 3; % 负荷数目
    system_data.Npipe = 5; % 每个热网管道数
    system_data.Nnode = 6; % 每个热网的节点数
    system_data.Nhload = 3; %每个热网的热负荷数
    system_data.load_bus = find(mpc.bus(:,3) ~= 0); % 每个城市所在的母线
    system_data.gen_bus = mpc.gen(mpc.gen(:,24) == 1,1); % 常规机组所在节点编号
    system_data.renewablegen_bus = mpc.gen(mpc.gen(:,24) == 3,1); % 新能源机组所在节点编号
    system_data.chp_bus = mpc.gen(mpc.gen(:,24) == 2,1); % CHP机组所在节点编号
    system_data.cost.c0 = mpc.gencost(mpc.gencost(:,8) == 1,7) / system_data.Sbase; % 常规机组成本曲线常数项
    system_data.cost.c1 = mpc.gencost(mpc.gencost(:,8) == 1,6); % 常规机组成本曲线一次项
    system_data.cost.c2 = mpc.gencost(mpc.gencost(:,8) == 1,5); % 常规机组成本曲线二次项
    system_data.cost.startup = mpc.gencost(mpc.gencost(:,8) == 1,2) / system_data.Sbase; % 常规机组开机成本
    system_data.cost.shutdown = mpc.gencost(mpc.gencost(:,8) == 1,3) / system_data.Sbase; % 常规机组停机成本
    system_data.chpcost.c0 = mpc.gencost(mpc.gencost(:,8) == 2,7) / system_data.Sbase;% chp机组电功率常数项成本
    system_data.chpcost.c1 = mpc.gencost(mpc.gencost(:,8) == 2,6);% chp机组电功率一次项成本
    system_data.chpcost.c2 = mpc.gencost(mpc.gencost(:,8) == 2,5);% chp机组电功率二次项成本
    system_data.chpcost.h1 = mpc.chpcost(:,2);% chp机组热功率一次项成本
    system_data.chpcost.h2 = mpc.chpcost(:,3);% chp机组热功率二次项成本
    system_data.chpcost.hp = mpc.chpcost(:,4);% chp机组热功率电功率乘积项成本
    system_data.chpcost.startup = mpc.gencost(mpc.gencost(:,8) == 2,2) / system_data.Sbase; % chp机组的开机成本
    system_data.chpcost.shutdown = mpc.gencost(mpc.gencost(:,8) == 2,3) / system_data.Sbase;% chp机组的停机成本
    system_data.plimit.upper = mpc.gen(mpc.gen(:,24) == 1,9) / system_data.Sbase; % 常规机组出力上限
    system_data.plimit.lower = mpc.gen(mpc.gen(:,24) == 1,10) / system_data.Sbase; % 常规机组出力下限
    system_data.resplimit.upper = mpc.gen(mpc.gen(:,24) == 3,9) / system_data.Sbase; % 新能源机组出力上限
    system_data.resplimit.lower = mpc.gen(mpc.gen(:,24) == 3,10) / system_data.Sbase; % 新能源机组出力下限
    system_data.chpplimit.p1 = mpc.chp(:,3) / system_data.Sbase; % chp机组出力可行域
    system_data.chpplimit.h1 = mpc.chp(:,4) / system_data.Sbase;
    system_data.chpplimit.p2 = mpc.chp(:,5) / system_data.Sbase;
    system_data.chpplimit.h2 = mpc.chp(:,6) / system_data.Sbase;
    system_data.chpplimit.p3 = mpc.chp(:,7) / system_data.Sbase;
    system_data.chpplimit.h3 = mpc.chp(:,8) / system_data.Sbase;
    system_data.chpplimit.p4 = mpc.chp(:,9) / system_data.Sbase;
    system_data.chpplimit.h4 = mpc.chp(:,10) / system_data.Sbase;
    system_data.ramplimit.up = 2 * mpc.gen(mpc.gen(:,24) == 1,19) / system_data.Sbase; % 常规机组爬坡上限
    system_data.ramplimit.down = 2 * mpc.gen(mpc.gen(:,24) == 1,19) / system_data.Sbase; % 常规机组爬坡下限
    system_data.ramplimit.sup = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组启动最大爬坡
    system_data.ramplimit.sdown = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组关机最大爬坡 
    system_data.chpramplimit.up = 2 * mpc.gen(mpc.gen(:,24) == 2,19) / system_data.Sbase; % chp机组爬坡上限
    system_data.chpramplimit.down = 2 * mpc.gen(mpc.gen(:,24) == 2,19) / system_data.Sbase;% chp机组爬坡下限
    system_data.mintime.off = mpc.gen(mpc.gen(:,24) == 1,22); % 常规机组的最小停机时间
    system_data.mintime.on = mpc.gen(mpc.gen(:,24) == 1,23); % 常规机组的最小开启时间
    system_data.chpmintime.off = mpc.gen(mpc.gen(:,24) == 2,22); % chp机组的最小停机时间
    system_data.chpmintime.on = mpc.gen(mpc.gen(:,24) == 2,23); % chp机组的最小开启时间
    system_data.pbranchlimit.upper = mpc.branch(:,6) / system_data.Sbase; % 支路潮流上限
    system_data.pbranchlimit.lower = -mpc.branch(:,6) / system_data.Sbase; % 支路潮流下限
    PTDF = round(makePTDF(mpc), 4); % 计算转移系数（行：to line 列：from bus）
    system_data.PTDF.gen = PTDF(:,system_data.gen_bus); % 机组所在对应的转移系数
    system_data.PTDF.renewablegen = PTDF(:,system_data.renewablegen_bus); % 新能源机组所在节点对应的转移系数
    system_data.PTDF.chp = PTDF(:,system_data.chp_bus); % chp所在节点对应的转移系数
    system_data.PTDF.load = PTDF(:,system_data.load_bus); % 负荷所在节点对应的转移系数
    
    system_data.cost.compensation_up = system_data.cost.c1*10;
    system_data.cost.compensation_down = system_data.cost.c1/5;
    system_data.chpcost.compensation_up_p = system_data.chpcost.c1*10;
    system_data.chpcost.compensation_down_p = system_data.chpcost.c1/5;
%     system_data.cost.compensation_up = mpc.REGcost(mpc.REGcost(:,3) == 1,1) + system_data.cost.c1; % Remove fuel costs not actually incurred
%     system_data.cost.compensation_down = mpc.REGcost(mpc.REGcost(:,3) == 1,2) - system_data.cost.c1;
%     system_data.chpcost.compensation_up_p = mpc.REGcost(mpc.REGcost(:,3) == 2,1) + system_data.chpcost.c1;
%     system_data.chpcost.compensation_down_p = mpc.REGcost(mpc.REGcost(:,3) == 2,2) - system_data.chpcost.c1;
    system_data.chpcost.compensation_up_h = 0;
    system_data.chpcost.compensation_down_h = 0;
    system_data.load_weight = [0.25;0.3;0.45];
    system_data.RES_weight = 1;
%     system_data.cost.compensation_up =  3 * (2 * system_data.cost.c2 .* system_data.plimit.upper + ...
%         system_data.cost.c1); % 常规机组向上调频成本（最大的边际发电成本2倍）
%     system_data.cost.compensation_down = 0.05 * (2 * system_data.cost.c2 .* system_data.plimit.upper + ...
%         system_data.cost.c1); % 常规机组向下调频成本（最大的边际发电成本的二分之一）
%     system_data.chpcost.compensation_up = 3 * (2 * system_data.chpcost.c2 .* system_data.chpplimit.p4 + ...
%         system_data.chpcost.c1 + system_data.chpcost.hp .* system_data.chpplimit.h3 + ...
%         2 * system_data.chpcost.h2 .* system_data.chpplimit.h3 + system_data.chpcost.h1 + ...
%         system_data.chpcost.hp .* system_data.chpplimit.p4); % chp机组向上调频成本
%     system_data.chpcost.compensation_down = 0.05 * (2 * system_data.chpcost.c2 .* system_data.chpplimit.p4 + ...
%         system_data.chpcost.c1 + system_data.chpcost.hp .* system_data.chpplimit.h3 + ...
%         2 * system_data.chpcost.h2 .* system_data.chpplimit.h3 + system_data.chpcost.h1 + ...
%         system_data.chpcost.hp .* system_data.chpplimit.p4); % chp机组向下调频成本

    %% 热网
    for i = 1:system_data.Nchp
        system_data.source_node_set(:,i) = mpc.node(mpc.node(:,2,i) == 0,1,i);
        system_data.cross_node_set(:,i) = mpc.node(mpc.node(:,2,i) == 1,1,i);
        system_data.load_node_set(:,i) = mpc.node(mpc.node(:,2,i) == 2,1,i);
        system_data.pipe.from_node(:,i) = mpc.pipe(:,1,i);
        system_data.pipe.to_node(:,i) = mpc.pipe(:,2,i);
        system_data.node.Tsmin(:,i)  = mpc.node(:,3,i);
        system_data.node.Tsmax(:,i)  = mpc.node(:,4,i);
        system_data.node.Trmin(:,i)  = mpc.node(:,5,i);
        system_data.node.Trmax(:,i)  = mpc.node(:,6,i);
        system_data.building.Rs(:,i) = mpc.heatload(:,4,i);
        system_data.building.N(:,i) = mpc.heatload(:,5,i);
    end

    system_data.heat_interval = 1;
    rho_w = 1; % 水的密度 t/m^3
    c_w = 4.2; % 水的比热容 kJ/kg度
    Area = mpc.pipe(:,4) .^ 2 * pi / 4; % 管道的面积 m^2
    system_data.massflow = mpc.pipe(:,9); % 质量流量 t/h
    system_data.gamma = ceil(rho_w * Area .* mpc.pipe(:,3) ./...
        system_data.massflow ./ system_data.heat_interval) - 1; % 无单位
    system_data.R = (system_data.gamma + 1) .* system_data.massflow * system_data.heat_interval; % 吨
    system_data.alpha = (system_data.R - rho_w * Area .* mpc.pipe(:,3)) ./ ...
        (system_data.massflow * system_data.heat_interval); % 无单位
    system_data.neta = 1 - exp(-mpc.pipe(:,6) .* ...
        mpc.pipe(:,3) ./ (c_w * 1000 * mpc.pipe(:,9)));
%     system_data.neta = 1 - exp(-(mpc.pipe(:,6) * system_data.heat_interval) ./ ...
%         (rho_w * Area * c_w) .* (system_data.gamma + 1.5 - system_data.alpha) * 0.0036);
    system_data.ratio = exp(-system_data.heat_interval ./ (mpc.heatload(:,4) .* mpc.heatload(:,3))); % 注意，一定要点除
    [Bbus,Bf,~,~] = makeBdc(mpc);
    system_data.Bbus = full(Bbus);
    system_data.Bf = full(Bf);
%     system_data.profiles_train = mpc.profiles_train;
%     system_data.profiles_test = mpc.profiles_test;
    
    system_data.Tau_building_out = [-20.4;-21.5;-22.5;-23.4;-23.9;-24.2;
                      -24.2;-23.5;-22;-20;-18;-16.5;
                      -15.5;-15;-15.3;-16;-16.8;-17.5;
                      -18.2;-18.7;-19.2;-19.6;-19.9;-20]; % 这是一天24小时的数据
    
    % 热网聚合参数计算
    [loc_headnode, loc_tailnode, loc_length, loc_diameter, ...
        loc_conductivity, loc_massflow] = deal(1, 2, 3, 4, 6, 9);
    [loc_node, loc_nodetype] = deal(1,2);
    for k = 1: system_data.Nchp
        data_pipe = mpc.pipe(:,:,k);
        data_node = mpc.node(:,:,k);
        noset_load=data_node(data_node(:,loc_nodetype) == 2,loc_node);     % set of load node
        num_load=length(noset_load);
        % % beta and gamma of each pipeline
        beta_pipe(:,1) = exp(-data_pipe(:,loc_conductivity).* ...
            data_pipe(:,loc_length)./(1000*c_w*data_pipe(:,loc_massflow)));
        gamma_pipe(:,1) = rho_w*Area(:)'.*data_pipe(:,loc_length)'./ ...
            data_pipe(:,loc_massflow)'./system_data.heat_interval;   % h

        % % Link and Delay of load node i
        for i = 1:num_load
            beta_node(i,1) = 1; %#ok<*AGROW>
            gamma_node(i,1) = 0;
            gamma_node_round_1(i,1) = 0;
            current_node = noset_load(i);
            current_pipeline = find(data_pipe(:,loc_tailnode) == current_node);
            current_node_head = data_pipe(current_pipeline,loc_headnode);         % head node
            mass_node(i,1) = data_pipe(current_pipeline,loc_massflow);
            beta_node(i,1) = beta_node(i,1)*beta_pipe(current_pipeline,1);
            gamma_node(i,1) = gamma_node(i,1) + gamma_pipe(current_pipeline,1);
            gamma_node_round_1(i,1) = gamma_node_round_1(i,1) + round(gamma_pipe(current_pipeline,1));
            while data_node(data_node(:,loc_node)==current_node_head,loc_nodetype) ~= 0  % if not source node
                current_node = current_node_head;
                current_pipeline = find(data_pipe(:,loc_tailnode) == current_node);
                current_node_head = data_pipe(current_pipeline,loc_headnode);     % head node
                beta_node(i,1) = beta_node(i,1)*beta_pipe(current_pipeline,1);
                gamma_node(i,1) = gamma_node(i,1) + gamma_pipe(current_pipeline,1);
                gamma_node_round_1(i,1) = gamma_node_round_1(i,1) + round(gamma_pipe(current_pipeline,1));
            end
        end

        system_data.aggregation(k).beta = beta_node;
        system_data.aggregation(k).gamma = ceil(gamma_node) - 1;
        system_data.aggregation(k).gamma_round_1 = gamma_node_round_1;
        system_data.aggregation(k).gamma_round_2 = round(gamma_node);
        system_data.aggregation(k).massflow = mass_node;
        system_data.aggregation(k).nodearray = data_node(data_node(:,2) == 2,1);
        system_data.aggregation(k).kappa = ceil(gamma_node) - gamma_node;
    end

    % 计算建筑物聚合参数
    [loc_no, loc_node, loc_C, loc_R, loc_num] = deal(1,2,3,4,5); %#ok<*ASGLU>
%     num_period_heat = data.period * system_data.electic_interval/system_data.heat_interval;

    % % set outdoor temperature of buildings
%     Tau_out = data.profiles.data(data.profiles.bus(:,2) == 3,:);
%     for i = 1:length(data.buildings)
%         data.buildings(i).Tau_out = Tau_out(i,:)';
%     end
    for k = 1:system_data.Nchp
        data_buildings = mpc.heatload(:,:,k);
        ratio = exp(-system_data.heat_interval./data_buildings(:,loc_R)./data_buildings(:,loc_C));
        a = data_buildings(:,loc_num)./data_buildings(:,loc_R)./(1-ratio);
        b = a.*ratio;
        c = data_buildings(:,loc_num)./data_buildings(:,loc_R);
        system_data.aggregation(k).a = a;
        system_data.aggregation(k).b = b;
        system_data.aggregation(k).c = c;
        system_data.aggregation(k).node = data_buildings(:,loc_node);

%         for i = 1:data.period
%             data.buildings(k).Tau_out_full(num_period_heat/data.period*(i-1)+1:num_period_heat/data.period*i,1) = ...
%                 data.buildings(k).Tau_out(i,1);
%         end
    end
    
    for i = 1:system_data.Nchp
        system_data.heatingsys(i).pipe = mpc.pipe;
        system_data.heatingsys(i).node = mpc.node;
        system_data.heatingsys(i).initial = [80 50 -10];
        
        system_data.buildings(i).param = mpc.heatload;
        system_data.buildings(i).param = floor(0.6*system_data.buildings(i).param(:,end));

        system_data.buildings(i).limit = [16 26 21];
%         system_data.buildings(i).Tau_out = mpc.profiles_train(:,11);
    end
    
end
