%% -------------------------HELLO-------------------------- %%
% 本函数是通用函数，IES118节点系统，可以自动加载case118_IES的数据并进行计算生成系统参数
% 主程序运行时只需运行此函数即可，无需导入excel表格
%% -------------------------START-------------------------- %%
function system_data = IES_118bus
    %% --------------------------loading----------------------- %%
    warning off
    if exist('mpc_IES118bus.mat', 'file')
        disp('IES118bus data found.');
    else
        % 读取 Excel 文件中的数据
        bus = readtable('IES_118bus_data.xlsx','Sheet','grid_bus');
        branch = readtable('IES_118bus_data.xlsx','Sheet','grid_branch');
        gen = readtable('IES_118bus_data.xlsx','Sheet','grid_generator');
        gencost = readtable('IES_118bus_data.xlsx','Sheet','grid_generator_cost');
        chp = readtable('IES_118bus_data.xlsx','Sheet','grid_CHP');
        chpcost = readtable('IES_118bus_data.xlsx','Sheet','grid_CHP_cost');
        pipe = readtable('IES_118bus_data.xlsx','Sheet','heatingsys_pipe');
        node = readtable('IES_118bus_data.xlsx','Sheet','heatingsys_node');
        heatload = readtable('IES_118bus_data.xlsx','Sheet','heatingsys_buildings');
        REGcost = readtable('IES_118bus_data.xlsx','Sheet','redispatch_compensation');

        % 表格转数组
        bus = table2array(bus);
        branch = table2array(branch);
        gen = table2array(gen);
        gencost = table2array(gencost);
        chp = table2array(chp);
        chpcost = table2array(chpcost);
        pipe = table2array(pipe);
        node = table2array(node);
        heatload = table2array(heatload);
        REGcost = table2array(REGcost);

        % 保存数据为.mat文件
        save('mpc_IES118bus.mat', "bus","branch","gen","gencost","chp","chpcost","pipe","node","heatload","REGcost");
        disp('IES118bus data not found, successfully generated.');
    end
    mpc = load('mpc_IES118bus.mat');
    mpc.baseMVA = 100;
    %% 热网数据转化为张量
    temp_pipe = mpc.pipe;
    temp_node = mpc.node;
    temp_heatload = mpc.heatload;
    mpc.pipe = zeros(50,11,10);
    mpc.node = zeros(51,9,10);
    mpc.heatload = zeros(26,5,10);
    for i = 1:10
        mpc.pipe(:,:,i) = temp_pipe(2 + 53*(i-1) : 51 + 53*(i-1), 2:end);
        mpc.node(:,:,i) = temp_node(2 + 54*(i-1) : 52 + 54*(i-1), 2:end);
        mpc.heatload(:,:,i) = temp_heatload(2 + 29*(i-1) : 27 + 29*(i-1), 2:end);
    end
    %% --------------------------data-------------------------- %%
    customize_Nchp = 10; % 自定义chp机组台数
    mpc.chp = mpc.chp(1:customize_Nchp, :);

    %% 电网
    system_data.Sbase = mpc.baseMVA; % 基准功率100MW
    system_data.eps_interval = 1;
    system_data.Nbus = size(mpc.bus, 1); % 电网节点数
    system_data.Ngen = sum(mpc.gen(:,24) == 1); % 常规机组数目
    system_data.Nbranch = size(mpc.branch, 1); % 支路数目
    system_data.Nrenewablegen = sum(mpc.gen(:,24) == 3); % 新能源机组数目
%     system_data.Nchp = sum(mpc.gen(:,24) == 2); % CHP机组数目
% %
    system_data.Nchp = customize_Nchp;

    system_data.Nload = 91; % 负荷数目
    system_data.Npipe = 50; % 每个热网管道数
    system_data.Nnode = 51; % 每个热网的节点数
    system_data.Nhload = 26; %每个热网的热负荷数

    system_data.load_bus = [
        1;2;3;4;6;7;11;12;13;14;
        15;16;17;18;19;20;21;22;23;27;
        28;29;31;32;33;34;35;36;39;40;
        41;42;43;44;45;46;47;48;49;50;
        51;52;53;54;55;56;57;58;59;60;
        62;66;67;70;74;75;76;77;78;79;
        80;82;83;84;85;86;88;90;92;93;
        94;95;96;97;98;100;101;102;103;
        104;105;106;107;108;109;110;112;
        114;115;117;118
    ]; % 每个城市所在的母线
    system_data.gen_bus = mpc.gen(mpc.gen(:,24) == 1,1); % 常规机组所在节点编号
    system_data.renewablegen_bus = mpc.gen(mpc.gen(:,24) == 3,1); % 新能源机组所在节点编号
    system_data.chp_bus = mpc.gen(mpc.gen(:,24) == 2,1); % CHP机组所在节点编号
    % %
    system_data.chp_bus = system_data.chp_bus(1:system_data.Nchp,1);

    system_data.cost.c0 = mpc.gencost(mpc.gencost(:,8) == 1,7) / system_data.Sbase; % 常规机组成本曲线常数项
    system_data.cost.c1 = mpc.gencost(mpc.gencost(:,8) == 1,6); % 常规机组成本曲线一次项
    system_data.cost.c2 = mpc.gencost(mpc.gencost(:,8) == 1,5); % 常规机组成本曲线二次项
    system_data.cost.startup = mpc.gencost(mpc.gencost(:,8) == 1,2) / system_data.Sbase; % 常规机组开机成本
    system_data.cost.shutdown = mpc.gencost(mpc.gencost(:,8) == 1,3) / system_data.Sbase; % 常规机组停机成本
    
    system_data.chpcost.c0 = mpc.gencost(mpc.gencost(:,8) == 2,7) / system_data.Sbase;% chp机组电功率常数项成本
    % %
    system_data.chpcost.c0 = system_data.chpcost.c0(1:system_data.Nchp,1);

    system_data.chpcost.c1 = mpc.gencost(mpc.gencost(:,8) == 2,6);% chp机组电功率一次项成本
    % %
    system_data.chpcost.c1 = system_data.chpcost.c1(1:system_data.Nchp,1);
    
    system_data.chpcost.c2 = mpc.gencost(mpc.gencost(:,8) == 2,5);% chp机组电功率二次项成本
    % %
    system_data.chpcost.c2 = system_data.chpcost.c2(1:system_data.Nchp,1);
    
    system_data.chpcost.h1 = mpc.chpcost(:,2);% chp机组热功率一次项成本
    % %
    system_data.chpcost.h1 = system_data.chpcost.h1(1:system_data.Nchp,1);
    
    system_data.chpcost.h2 = mpc.chpcost(:,3);% chp机组热功率二次项成本
    % %
    system_data.chpcost.h2 = system_data.chpcost.h2(1:system_data.Nchp,1);
    
    system_data.chpcost.hp = mpc.chpcost(:,4);% chp机组热功率电功率乘积项成本
    % %
    system_data.chpcost.hp = system_data.chpcost.hp(1:system_data.Nchp,1);

    system_data.chpcost.startup = mpc.gencost(mpc.gencost(:,8) == 2,2) / system_data.Sbase; % chp机组的开机成本
    % %
    system_data.chpcost.startup = system_data.chpcost.startup(1:system_data.Nchp,1);
    
    system_data.chpcost.shutdown = mpc.gencost(mpc.gencost(:,8) == 2,3) / system_data.Sbase;% chp机组的停机成本
    % %
    system_data.chpcost.shutdown = system_data.chpcost.shutdown(1:system_data.Nchp,1);

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

    system_data.ramplimit.up =   2 * mpc.gen(mpc.gen(:,24) == 1,19) / system_data.Sbase; % 常规机组爬坡上限
    system_data.ramplimit.down = 2 * mpc.gen(mpc.gen(:,24) == 1,19) / system_data.Sbase; % 常规机组爬坡下限
    system_data.ramplimit.sup = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组启动最大爬坡
    system_data.ramplimit.sdown = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组关机最大爬坡    

    system_data.chpramplimit.up = 2 * mpc.gen(mpc.gen(:,24) == 3,19) / system_data.Sbase; % chp机组爬坡上限
    % %
    system_data.chpramplimit.up = system_data.chpramplimit.up(1:system_data.Nchp,1);

    system_data.chpramplimit.down = 2 * mpc.gen(mpc.gen(:,24) == 3,19) / system_data.Sbase;% chp机组爬坡下限
    % %
    system_data.chpramplimit.down = system_data.chpramplimit.down(1:system_data.Nchp,1);

    system_data.mintime.off = mpc.gen(mpc.gen(:,24) == 1,22); % 常规机组的最小停机时间
    system_data.mintime.on = mpc.gen(mpc.gen(:,24) == 1,23); % 常规机组的最小开启时间
    system_data.chpmintime.off = mpc.gen(mpc.gen(:,24) == 2,22); % chp机组的最小停机时间
    % %
    system_data.chpmintime.off = system_data.chpmintime.off(1:system_data.Nchp,1);
    
    system_data.chpmintime.on = mpc.gen(mpc.gen(:,24) == 2,23); % chp机组的最小开启时间
    % %
    system_data.chpmintime.on = system_data.chpmintime.on(1:system_data.Nchp,1);

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
    system_data.chpcost.compensation_up_h = zeros(system_data.Nchp,1);
    system_data.chpcost.compensation_down_h = zeros(system_data.Nchp,1);

    system_data.load_weight = [
        0.011127415;0.009125331;0.009942421;0.012164776;0.011082586;
        0.009581312;0.01153976;0.009838587;0.010899123;0.00853348;
        0.013127886;0.011255913;0.012290697;0.012258637;0.010452759;
        0.010792529;0.011090855;0.011899053;0.010567023;0.011048739;
        0.010763991;0.013458927;0.011565582;0.010890186;0.00912895;
        0.009173968;0.01003117;0.008360027;0.010085097;0.009251321;
        0.012717277;0.013018267;0.011766943;0.013041022;0.008349365;
        0.01288359;0.011319944;0.010955853;0.010720225;0.009559404;
        0.010327043;0.012107224;0.00908951;0.013007931;0.008583716;
        0.012724369;0.010751695;0.009179088;0.009870722;0.011324968;
        0.010649926;0.010558826;0.010543054;0.012030236;0.009327605;
        0.011548806;0.009849705;0.010901999;0.008271711;0.013949281;
        0.009488789;0.011783187;0.01017492;0.014137625;0.011022752;
        0.010351864;0.011615373;0.013490469;0.008587458;0.012605937;
        0.010388386;0.012180585;0.009605362;0.010947958;0.010721342;
        0.011602739;0.013955942;0.013569704;0.012922269;0.008281373;
        0.011547969;0.010840894;0.012903583;0.011655824;0.010601577;
        0.009669706;0.011473522;0.011556005;0.011282066;0.010470585;
        0.010307275
    ]; % 每个城市所占的负荷比例

    system_data.RES_weight = [
        0.1; 0.1; 0.1; 0.1; 0.1;
        0.1; 0.1; 0.1; 0.1; 0.1
    ]; % 每个风电场权重

    %% 热网
    for i = 1:system_data.Nchp
        system_data.source_node_set(:,i) = mpc.node(mpc.node(:,2,i) == 0,1,i) + 1; %由于mpc数据中节点编号是从0开始的，因此要加1
        system_data.cross_node_set(:,i) = mpc.node(mpc.node(:,2,i) == 1,1,i) + 1; %由于mpc数据中节点编号是从0开始的，因此要加1
        system_data.load_node_set(:,i) = mpc.node(mpc.node(:,2,i) == 2,1,i) + 1; %由于mpc数据中节点编号是从0开始的，因此要加1
        system_data.pipe.from_node(:,i) = mpc.pipe(:,1,i) + 1;
        system_data.pipe.to_node(:,i) = mpc.pipe(:,2,i) + 1;
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
    Area = zeros(size(mpc.pipe,1),size(mpc.pipe,3));
    for i = 1:size(mpc.pipe,3)
        Area(:,i) = mpc.pipe(:,4,i) .^ 2 * pi / 4; % 管道的面积 m^2
        system_data.massflow(:,i) = mpc.pipe(:,9,i); % 质量流量 t/h
        system_data.gamma(:,i) = ceil(rho_w * Area(:,i) .* mpc.pipe(:,3,i) ./...
            system_data.massflow(:,i) ./ system_data.heat_interval) - 1; % 无单位
        system_data.R(:,i) = (system_data.gamma(:,i) + 1) .* system_data.massflow(:,i) * system_data.heat_interval; % 吨
        system_data.alpha(:,i) = (system_data.R(:,i) - rho_w * Area(:,i) .* mpc.pipe(:,3,i)) ./ ...
            (system_data.massflow(:,i) * system_data.heat_interval); % 无单位
        system_data.neta(:,i) = 1 - exp(-(mpc.pipe(:,6,i) * system_data.heat_interval) ./ ...
            (rho_w * Area(:,i) * c_w) .* (system_data.gamma(:,i) + 1.5 - system_data.alpha(:,i)) * 0.0036);
        system_data.ratio(:,i) = exp(-system_data.heat_interval ./ (mpc.heatload(:,4,i) .* mpc.heatload(:,3,i))); % 注意，一定要点除
    end

    system_data.Tau_building_out = [-21.5,  -21.7,  -23.1,  -25.7,  -25.9,  -25.2,  -24.7,  -23.8,  -23.7,  -21.4,  -18.1,  -17.5,  -16.1,  -16.0,  -16.5,  -17.0,  -17.9,  -18.2,  -19.6,  -19.4,  -20.7,  -21.2,  -20.7,  -21.2; 
                           -22.4,  -22.9,  -22.6,  -25.0,  -24.1,  -26.0,  -25.5,  -23.6,  -23.3,  -21.4,  -18.7,  -17.5,  -15.9,  -15.1,  -16.2,  -16.8,  -18.3,  -18.9,  -19.8,  -20.0,  -20.1,  -21.4,  -21.6,  -21.2; 
                           -20.8,  -23.0,  -23.1,  -25.6,  -26.1,  -25.5,  -26.0,  -24.6,  -23.7,  -21.2,  -18.0,  -16.9,  -15.8,  -15.5,  -16.5,  -16.7,  -17.9,  -18.0,  -18.4,  -19.2,  -21.0,  -19.7,  -20.7,  -20.4; 
                           -21.4,  -21.9,  -22.5,  -23.9,  -26.1,  -26.4,  -24.9,  -25.2,  -23.1,  -20.7,  -18.3,  -17.6,  -17.0,  -15.3,  -16.4,  -16.7,  -17.6,  -17.9,  -18.7,  -19.7,  -20.2,  -20.6,  -21.4,  -20.4; 
                           -21.0,  -23.2,  -24.1,  -23.8,  -26.1,  -24.2,  -24.3,  -24.8,  -22.8,  -21.6,  -18.5,  -17.8,  -15.8,  -16.2,  -15.4,  -16.7,  -16.8,  -17.7,  -19.2,  -20.3,  -20.1,  -19.9,  -21.1,  -20.4; 
                           -20.6,  -22.5,  -23.8,  -25.7,  -24.1,  -25.6,  -25.2,  -23.5,  -23.0,  -20.6,  -19.2,  -17.9,  -16.2,  -15.6,  -15.5,  -17.2,  -17.5,  -18.5,  -18.6,  -19.3,  -20.1,  -19.7,  -21.1,  -21.4; 
                           -21.8,  -23.3,  -24.7,  -25.5,  -25.3,  -25.8,  -25.6,  -24.0,  -23.1,  -20.2,  -18.3,  -16.9,  -16.0,  -15.4,  -15.4,  -16.7,  -17.5,  -17.7,  -19.6,  -18.9,  -20.2,  -19.7,  -21.7,  -21.6; 
                           -21.7,  -22.8,  -23.7,  -24.2,  -25.1,  -24.8,  -25.7,  -23.6,  -24.2,  -20.5,  -18.3,  -18.1,  -16.3,  -16.3,  -16.2,  -16.9,  -17.6,  -17.5,  -19.8,  -20.3,  -19.6,  -20.2,  -21.5,  -21.3; 
                           -21.3,  -21.7,  -22.5,  -24.7,  -25.5,  -24.8,  -24.7,  -24.2,  -22.9,  -20.8,  -19.6,  -17.1,  -17.0,  -15.5,  -15.5,  -16.4,  -17.5,  -18.4,  -18.3,  -18.9,  -19.8,  -21.5,  -20.8,  -20.1; 
                           -21.2,  -22.9,  -23.1,  -24.3,  -25.2,  -24.7,  -24.8,  -25.6,  -23.7,  -20.3,  -18.2,  -17.4,  -17.0,  -15.2,  -16.6,  -16.0,  -17.6,  -19.0,  -19.9,  -19.6,  -20.9,  -21.2,  -20.8,  -20.4]';
    for i = 1:system_data.Nchp
        system_data.heatingsys(i).pipe = mpc.pipe(:,:,i);
        system_data.heatingsys(i).node = mpc.node(:,:,i);
        system_data.heatingsys(i).initial = [80 50 -10];
        system_data.buildings(i).param = mpc.heatload(:,:,i);
        system_data.buildings(i).limit = [21 21 21];

        % **
        system_data.buildings(i).param(:,end) = floor(0.6*system_data.buildings(i).param(:,end));

    end
end
