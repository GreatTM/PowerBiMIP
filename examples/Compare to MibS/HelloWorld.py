# $$\begin{aligned}
# &\min_{x,y} \quad x - 4y \\
# &\text{s.t.} \quad x \geq 0 \\
# &\quad \quad \min_{y} \quad y \\
# &\quad \quad \text{s.t.} \quad -x - y \leq -3 \\
# &\quad \quad \quad \quad -2x + y \leq 0 \\
# &\quad \quad \quad \quad 2x + y \leq 12 \\
# &\quad \quad \quad \quad 3x - 2y \leq 4 \\
# &\quad \quad \quad \quad y \geq 0
# \end{aligned}$$

import pyomo.environ as pe
from pao.pyomo import *

# 1. 创建模型对象
model = pe.ConcreteModel()

# 2. 定义上层（Leader）变量
# 在PAO中，上层变量通常定义在主模型上
model.x = pe.Var(bounds=(0, None), doc="上层变量")

# 3. 定义下层（Follower）子模型
# fixed=[model.x] 表示 x 在下层被视为常数（参数）
model.sub = SubModel(fixed=[model.x])

# 4. 定义下层变量
model.sub.y = pe.Var(bounds=(0, None), doc="下层变量")

# 5. 定义上层目标函数
model.obj = pe.Objective(expr=model.x - 4*model.sub.y, sense=pe.minimize)

# 6. 定义下层目标函数
model.sub.obj = pe.Objective(expr=model.sub.y, sense=pe.minimize)

# 7. 定义下层约束条件
# 注意：涉及下层变量的约束通常归类为下层约束
model.sub.c1 = pe.Constraint(expr= -model.x - model.sub.y <= -3)
model.sub.c2 = pe.Constraint(expr= -2*model.x + model.sub.y <= 0)
model.sub.c3 = pe.Constraint(expr= 2*model.x + model.sub.y <= 12)
model.sub.c4 = pe.Constraint(expr= 3*model.x - 2*model.sub.y <= 4)

# ==========================================
# 求解部分
# ==========================================

# 方式 A: 使用 MibS 求解器 (如果你本地编译了MibS)
# solver = Solver('pao.pyomo.MIBS') 

# 方式 B: 使用 Gurobi 求解 (通过PAO自动转化为单层MIP)
# 'pao.pyomo.FA' 代表 Fortuny-Amat 转化方法 (Big-M)
# mip_solver 指定底层用于解MIP的求解器，这里我们用 gurobi
solver = Solver('pao.pyomo.FA', mip_solver='gurobi')

# 修改前
# results = solver.solve(M)

# 修改后：打开日志 (tee=True)
results = solver.solve(model, tee=True)

# 输出结果
print(f"上层变量 x: {pe.value(model.x)}")
print(f"下层变量 y: {pe.value(model.sub.y)}")
print(f"上层目标值: {pe.value(model.obj)}")