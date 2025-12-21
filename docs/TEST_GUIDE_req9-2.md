# req9-2 绘图功能测试指南

本文档提供了验证 req9-2（迭代图形界面美化）功能的测试步骤和预期结果。

---

## 测试环境要求

- MATLAB R2021a 及以上版本（推荐）
- YALMIP 工具箱
- Gurobi 或 CPLEX 求解器
- PowerBiMIP 工具箱已添加到 MATLAB 路径

---

## 测试用例 1：BiMIP exact_KKT 模式

### 测试步骤

1. 打开 MATLAB
2. 进入 PowerBiMIP 根目录
3. 运行以下代码：

```matlab
% 测试 BiMIP exact_KKT 模式的绘图
clear; close all; clc;
yalmip('clear');

% 加载示例
run('examples/toy_examples/BiMIP_toy_example1.m');
```

### 预期结果

- **控制台输出**：显示 R&D 迭代日志（Iter | MP Obj | SP1 Obj | SP2 Obj | LB | UB | Gap）
- **弹窗图形**：
  - 标题：`RD Convergence`
  - 图形尺寸：约 800×200（4:1 长宽比）
  - 左 Y 轴：Objective，显示红色方框线（UB）和蓝色三角线（LB）
  - 右 Y 轴：Gap (%)，显示黑色虚线圆形（Gap）
  - X 轴：Iteration
  - 所有字体：Times New Roman 12pt
  - Grid 和 Box 均开启，线宽 0.75
  - 图例无边框，横向排列
- **保存文件**：
  - `results/figures/RD_<timestamp>_convergence.png`
  - `results/figures/RD_<timestamp>_convergence.eps`

---

## 测试用例 2：BiMIP quick 模式

### 测试步骤

```matlab
% 测试 BiMIP quick 模式（Fast-R&D + L1-PADM）
clear; close all; clc;
yalmip('clear');

% 定义变量
model.var.x = intvar(1,1,'full');
model.var.z = intvar(1,1,'full');
model.var.y = sdpvar(4,1,'full');

% 约束和目标（与 toy_example1 相同）
model.constraints_upper = [];
model.constraints_upper = model.constraints_upper + (model.var.x >= 0);
model.constraints_upper = model.constraints_upper + (-25 * model.var.x + 20 * model.var.z <= 30);
model.constraints_upper = model.constraints_upper + (model.var.x + 2 * model.var.z <= 10);
model.constraints_upper = model.constraints_upper + (2 * model.var.x - model.var.z <= 15);
model.constraints_upper = model.constraints_upper + (2 * model.var.x + 10 * model.var.z >= 15);

model.constraints_lower = [];
model.constraints_lower = model.constraints_lower + (-25 * model.var.x + 20 * model.var.z <= 30 + model.var.y(1,1));
model.constraints_lower = model.constraints_lower + (model.var.x + 2 * model.var.z <= 10 + model.var.y(2,1));
model.constraints_lower = model.constraints_lower + (2 * model.var.x - model.var.z <= 15 + model.var.y(3,1));
model.constraints_lower = model.constraints_lower + (2 * model.var.x + 10 * model.var.z >= 15 - model.var.y(4,1));
model.constraints_lower = model.constraints_lower + (model.var.z >= 0);
model.constraints_lower = model.constraints_lower + (model.var.y >= 0);

model.objective_upper = -model.var.x - 10 * model.var.z;
model.objective_lower = model.var.z + 1e3 * sum(model.var.y,'all');

model.var_xu = [];
model.var_zu = [reshape(model.var.x, [], 1)];
model.var_xl = [reshape(model.var.y, [], 1)];
model.var_zl = [reshape(model.var.z, [], 1)];

% 使用 quick 模式 + 实时绘图
ops = BiMIPsettings( ...
    'perspective', 'optimistic', ...
    'method', 'quick', ...
    'solver', 'gurobi', ...
    'verbose', 1, ...
    'plot.verbose', 2, ...  % 启用实时绘图
    'max_iterations', 10, ...
    'optimal_gap', 1e-4);

[Solution, BiMIP_record] = solve_BiMIP(model.var, ...
    model.var_xu, model.var_zu, model.var_xl, model.var_zl, ...
    model.constraints_upper, model.constraints_lower, ...
    model.objective_upper, model.objective_lower, ops);
```

### 预期结果

- **控制台输出**：
  - R&D 外层迭代日志
  - 每次外层迭代后显示 L1-PADM 内层迭代信息（但会被清除）
- **弹窗图形 1**：`RD Convergence`（与测试用例 1 相同）
- **弹窗图形 2**：`L1-PADM Convergence`
  - 多子图垂直排列（n×1，n = 外层迭代次数-1）
  - 每个子图显示对应 R&D 迭代的 PADM 收敛曲线
  - 子图标题：`R&D Iteration 2`, `R&D Iteration 3`, ...
  - Y 轴：Objective
  - X 轴：Iteration
- **保存文件**：
  - `results/figures/RD_<timestamp>_convergence.png`
  - `results/figures/RD_<timestamp>_convergence.eps`
  - `results/figures/PADM_<timestamp>_convergence.png`
  - `results/figures/PADM_<timestamp>_convergence.eps`

---

## 测试用例 3：Robust C&CG

### 测试步骤

如果您有 TRO 示例可用：

```matlab
% 测试 Robust C&CG 绘图
clear; close all; clc;
yalmip('clear');

% 运行 TRO 示例（如果可用）
cd examples/TRO-IES/
run('TRO_IES_example.m');
```

或者使用简化的 TRO-LP 测试：

```matlab
% 简化 TRO-LP 测试
clear; close all; clc;
yalmip('clear');

% 第一阶段变量
y = sdpvar(2,1);

% 第二阶段变量
x = sdpvar(2,1);

% 不确定参数
u = sdpvar(2,1);

% 第一阶段约束
cons_1st = [y >= 0; sum(y) <= 10];

% 第二阶段约束（依赖 y 和 u）
cons_2nd = [x >= 0; x <= y + u];

% 不确定集约束
cons_uncertainty = [u >= 0; u <= 2; sum(u) <= 3];

% 目标函数
obj_1st = sum(y);
obj_2nd = -sum(x);

% 配置 C&CG 求解器
ops = RobustCCGsettings( ...
    'mode', 'exact_KKT', ...
    'solver', 'gurobi', ...
    'verbose', 1, ...
    'plot.verbose', 1, ...
    'max_iterations', 20, ...
    'gap_tol', 1e-4);

% 调用 solve_TRO
original_var.y = y;
original_var.x = x;
original_var.u = u;

[Solution, CCG_record] = solve_TRO(original_var, y, [], x, [], u, ...
    cons_1st, cons_2nd, cons_uncertainty, obj_1st, obj_2nd, ops);
```

### 预期结果

- **控制台输出**：C&CG 迭代日志（Iter | MP Obj | SP Obj | LB | UB | Gap% | Time）
- **弹窗图形**：`CCG Convergence`
  - 与 R&D 图形风格完全一致
  - 左 Y 轴：Objective（UB 红色方框、LB 蓝色三角）
  - 右 Y 轴：Gap (%)（黑色虚线圆形）
  - Times New Roman 12pt，Grid/Box on
- **保存文件**：
  - `results/figures/CCG_<timestamp>_convergence.png`
  - `results/figures/CCG_<timestamp>_convergence.eps`

---

## 测试用例 4：关闭绘图功能

### 测试步骤

```matlab
% 测试关闭绘图
ops = BiMIPsettings( ...
    'method', 'exact_KKT', ...
    'plot.verbose', 0);  % 关闭绘图

% 运行求解器（使用 toy_example1 模型）
[Solution, BiMIP_record] = solve_BiMIP(model.var, ...
    model.var_xu, model.var_zu, model.var_xl, model.var_zl, ...
    model.constraints_upper, model.constraints_lower, ...
    model.objective_upper, model.objective_lower, ops);
```

### 预期结果

- **控制台输出**：正常显示迭代日志
- **无图形弹窗**
- **无保存文件**

---

## 测试用例 5：仅保存图形不实时显示

### 测试步骤

```matlab
% 测试仅保存不实时更新
ops = BiMIPsettings( ...
    'method', 'exact_KKT', ...
    'plot.verbose', 1);  % 仅最终保存

[Solution, BiMIP_record] = solve_BiMIP(model.var, ...
    model.var_xu, model.var_zu, model.var_xl, model.var_zl, ...
    model.constraints_upper, model.constraints_lower, ...
    model.objective_upper, model.objective_lower, ops);
```

### 预期结果

- **控制台输出**：正常显示迭代日志
- **图形在求解结束后弹出**（不实时刷新）
- **保存文件**：png 和 eps

---

## 常见问题排查

### 问题 1：报错 "Undefined function or variable 'plotConvergenceCurves'"

**原因**：`src/utils/` 未添加到 MATLAB 路径

**解决**：
```matlab
addpath(genpath('src'));
```

### 问题 2：报错 "Reference to non-existent field 'plot'"

**原因**：旧版本 settings 文件缓存

**解决**：
```matlab
clear ops;
ops = BiMIPsettings();  % 重新生成默认配置
```

### 问题 3：图形显示但未保存文件

**原因**：`ops.plot.saveFig` 设置为 false

**解决**：
```matlab
ops.plot.saveFig = true;
```

### 问题 4：保存目录权限错误

**原因**：`results/figures/` 目录不可写

**解决**：
```matlab
mkdir('results/figures');
```

---

## 验收标准总结

所有测试用例通过，需满足：

1. ✅ 图形尺寸为 4:1 长宽比（约 800×200）
2. ✅ 颜色符合规范（UB 红色方框、LB 蓝色三角、Gap 黑色虚线圆形）
3. ✅ 所有文本使用 Times New Roman 12pt
4. ✅ Grid 和 Box 均开启，box 线宽 0.75
5. ✅ 图例无边框，横向排列
6. ✅ PADM 子图正确排列（n×1 布局）
7. ✅ 文件正确保存为 png 和 eps 格式
8. ✅ `plot.verbose` 参数正确控制绘图行为
9. ✅ 无 linter 错误或警告（除已抑制的 NASGU）

---

## 后续改进建议

如测试中发现问题或有改进需求，请在以下文档中记录：

- Bug 报告：提交 GitHub Issue
- 功能改进：更新 `docs/requirements_doc/req9-2_plotBeauty.md`
- 实施修改：记录到 `docs/operates_log/ope_req9-2.md`

