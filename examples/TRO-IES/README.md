<script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
<script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
# 算例介绍

## 算例背景

针对综合能源系统（Integrated Energy System, IES）在电负荷与室外温度双重不确定性下的优化调度问题，本算例展示了一种日前两阶段自适应鲁棒调度模型。在传统的确定性优化中，预测误差会导致实际运行偏离最优状态，甚至引发系统安全问题；而传统的鲁棒优化方法虽然能保证系统在最恶劣场景下的可行性，但往往过于保守。两阶段自适应鲁棒优化通过将决策分为"这里和现在"（Here-and-Now）的一阶段决策和"等待和观察"（Wait-and-See）的二阶段决策，在保障系统安全运行及用户热舒适度的同时，有效降低了结果的保守性。该问题通常采用列与约束生成（Column-and-Constraint Generation, C&CG）算法求解，其核心的子问题（Subproblem）用于寻找最恶劣的运行场景。由于子问题中不确定集内包含二进制变量（用于刻画多区间不确定集），而下层再调度问题为连续变量的线性规划，因此该子问题本质上是一个双层混合整数规划（Bi-level Mixed-Integer Program, BiMIP）问题，适合调用 PowerBiMIP 求解器进行求解。

## 算例数学模型

### 两阶段鲁棒优化模型

本算例的数学模型构建为如下的两阶段鲁棒优化形式：

$$
\begin{align}
& \min_{\boldsymbol{y}} \boldsymbol{c}_{1}^{\top} \boldsymbol{y} + \max_{\boldsymbol{u} \in \mathcal{U}} \min_{\boldsymbol{x} \in \Omega(\boldsymbol{y}, \boldsymbol{u})} \boldsymbol{c}_{2}^{\top} \boldsymbol{x} \\
& \text{s.t.} \quad \boldsymbol{A} \boldsymbol{y} \le \boldsymbol{d} \\
& \quad \quad \quad \boldsymbol{x} \in \Omega(\boldsymbol{y}, \boldsymbol{u}) = \{ \boldsymbol{x} \mid \boldsymbol{E} \boldsymbol{x} + \boldsymbol{G} \boldsymbol{y} + \boldsymbol{F} \boldsymbol{u} \ge \boldsymbol{h} \}
\end{align}
$$

其中，不确定集 $\mathcal{U}$ 采用预算不确定集（Budget Uncertainty Set）的形式：

$$
\mathcal{U} = \left\{ \boldsymbol{u} \left| \begin{matrix} \boldsymbol{u} = \bar{\boldsymbol{u}} \odot (1 + \Delta \boldsymbol{u}^{+} - \Delta \boldsymbol{u}^{-}) \\ 0 \le \boldsymbol{u}^{+}, \boldsymbol{u}^{-} \le 1 \\ \sum \boldsymbol{u}^{+} = \sum \boldsymbol{u}^{-}, \quad \sum (\boldsymbol{u}^{+} + \boldsymbol{u}^{-}) \le \Gamma \end{matrix} \right. \right\}
$$

其中，一阶段决策变量 $\boldsymbol{y}$ 为二进制变量，表示储能设备的充放电状态、储热罐的充放热状态等"这里和现在"的决策；二阶段决策变量 $\boldsymbol{x}$ 为各设备的出力（如燃气轮机电功率与热功率、电锅炉功率）、储能充放电功率、储热罐充放热功率、配电网潮流（节点电压、支路功率、PCC交互功率）、热网状态（节点供回水温度、管道进出口温度、热源与热负荷功率）、建筑室内温度及切负荷量等连续变量，代表适应不确定性实现的"等待和观察"决策；$\boldsymbol{u}$ 代表可再生能源出力、电负荷、室外温度及建筑温度修正项等不确定参数。

式(1)为模型的总体目标函数，其中 $\boldsymbol{c}_{1}$ 代表一阶段成本系数，$\boldsymbol{c}_{2}$ 代表燃料成本、电网交互成本、运维成本及越限惩罚成本系数，第二项 Max-Min 结构即为寻找不确定集 $\mathcal{U}$ 下的最恶劣场景及对应的最优再调度成本。约束(2)为一阶段约束，其中 $\boldsymbol{A}, \boldsymbol{d}$ 分别代表设备状态互斥约束（如储能不可同时充放电、储热罐不可同时充放热）、充放功率上下限约束、荷电/蓄热状态上下限约束、初始与终端状态约束以及状态动态方程的系数矩阵和常数向量。约束(3)为二阶段耦合约束，涵盖了配电网DistFlow潮流约束（节点有功/无功平衡、电压方程、电压上下限）、设备与节点关联约束、PCC功率限制、可再生能源出力约束、储能/储热罐功率耦合约束（与一阶段决策耦合）、燃气轮机出力及热电耦合约束、电锅炉功率及热电转换约束、热网温度准动态约束（供回水温度传输方程、热源/交叉/负荷节点温度与功率平衡）、节点温度上下限约束、建筑室内温度动态方程、室内温度上下限约束、终端与平均温度约束、电热系统耦合约束（热源功率平衡、热负荷功率平衡）以及不确定参数与决策变量的关联约束。

### C&CG算法求解框架

两阶段鲁棒优化问题通常采用C&CG算法进行求解，该算法将原问题分解为主问题（Master Problem）和子问题（Subproblem）交替迭代求解。

**主问题（Master Problem）**：

$$
\begin{align}
& \min_{\boldsymbol{y}, \eta, \{\boldsymbol{x}^{(k)}\}} \boldsymbol{c}_{1}^{\top} \boldsymbol{y} + \eta \\
& \text{s.t.} \quad \boldsymbol{A} \boldsymbol{y} \le \boldsymbol{d} \\
& \quad \quad \quad \eta \ge \boldsymbol{c}_{2}^{\top} \boldsymbol{x}^{(k)}, \quad \forall k = 1, \ldots, K \\
& \quad \quad \quad \boldsymbol{x}^{(k)} \in \Omega(\boldsymbol{y}, \boldsymbol{u}^{(k)}), \quad \forall k = 1, \ldots, K
\end{align}
$$

主问题在每次迭代中根据子问题返回的最恶劣场景 $\boldsymbol{u}^{(k)}$ 添加新的约束和变量，逐步逼近最优解。其中 $\eta$ 为二阶段成本的下界估计，$K$ 为当前迭代次数。

**子问题（Subproblem）**：

$$
\begin{align}
& \max_{\boldsymbol{u} \in \mathcal{U}} \min_{\boldsymbol{x} \in \Omega(\boldsymbol{y}^*, \boldsymbol{u})} \boldsymbol{c}_{2}^{\top} \boldsymbol{x}
\end{align}
$$

子问题在给定主问题求得的一阶段决策 $\boldsymbol{y}^*$ 后，在不确定集 $\mathcal{U}$ 中寻找使二阶段成本最大的最恶劣场景。由于不确定集中包含二进制变量（如多区间不确定集中的区间指示变量），而下层再调度问题为连续变量的线性规划，因此**子问题本质上是一个双层混合整数规划（BiMIP）问题，可以调用PowerBiMIP求解器进行求解**。

**算法流程**：C&CG算法的基本流程为：(1) 初始化，设置迭代计数 $k=0$，上界 $UB=+\infty$，下界 $LB=-\infty$；(2) 求解主问题，得到一阶段决策 $\boldsymbol{y}^*$ 和下界估计，更新 $LB$；(3) 固定 $\boldsymbol{y}^*$，求解子问题得到最恶劣场景 $\boldsymbol{u}^{(k+1)}$ 和对应的二阶段成本，更新 $UB$；(4) 若 $UB - LB \le \epsilon$（收敛容差），则算法终止；否则将新场景添加到主问题中，$k \leftarrow k+1$，返回步骤(2)继续迭代。

需要注意的是，本算例展示的模型为紧凑形式，详细模型构建与参数说明请参阅文献：Lu S, Gu W, Zhou S, et al. Adaptive Robust Dispatch of Integrated Energy System Considering Uncertainties of Electricity and Outdoor Temperature [J]. IEEE Transactions on Industrial Informatics, 2020, 16(7): 4691-702.

