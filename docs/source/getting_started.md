# Getting started

PowerBiMIP has two solver interfaces built on YALMIP:

- `solve_BiMIP` for linear bilevel mixed-integer programs.
- `solve_TRO` for two-stage robust optimization with linear programming recourse.

Run the examples from the repository's `matlab` folder after [installing PowerBiMIP](installation.md).

## Modeling conventions

Use these modeling conventions for both interfaces.

- **Clear YALMIP's state.** Run `yalmip('clear')` before declaring variables. `solve_TRO` stops with `PowerBiMIP:DirtyEnvironment` if YALMIP has more registered variables than the model declares.
- **Minimize.** Every objective field is minimized. To maximize, negate the expression.
- **Stay linear.** Constraints and objectives must be linear. Nonlinear constraints and quadratic objectives are rejected.
- **Use the exact fields.** Missing or extra fields raise `PowerBiMIP:InputFormat`. Variable fields accept a YALMIP variable array or nested structs and cell arrays of such arrays.

| Interface | Required fields |
| :--- | :--- |
| `solve_BiMIP` | `var_upper`, `var_lower`, `cons_upper`, `cons_lower`, `obj_upper`, `obj_lower` |
| `solve_TRO` | `var_1st`, `var_2nd`, `var_uncertain`, `cons_1st`, `cons_2nd`, `cons_uncertainty`, `obj_1st`, `obj_2nd` |

### Optimistic and pessimistic models

In the optimistic perspective, upper-level constraints may contain lower-level variables (coupling constraints). PowerBiMIP classifies the model automatically:

- If the upper-level variables in those rows do not appear in the lower-level constraints, the rows are enforced directly in a subproblem.
- Otherwise, the coupling constraints are reformulated with a penalty factor `kappa` (default 50).

In the pessimistic perspective, PowerBiMIP solves models without coupling constraints. It uses a regularized reformulation, checks lower-level optimality and, if needed, solves a correction problem.

Pessimistic models currently support only the exact methods. Pessimistic models with coupling constraints are not yet supported.

## Example 1: bilevel mixed-integer program

This example is the classic problem of Moore and Bard (1990), also used by Zeng and An (2014). The script is `matlab/examples/BiMIP_benchmarks/BiMIP_toy_example1.m`.

### BiMIP formulation

The leader chooses an integer $x \ge 0$. Four of its constraints also contain the follower's integer variable $z$:

$$
\begin{aligned}
\min_{x \in \mathbb{Z}_+} \quad & -x - 10 z \\
\text{s.t.} \quad & -25 x + 20 z \le 30, \quad x + 2 z \le 10, \\
& 2 x - z \le 15, \quad 2 x + 10 z \ge 15.
\end{aligned}
$$

For a given $x$, the follower chooses $z$ and slack variables $y$:

$$
\begin{aligned}
\min_{y \in \mathbb{R}_+^4,\, z \in \mathbb{Z}_+} \quad & z + 1000 \sum_{k=1}^{4} y_k \\
\text{s.t.} \quad & -25 x + 20 z \le 30 + y_1, \quad x + 2 z \le 10 + y_2, \\
& 2 x - z \le 15 + y_3, \quad 2 x + 10 z \ge 15 - y_4.
\end{aligned}
$$

### BiMIP script

```matlab
clear; close all; clc;
yalmip('clear');

% Variables
model.var_upper.x = intvar(1, 1, 'full');
model.var_lower.z = intvar(1, 1, 'full');
model.var_lower.y = sdpvar(4, 1, 'full');

% Upper level
model.cons_upper = [];
model.cons_upper = model.cons_upper + (model.var_upper.x >= 0);
model.cons_upper = model.cons_upper + (-25 * model.var_upper.x + 20 * model.var_lower.z <= 30);
model.cons_upper = model.cons_upper + (model.var_upper.x + 2 * model.var_lower.z <= 10);
model.cons_upper = model.cons_upper + (2 * model.var_upper.x - model.var_lower.z <= 15);
model.cons_upper = model.cons_upper + (2 * model.var_upper.x + 10 * model.var_lower.z >= 15);
model.obj_upper  = -model.var_upper.x - 10 * model.var_lower.z;

% Lower level
model.cons_lower = [];
model.cons_lower = model.cons_lower + (-25 * model.var_upper.x + 20 * model.var_lower.z <= 30 + model.var_lower.y(1));
model.cons_lower = model.cons_lower + (model.var_upper.x + 2 * model.var_lower.z <= 10 + model.var_lower.y(2));
model.cons_lower = model.cons_lower + (2 * model.var_upper.x - model.var_lower.z <= 15 + model.var_lower.y(3));
model.cons_lower = model.cons_lower + (2 * model.var_upper.x + 10 * model.var_lower.z >= 15 - model.var_lower.y(4));
model.cons_lower = model.cons_lower + (model.var_lower.z >= 0) + (model.var_lower.y >= 0);
model.obj_lower  = model.var_lower.z + 1e3 * sum(model.var_lower.y, 'all');

% Solve
ops = BiMIPsettings( ...
    'perspective', 'optimistic', ...
    'method', 'exact_KKT', ...
    'solver', 'gurobi', ...
    'verbose', 2, ...
    'max_iterations', 10, ...
    'optimal_gap', 1e-4, ...
    'plot.verbose', 1);

[Solution, BiMIP_record] = solve_BiMIP(model, ops);

fprintf('Upper objective: %.4f (x = %d, z = %d)\n', ...
    Solution.obj_upper, round(Solution.var_upper.x), round(Solution.var_lower.z));
```

### Output and solution fields

The four coupling constraints share $x$ with the lower-level constraints, so PowerBiMIP reformulates them with `kappa = 50`. With the default solver, the decomposition converges in three iterations.

```text
  Iter |       MP Obj     SP1 Obj     SP2 Obj |          LB          UB         Gap
     1 |     -42.0000      2.0000    -22.0000 |      -42.00      -22.00      90.91%
     2 |     -26.0000      1.0000    -16.0000 |      -26.00      -22.00      18.18%
     3 |     -22.0000      2.0000    -22.0000 |      -22.00      -22.00       0.00%

Convergence criteria met (gap = 0.00% <= 0.01%).
```

`solve_BiMIP` returns two structs:

- **`Solution`** mirrors `model` with every expression replaced by its value. Here `Solution.var_upper.x` and `Solution.var_lower.z` are both 2, and `Solution.obj_upper` is −22. YALMIP also updates the original variables, so `value(model.var_upper.x)` gives the same result.
- **`BiMIP_record`** holds the iteration history (`LB`, `UB`, `gap`, `iteration_num`, `total_time`) and the master and subproblem solutions of each iteration.

## Example 2: two-stage robust optimization

`solve_TRO` solves two-stage robust problems whose second stage is a linear program, assuming relatively complete recourse. It uses column-and-constraint generation (C&CG).

Each C&CG subproblem has a max-min structure. PowerBiMIP turns it into a bilevel linear program and solves it with KKT conditions, strong duality or the penalty-based quick method.

### Robust facility location formulation

The script `matlab/examples/BiMIP_benchmarks/TRO_LP_toy_example1.m` implements the three-facility location and transportation problem of Zeng and Zhao (2013):

$$
\begin{aligned}
\min_{y \in \{0,1\}^3,\, z \in \mathbb{R}_+^3} \quad & f^{\top} y + c^{\top} z + \max_{g \in \mathcal{G}} \min_{x \ge 0} \sum_{i=1}^{3} \sum_{j=1}^{3} T_{ij} x_{ij} \\
\text{s.t.} \quad & z_i \le 800 y_i \quad (i = 1, 2, 3), \qquad \sum_{i=1}^{3} z_i \ge 772.
\end{aligned}
$$

Shipments $x_{ij}$ respect each facility's capacity, $\sum_j x_{ij} \le z_i$, and meet the uncertain demand $\sum_i x_{ij} \ge \bar{d}_j + 40 g_j$. The demand deviations lie in the budget set

$$
\mathcal{G} = \bigl\{ g \in [0, 1]^3 : g_1 + g_2 + g_3 \le 1.8,\; g_1 + g_2 \le 1.2 \bigr\}.
$$

### Two-stage robust script

```matlab
clear; close all; clc;
yalmip('clear');

f = [400; 414; 326];
c = [18; 25; 20];
T = [22, 33, 24; 33, 23, 30; 20, 25, 27];
d_nominal = [206; 274; 220];
n_facilities = 3; n_demands = 3; capacity_limit = 800;

% Variables
model.var_1st.y     = binvar(n_facilities, 1, 'full');
model.var_1st.z     = sdpvar(n_facilities, 1, 'full');
model.var_uncertain = sdpvar(n_demands, 1, 'full');
model.var_2nd.x     = sdpvar(n_facilities, n_demands, 'full');

% First stage
model.cons_1st = (model.var_1st.z >= 0) + (sum(model.var_1st.z) >= 772);
for i = 1:n_facilities
    model.cons_1st = model.cons_1st + (model.var_1st.z(i) <= capacity_limit * model.var_1st.y(i));
end

% Second stage
model.cons_2nd = (model.var_2nd.x(:) >= 0);
for i = 1:n_facilities
    model.cons_2nd = model.cons_2nd + (sum(model.var_2nd.x(i, :)) <= model.var_1st.z(i));
end
for j = 1:n_demands
    model.cons_2nd = model.cons_2nd + (sum(model.var_2nd.x(:, j)) >= d_nominal(j) + 40 * model.var_uncertain(j));
end

% Uncertainty set
model.cons_uncertainty = (0 <= model.var_uncertain <= 1) + ...
    (sum(model.var_uncertain) <= 1.8) + ...
    (model.var_uncertain(1) + model.var_uncertain(2) <= 1.2);

% Objectives
model.obj_1st = f' * model.var_1st.y + c' * model.var_1st.z;
model.obj_2nd = sum(sum(T .* model.var_2nd.x));

% Solve
ops = TROsettings('mode', 'exact_KKT', 'solver', 'gurobi', 'verbose', 2, 'gap_tol', 1e-4);
[Solution, Robust_record] = solve_TRO(model, ops);

fprintf('Worst-case total cost: %.4f (first-stage cost: %.4f)\n', ...
    Robust_record.UB(end), Solution.obj_1st);
```

With the default solver, C&CG converges in three iterations. The solution opens facilities 1 and 3, with capacities 255.2 and 516.8.

```{note}
`Solution.obj_1st` is only the first-stage cost, 15655.6. The worst-case total cost, 33680, is in `Robust_record.UB(end)`.
```

## Solver options

### BiMIPsettings

Pass options to `BiMIPsettings` as name-value pairs.

| Option | Default | Meaning |
| :--- | :--- | :--- |
| `perspective` | `'optimistic'` | `'optimistic'` or `'pessimistic'` |
| `method` | `'exact_KKT'` | `'exact_KKT'`, `'exact_strong_duality'` or `'quick'` |
| `solver` | `'gurobi'` | YALMIP solver name, such as `'cplex'`, `'copt'` or `'mosek'` |
| `max_iterations` | 10 | Maximum number of outer iterations |
| `optimal_gap` | 1e-4 | Relative gap tolerance |
| `kappa` | 50 | Penalty factor for reformulating coupling constraints |
| `penalty_rho` | 50 | Initial penalty factor of the quick method |
| `verbose` | 1 | 0 silent, 1 summary, 2 detailed, 3 adds solver logs |
| `plot.verbose` | 0 | 0 none, 1 final plot, 2 live plot (needs `verbose` ≥ 2) |
| `plot.saveFig` | `false` | Save figures to `plot.saveDir` |

The quick method is available only for optimistic models.

### TROsettings

Pass options to `TROsettings` as name-value pairs. `solve_TRO(model, ops, u_init)` also accepts an optional initial scenario `u_init`.

| Option | Default | Meaning |
| :--- | :--- | :--- |
| `mode` | `'exact_KKT'` | `'exact_KKT'`, `'exact_strong_duality'` or `'quick'` |
| `solver` | `'gurobi'` | YALMIP solver name |
| `max_iterations` | 50 | Maximum number of C&CG iterations |
| `gap_tol` | 1e-4 | Relative gap tolerance |
| `penalty_rho` | 100 | Initial penalty factor of the quick method |
| `verbose` | 1 | 0 silent, 1 summary, 2 detailed, 3 adds solver logs |
| `plot.verbose` | 0 | 0 none, 1 final plot, 2 live plot (needs `verbose` ≥ 2) |

Note the different names: `TROsettings` uses `mode` and `gap_tol` where `BiMIPsettings` uses `method` and `optimal_gap`.
