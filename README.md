# An_Open_Source_BiMIP_Toolbox_trial
This is the trial version. It will be gradually open-sourced in the future.
# BiMIP Toolbox - 用户指南
**An open source MATLAB toolbox for BiMIP (trial version)**  
[![AGPL-3.0 License](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE.txt)
[![View on GitHub](https://img.shields.io/badge/GitHub-Repository-brightgreen)](https://github.com/GreatTM/An_Open_Source_BiMIP_Toolbox_trial)

👤 **作者**:  
Yemin Wu (`yemin.wu@seu.edu.cn`)  
Shuai Lu (`shuai.lu.seu@outlook.com`)  

📜 **版权**: Copyright © 2025 Yemin Wu  
🌐 **官网**: https://github.com/GreatTM/An_Open_Source_BiMIP_Toolbox_trial  

---

## 🔧 安装与配置
### 前置依赖
1. 安装 [YALMIP](https://yalmip.github.io/)（建议最新版本）：
2. 安装 **Gurobi/Cplex** 求解器（任选其一）

### 工具箱安装
% 在MATLAB中运行：
addpath(genpath('BiMIP工具箱路径'));  % 添加包含子文件夹
savepath                           % 永久保存路径（可选）

## 🚀 快速开始
### 求解示例问题
BiMIP_toy_example1.m

## 📐 模型规范
### 标准形式
$$\begin{align*}
&\min_{x_u,z_u \in \mathbb Z^{N_z},x_l,z_l} c_1^T x_u + c_2^T z_u + c_3^T x_l + c_4^T z_l \\
&\text{s.t.} \\
&\quad A_u x_u + B_u z_u + C_u x_l + D_u z_l \leq b_u \\
&\quad E_u x_u + F_u z_u + G_u x_l + H_u z_l = h_u \\
\\
&\quad \min_{x_l,z_l \in \mathbb Z^{N_z}} c_5^T x_l + c_6^T z_l \\
&\quad \text{s.t.} \\
&\quad\quad A_l x_u + B_l z_u + C_l x_l + D_l z_l \leq b_l : \mu \\
&\quad\quad E_l x_u + F_l z_u + G_l x_l + H_l z_l = h_l : \lambda 
\end{align*}$$

### 变量命名规则
| 变量类型         | 代码标识      | 维度要求 |
|------------------|--------------|----------|
| 上层连续变量     | `model.var_xu` | N×1 向量 |
| 上层离散变量     | `model.var_zu` | N×1 向量 |
| 下层连续变量     | `model.var_xl` | N×1 向量 |
| 下层离散变量     | `model.var_zl` | N×1 向量 |

> 💡 使用 `reshape()` 确保变量为列向量

---

## ⚙️ BiMIPsettings 配置
| 参数 | 默认值 | 说明 |
|------|---------|------|
| `method` | `'KKT'` | 求解方法 [`KKT`/`strong_duality`] |
| `solver` | `'gurobi'` | 底层求解器 [`gurobi`/`cplex`] |
| `verbose` | `2` | 输出详细度 [0:静默, 1:基础, 2:+图形, 3:+求解器日志] |
| `RD_max_iterations` | `10` | 最大迭代次数 |
| `RD_optimal_gap` | `1e-4` | 收敛精度阈值 |

---

## 📊 输出结果解析
| 输出变量 | 说明 |
|----------|------|
| `Solution` | 包含所有变量最优解的结构体 |
| `BiMILP_record` | 求解过程记录（迭代次数、间隙等） |
| `coefficients` | 模型系数提取结果 |

---

## ⚠️ 重要限制（将持续更新）
1. **模型类型**：仅支持双层混合整数**线性**规划（BiMILP）
2. **非线性项**：不支持任何非线性项
3. **上层约束**：不得包含下层变量（如：`x_u + x_l ≤ 10` 非法）
4. **目标函数**：下层目标必须仅含下层变量

> 📌 违反上述限制将导致求解错误！

---

## 📜 许可与引用
本工具箱采用 **AGPL-3.0 许可证**，使用时需遵守：
Copyright © 2025 Yemin Wu.

详见 LICENSE.txt 文件
若在研究中使用了本工具箱，请引用：

bibtex

@software{BiMIPToolbox,

author = {Wu, Yemin and Lu, Shuai},

title = {An Open Source MATLAB Toolbox for BiMIP},

year = {2025},

url = {https://github.com/GreatTM/An_Open_Source_BiMIP_Toolbox_trial}

}
---

**遇到问题？**  
联系作者：`yemin.wu@seu.edu.cn`  
提交 Issue：[GitHub Issues](https://github.com/GreatTM/An_Open_Source_BiMIP_Toolbox_trial/issues)