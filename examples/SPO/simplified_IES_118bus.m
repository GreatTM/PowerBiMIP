%% -------------------------HELLO-------------------------- %%
% 本函数是通用函数，IES118节点系统，可以自动加载case118_IES的数据并进行计算生成系统参数
% 主程序运行时只需运行此函数即可，无需导入excel表格
%% -------------------------START-------------------------- %%
function system_data = simplified_IES_118bus
    %% --------------------------loading----------------------- %%
    warning off
    if exist('mpc_simplified_IES118bus.mat', 'file')
        disp('simplified IES118bus data found.');
    else
        % 读取 Excel 文件中的数据
        bus = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_bus');
        branch = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_branch');
        gen = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_generator');
        gencost = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_generator_cost');
        chp = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_CHP');
        chpcost = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_CHP_cost');
        chphmax = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_CHP_hmax');
        chphmin = readtable('simplified_IES_118bus_data.xlsx','Sheet','grid_CHP_hmin');
        hload = readtable('simplified_IES_118bus_data.xlsx','Sheet','hload');

        % 表格转数组
        bus = table2array(bus);
        branch = table2array(branch);
        gen = table2array(gen);
        gencost = table2array(gencost);
        chp = table2array(chp);
        chpcost = table2array(chpcost);
        chphmax = table2array(chphmax);
        chphmin = table2array(chphmin);
        hload = table2array(hload);

        % 保存数据为.mat文件
        save('mpc_simplified_IES118bus.mat', "bus","branch","gen","gencost","chp","chpcost","chphmax","chphmin","hload");
        disp('simplified IES118bus data not found, successfully generated.');
    end
    mpc = load('mpc_simplified_IES118bus.mat');
    mpc.baseMVA = 100;

%% 常规机组（与电网数据相同）
    system_data.Sbase = mpc.baseMVA; % 基准功率100MW
    system_data.Nbus = size(mpc.bus,1); % 电网节点数
    system_data.Ngen = sum(mpc.gen(:,24) == 1); % 常规机组数目
    system_data.Nrenewablegen = 9; % 新能源机组数，均为风电
    system_data.Nload = 91; % 负荷数目
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
    system_data.gen_bus = mpc.gen(mpc.gen(:,24) == 1, 1); % 常规机组所在节点编号
    system_data.renewablegen_bus = mpc.gen(mpc.gen(:,24) == 3, 1); % 新能源机组所在节点编号
    system_data.RES_weight = [
        0.1; 0.17; 0.2; 0.1; 0.08; 0.05; 0.1; 0.05; 0.15];
    system_data.cost.c0 = mpc.gencost(mpc.gencost(:,8) == 1,7) / system_data.Sbase; % 机组成本曲线常数项
    system_data.cost.c1 = mpc.gencost(mpc.gencost(:,8) == 1,6); % 机组成本曲线一次项
    system_data.cost.c2 = mpc.gencost(mpc.gencost(:,8) == 1,5); % 机组成本曲线二次项

    system_data.cost.startup = mpc.gencost(mpc.gencost(:,8) == 1,2) / system_data.Sbase; % 机组开机成本
    system_data.cost.shutdown = mpc.gencost(mpc.gencost(:,8) == 1,3) / system_data.Sbase; % 机组停机成本
    system_data.plimit.upper = mpc.gen(mpc.gencost(:,8) == 1,9) / system_data.Sbase; % 机组出力上限
    system_data.plimit.lower = mpc.gen(mpc.gencost(:,8) == 1,10) / system_data.Sbase; % 机组出力下限
    system_data.resplimit.upper = ones(9,1)*200 / system_data.Sbase;
    system_data.ramplimit.up =   0.2 * system_data.plimit.upper; % 常规机组爬坡上限
    system_data.ramplimit.down = 0.2 * system_data.plimit.upper; % 常规机组爬坡下限
    system_data.ramplimit.sup = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组启动最大爬坡
    system_data.ramplimit.sdown = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组关机最大爬坡
    system_data.mintime.on =     3 * ones(49,1); % 最小开启时间
    system_data.mintime.off =    3 * ones(49,1); % 最小停机时间
    system_data.pbranchlimit.upper = [
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000;1000;1000;1000;1000;
        1000;1000;1000;1000;1000;1000
    ] / system_data.Sbase; % 支路潮流上限
    system_data.pbranchlimit.lower = [
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;-1000;
        -1000;-1000;-1000;-1000;-1000;-1000
    ] / system_data.Sbase; % 支路潮流下限
    PTDF = round(makePTDF(mpc), 4); % 计算转移系数（行：to line 列：from bus）
    system_data.PTDF.gen = PTDF(:,system_data.gen_bus); % 机组所在对应的转移系数
    system_data.PTDF.renewablegen = PTDF(:,system_data.renewablegen_bus); % 新能源机组所在节点对应的转移系数
    system_data.PTDF.load = PTDF(:,system_data.load_bus); % 负荷所在节点对应的转移系数
    system_data.cost.compensation_up = system_data.cost.c1*10;
    system_data.cost.compensation_down = system_data.cost.c1*2;

%% CHP机组（多边形约束区域 + 电功率爬坡 + 热功率上下限 + 热功率需求，电热功率成本）
    system_data.Nchp = sum(mpc.gen(:,24) == 2); % CHP机组数目
    system_data.chp_bus = mpc.gen(mpc.gen(:,24) == 2,1); % CHP机组所在节点编号
    % 成本
    system_data.chpcost.c0 = mpc.gencost(mpc.gencost(:,8) == 2,7) / system_data.Sbase; % chp机组电功率常数项成本
    system_data.chpcost.c1 = mpc.gencost(mpc.gencost(:,8) == 2,6); % chp机组电功率一次项成本
    system_data.chpcost.c2 = mpc.gencost(mpc.gencost(:,8) == 2,5); % chp机组电功率二次项成本
    system_data.chpcost.h1 = mpc.chpcost(:,2); % chp机组热功率一次项成本
    system_data.chpcost.h2 = mpc.chpcost(:,3); % chp机组热功率二次项成本
    system_data.chpcost.hp = mpc.chpcost(:,4); % chp机组热功率电功率乘积项成本
    system_data.chpcost.startup = mpc.gencost(mpc.gencost(:,8) == 2,2) / system_data.Sbase; % chp机组的开机成本
    system_data.chpcost.shutdown = mpc.gencost(mpc.gencost(:,8) == 2,3) / system_data.Sbase;% chp机组的停机成本
    % 多边形约束区域
    system_data.chpplimit.p1 = mpc.chp(:,3) / system_data.Sbase; % chp机组出力可行域
    system_data.chpplimit.h1 = mpc.chp(:,4) / system_data.Sbase;
    system_data.chpplimit.p2 = mpc.chp(:,5) / system_data.Sbase;
    system_data.chpplimit.h2 = mpc.chp(:,6) / system_data.Sbase;
    system_data.chpplimit.p3 = mpc.chp(:,7) / system_data.Sbase;
    system_data.chpplimit.h3 = mpc.chp(:,8) / system_data.Sbase;
    system_data.chpplimit.p4 = mpc.chp(:,9) / system_data.Sbase;
    system_data.chpplimit.h4 = mpc.chp(:,10) / system_data.Sbase;
    % 电功率爬坡
    system_data.chpramplimit.up = 0.2 * system_data.chpplimit.p4 / system_data.Sbase; % chp机组爬坡上限
    system_data.chpramplimit.down = 0.2 * system_data.chpplimit.p4 / system_data.Sbase;% chp机组爬坡下限
    system_data.PTDF.chp = PTDF(:,system_data.chp_bus); % chp所在节点对应的转移系数
    % 补偿成本
    system_data.chpcost.compensation_up_p = system_data.chpcost.c1*10;
    system_data.chpcost.compensation_down_p = system_data.chpcost.c1*2;
    system_data.chpcost.compensation_up_h = zeros(system_data.Nchp,1);
    system_data.chpcost.compensation_down_h = zeros(system_data.Nchp,1);
    % 热功率上下限
    system_data.hchplimit.up = mpc.chphmax(:,2:end) / system_data.Sbase;
    system_data.hchplimit.down = mpc.chphmin(:,2:end) / system_data.Sbase;
    % 热功率需求
    system_data.hload = mpc.hload / system_data.Sbase;
end
