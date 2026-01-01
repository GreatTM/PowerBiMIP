%% -------------------------HELLO-------------------------- %%
% 本函数是通用函数，改编的ieee9节点系统，可根据标准算例文件case9生成系统参数
% 主程序运行时只需运行此函数即可，无需导入excel表格
%% -------------------------START-------------------------- %%
function system_data = case9_modified
    %% --------------------------loading----------------------- %%
%     mpc = case9; % 载入ieee9节点标准算例系统
%     %% --------------------------data-------------------------- %%
%     system_data.Sbase = mpc.baseMVA; % 基准功率100MW
%     system_data.Nbus = 9;
%     system_data.Ngen = 3;
%     system_data.Nrenewablegen = 1;
%     system_data.Nload = 3; 
%     % 每个城市所占的负荷比例
%     system_data.load_weight = [0.25;  0.3;  0.45];
%     % 每个城市所在的母线
%     system_data.load_bus =    [5;     7;    9];
%     system_data.gen_bus = mpc.gen(:,1); % 机组所在节点编号
%     system_data.renewablegen_bus = 1; % 新能源机组所在节点编号
%     system_data.RES_weight = 1;
% 
%     system_data.cost.c0 = mpc.gencost(:,7) / system_data.Sbase; % 机组成本曲线常数项
%     system_data.cost.c1 = mpc.gencost(:,6); % 机组成本曲线一次项
%     system_data.cost.c2 = mpc.gencost(:,5); % 机组成本曲线二次项
%     system_data.cost.startup = mpc.gencost(:,2) / system_data.Sbase; % 机组开机成本
%     system_data.cost.shutdown = mpc.gencost(:,3) / system_data.Sbase; % 机组停机成本
%     system_data.plimit.upper = mpc.gen(:,9) / system_data.Sbase; % 机组出力上限
%     system_data.plimit.lower = mpc.gen(:,10) / system_data.Sbase; % 机组出力下限
%     system_data.resplimit.upper = 200 / system_data.Sbase;
%     system_data.ramplimit.up =   [80;  95;  86] / system_data.Sbase; % 机组爬坡上限
%     system_data.ramplimit.down = [80;  95;  86] / system_data.Sbase; % 机组爬坡下限
%     system_data.ramplimit.sup = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组启动最大爬坡
%     system_data.ramplimit.sdown = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组关机最大爬坡 
% 
%     system_data.mintime.on =     [2;   2;   2]; % 最小开启时间
%     system_data.mintime.off =    [2;   2;   2]; % 最小停机时间
%     system_data.pbranchlimit.upper = [1000;   1000;   1000;   1000;  1000;...
%                                       1000;   1000;   1000;   1000] / system_data.Sbase; % 支路潮流上限
%     system_data.pbranchlimit.lower = [-1000;  -1000;  -1000;  -1000; -1000;...
%                                       -1000;  -1000;  -1000;  -1000] / system_data.Sbase; % 支路潮流下限
%     PTDF = round(makePTDF(mpc), 4); % 计算转移系数（行：to line 列：from bus）
%     system_data.PTDF.gen = PTDF(:,system_data.gen_bus); % 机组所在对应的转移系数
%     system_data.PTDF.renewablegen = PTDF(:,system_data.renewablegen_bus); % 新能源机组所在节点对应的转移系数
%     system_data.PTDF.load = PTDF(:,system_data.load_bus); % 负荷所在节点对应的转移系数
%     system_data.cost.compensation_up =   system_data.cost.c1*10; % 向上调频成本
%     system_data.cost.compensation_down = system_data.cost.c1*2; % 向下调频成本

mpc = case9; % 载入ieee9节点标准算例系统
    %% --------------------------data-------------------------- %%
    system_data.Sbase = mpc.baseMVA; % 基准功率100MW
    system_data.Nbus = 9;
    system_data.Ngen = 3;
    system_data.Nrenewablegen = 1;
    system_data.Nload = 3; 
    % 每个城市所占的负荷比例
    system_data.load_weight = [0.25;  0.3;  0.45];
    % 每个城市所在的母线
    system_data.load_bus =    [5;     7;    9];
    system_data.gen_bus = mpc.gen(:,1); % 机组所在节点编号
    system_data.renewablegen_bus = 1; % 新能源机组所在节点编号
    system_data.RES_weight = 1;

    system_data.cost.c0 = mpc.gencost(:,7) / system_data.Sbase; % 机组成本曲线常数项
    system_data.cost.c1 = mpc.gencost(:,6); % 机组成本曲线一次项
    system_data.cost.c2 = mpc.gencost(:,5); % 机组成本曲线二次项
    system_data.cost.startup = mpc.gencost(:,2) / system_data.Sbase; % 机组开机成本
    system_data.cost.shutdown = mpc.gencost(:,3) / system_data.Sbase; % 机组停机成本
    system_data.plimit.upper = mpc.gen(:,9) / system_data.Sbase; % 机组出力上限
    system_data.plimit.lower = mpc.gen(:,10) / system_data.Sbase; % 机组出力下限
    system_data.resplimit.upper = 200 / system_data.Sbase;
    system_data.ramplimit.up =   [80;  95;  86] / system_data.Sbase; % 机组爬坡上限
    system_data.ramplimit.down = [80;  95;  86] / system_data.Sbase; % 机组爬坡下限
    system_data.ramplimit.sup = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组启动最大爬坡
    system_data.ramplimit.sdown = 0.5 * (system_data.plimit.upper + system_data.plimit.lower); % 常规机组关机最大爬坡 

    system_data.mintime.on =     [2;   2;   2;2;2]; % 最小开启时间
    system_data.mintime.off =    [2;   2;   2;2;2]; % 最小停机时间
    system_data.pbranchlimit.upper = [1000;   1000;   1000;   1000;  1000;...
                                      1000;   1000;   1000;   1000] / system_data.Sbase; % 支路潮流上限
    system_data.pbranchlimit.lower = [-1000;  -1000;  -1000;  -1000; -1000;...
                                      -1000;  -1000;  -1000;  -1000] / system_data.Sbase; % 支路潮流下限
    PTDF = round(makePTDF(mpc), 4); % 计算转移系数（行：to line 列：from bus）
    system_data.PTDF.gen = PTDF(:,system_data.gen_bus); % 机组所在对应的转移系数
    system_data.PTDF.renewablegen = PTDF(:,system_data.renewablegen_bus); % 新能源机组所在节点对应的转移系数
    system_data.PTDF.load = PTDF(:,system_data.load_bus); % 负荷所在节点对应的转移系数
    system_data.cost.compensation_up =   system_data.cost.c1*10; % 向上调频成本
    system_data.cost.compensation_down = system_data.cost.c1*0.2; % 向下调频成本

end