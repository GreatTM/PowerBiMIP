# 算例：电力系统闭环“预测-决策”问题

## 算例背景

在传统的"先预测-后决策"模式下，预测模型通常以最小化预测误差（如均方误差MSE）为目标，忽略了下游优化环节中预测误差对运行成本的非对称影响（例如，预测值偏低导致的向上调频成本远高于预测值偏高导致的向下调频成本），从而导致最终的机组组合决策在经济性上并非最优。针对电力系统机组组合问题中传统"先预测-后决策"框架存在的局限性，闭环"预测-优化"的机组组合决策方法旨在将决策过程的信息融入预测训练环节，从而使得预测环节能够考虑预测误差对优化决策模型目标函数的非对称、非线性影响。文献[1]将该闭环"预测-优化"模型建立为一个双层混合整数规划（BiMIP）模型：上层问题通过调整预测模型参数，最小化包含日前调度成本和日内再调度成本在内的系统实际总运行成本；下层问题则是基于预测信息的日前机组组合优化。**该模型是标准BiMIP问题，可以直接调用PowerBiMIP求解器求解**。

## 算例数学模型

本算例的数学模型构建为如下的双层规划形式：

$$
\begin{align}
& \min_{\theta, \{x_{i}^*, z_{i}^*, y_{i}\}_{i \in I}} \sum_{i \in I} \left( c_4^{\top} x_{i}^* + c_2^{\top} z_{i}^* + c_3^{\top} y_{i} \right) + \lambda \|\theta\| \\
& \text{s.t.} \quad y_{i} \in \Phi_2(x_{i}^*, z_{i}^*, \tilde{w}_i), \quad \forall i \in I \\
& \quad \quad \quad (x_{i}^*, z_{i}^*) \in \mathop{\arg\min}_{x,z} \left\{ c_1^{\top} x + c_2^{\top} z \mid (x, z) \in \Phi_1(\hat{w}_{\theta}(u_i)) \right\}, \quad \forall i \in I
\end{align}
$$

其中，下层可行域的具体形式定义为：

$$
\Phi_1(\hat{w}_{\theta}) = \left\{ (x,z) \left| \begin{matrix} Px + Sz \le d(\hat{w}_{\theta}) \\ Dx + Ez = h(\hat{w}_{\theta}) \\ x \in \mathbb{R}^{N_x}, z \in \{0,1\}^{N_z} \end{matrix} \right. \right\}
$$

$$
\Phi_2(x^*, z^*, \tilde{w}) = \left\{ y \left| \begin{matrix} Ay \le b(\tilde{w}) + Rx^* + Kz^* \\ Gy = g(\tilde{w}) + Ux^* + Qz^* \\ y \in \mathbb{R}^{N_y} \end{matrix} \right. \right\}
$$

其中，上层决策变量 $\theta$ 为预测模型的参数向量；$y$ 为机组实时上/下调出力、再调度阶段的切负荷量及弃风量等连续变量；下层决策变量 $x$ 为机组日前出力、备用容量、弃风量及切负荷量等连续变量，$z$ 为二进制变量，代表机组日前启停状态、启动及停机动作。

式(1)为上层目标函数，旨在最小化整个训练集上的"实际运行总成本"与正则化项之和，其中实际运行成本包括日前调度阶段确定的燃料成本 $c_4^{\top} x_{i}^*$、启停成本 $c_2^{\top} z_{i}^*$，以及再调度阶段的调整成本 $c_3^{\top} y_{i}$（含燃料调整费用、弃风及切负荷惩罚）；式(2)为再调度（Re-dispatch）约束，表示在实际场景 $\tilde{w}$ 揭示后，$y$ 需满足物理限制，其可行域 $\Phi_2$ 涵盖了再调度变量非负约束、调整后出力的上下限约束、再调度弃风与切负荷约束、实时功率平衡约束以及实时直流潮流约束；式(3)描述了日前机组组合（Day-Ahead UC）问题，即在给定预测值 $\hat{w}_{\theta}$ 下最小化预期成本，其可行域 $\Phi_1$ 涵盖了机组出力非负及上下限约束、弃风与切负荷约束、机组启停逻辑约束、功率平衡约束以及直流潮流约束。

## 参考文献

[1] Chen X, Liu Y, Wu L. Towards improving unit commitment economics: An add-on tailor for renewable energy and reserve predictions [J]. IEEE Transactions on Sustainable Energy, 2024.