# Case library

All cases are included under `matlab/examples`. Run them from the `matlab` folder after [installing PowerBiMIP](installation.md).

| Case | Interface | System | Entry script |
| :--- | :--- | :--- | :--- |
| [Grid vulnerability](#transmission-grid-vulnerability-analysis) | `solve_BiMIP` | IEEE RTS-96, one area | `main_Vulnerability_Analysis.m` |
| [Forecasting and unit commitment](#decision-focused-forecasting-and-unit-commitment) | `solve_BiMIP` | IEEE 118-bus | `main_SPO.m` |
| [Integrated energy dispatch](#adaptive-robust-dispatch-of-integrated-energy-systems) | `solve_TRO` | 33-bus power and heat | `TRO_IES_example.m` |
| [Benchmarks](#standard-bimip-and-tro-benchmarks) | Both | 11 small instances | One script each |

## Transmission grid vulnerability analysis

Folder: `matlab/examples/Vulnerability_Analysis`

This case studies line interdiction with corrective switching on the one-area IEEE RTS-96 system: 24 buses, 38 branches and 2,479 MW of load. It follows Zhao and Zeng (2013), with the line ratings and loads modified by Delgadillo et al. (2010).

An attacker disconnects exactly $K$ of the 38 lines. The operator then minimizes load shedding with DC power flow, generator redispatch and its own line-switching decisions. Both levels therefore have 38 binary variables.

$$
\begin{aligned}
\min_{u \in \{0,1\}^{38}} \quad & -\mathbf{1}^{\top} s \\
\text{s.t.} \quad & \textstyle\sum_{\ell} u_{\ell} = K, \\
& (v, s, \dots) \in \arg\min \bigl\{ \mathbf{1}^{\top} \tilde{s} : (\tilde{v}, \tilde{s}, \dots) \in \Omega_{\text{DC}}(u),\; \tilde{v} \in \{0,1\}^{38} \bigr\}.
\end{aligned}
$$

Here $u$ marks attacked lines, $v$ the lines the operator keeps in service and $s$ the load shed at each bus. Because the lower level contains binary variables, a single-level KKT reformulation is not available.

Run the following command from the `matlab` folder.

```matlab
run('examples/Vulnerability_Analysis/main_Vulnerability_Analysis.m');
```

Settings at the top of `main_Vulnerability_Analysis.m`:

- `K_values` sets the attack budget. The default is 2, for which the published load shedding is 279 MW.
- `mode_to_run` is `'exact'` or `'quick'`.
- `solver` selects the MILP solver, Gurobi by default.

Reference values for $K = 1$ to 12 are stored in `run_ZZ2013_RTS96_BiMIP.m`. The same instances exported for MibS are in the `mibs` subfolder.

```{figure} _static/figures/powerbimip-mibs-time-to-gap.png
:name: fig-rts96-time-to-gap
:alt: Six panels of optimality gap in percent against solve time in seconds on a log scale, for attack budgets K = 2, 4, 6, 8, 10 and 12, comparing PowerBiMIP exact mode, PowerBiMIP quick mode and MibS.
:width: 100%

Optimality gap over time on the RTS-96 case for K = 2, 4, 6, 8, 10 and 12. Red squares mark PowerBiMIP exact mode, blue triangles mark PowerBiMIP quick mode, and the black dashed line marks MibS. The vertical axis (<span lang="zh-CN">最优值间隙</span>) shows the gap in percent. The horizontal axis (<span lang="zh-CN">时间</span>) shows time in seconds on a log scale. See the [PowerBiMIP paper](https://doi.org/10.13334/j.0258-8013.pcsee.261230) for the setup and gap definitions.
```

References:

1. L. Zhao and B. Zeng, "Vulnerability analysis of power grids with line switching," *IEEE Transactions on Power Systems*, vol. 28, no. 3, pp. 2727–2736, 2013.
2. A. Delgadillo, J. M. Arroyo and N. Alguacil, "Analysis of electric grid interdiction with line switching," *IEEE Transactions on Power Systems*, vol. 25, no. 2, pp. 633–641, 2010.

## Decision-focused forecasting and unit commitment

Folder: `matlab/examples/SPO`

Mean squared error penalizes equal-sized under- and overpredictions equally, even when their operating costs differ. This case, after Chen, Liu and Wu (2024), trains the renewable forecast to reduce unit commitment and redispatch costs.

The upper level chooses the forecast parameters $\theta$ and the real-time redispatch $y_i$. The lower level is the day-ahead unit commitment that uses the forecast, solved for every training day $i$:

$$
\begin{aligned}
\min_{\theta,\, \{x_i, z_i, y_i\}} \quad & \sum_{i \in I} \bigl( c_4^{\top} x_i + c_2^{\top} z_i + c_3^{\top} y_i \bigr) + \lambda \|\theta\|_1 \\
\text{s.t.} \quad & y_i \in \Phi_2(x_i, z_i, \tilde{w}_i), \\
& (x_i, z_i) \in \arg\min_{x,\; z \in \{0,1\}^{N_z}} \bigl\{ c_1^{\top} x + c_2^{\top} z : (x, z) \in \Phi_1(\hat{w}_{\theta}(u_i)) \bigr\}, \quad i \in I.
\end{aligned}
$$

On the IEEE 118-bus system, the training problem has 47,050 continuous upper-level variables. The lower level has 39,480 continuous and 22,680 binary variables.

This case also requires the Statistics and Machine Learning Toolbox. Run the following command from the `matlab` folder.

```matlab
run('examples/SPO/main_SPO.m');
```

The script first fits a linear regression baseline. It then solves the bilevel problem with the quick method, evaluates both forecasts on the test days and prints the cost reduction relative to the baseline.

Reference:

1. X. Chen, Y. Liu and L. Wu, "Towards improving unit commitment economics: An add-on tailor for renewable energy and reserve predictions," *IEEE Transactions on Sustainable Energy*, 2024.

## Adaptive robust dispatch of integrated energy systems

Folder: `matlab/examples/TRO-IES`

This case schedules an electricity and heat system for the next 24 hours under uncertainty, following Lu et al. (2020). The system combines a 33-bus distribution network, gas turbines, electric boilers, battery and heat storage, a district heating network and buildings with thermal inertia.

- **First stage.** Charging and discharging states and schedules of the battery and heat storage.
- **Second stage.** Dispatch of gas turbines and electric boilers, grid exchange, distribution power flow, heating network temperatures and indoor temperatures.
- **Uncertainty.** Renewable output, electric load, outdoor temperature and an indoor temperature correction. Each has a deviation limit of 20% and a separate uncertainty budget of $\Gamma = 12$.

`solve_TRO` uses C&CG to solve the problem. Each subproblem is a bilevel linear program with continuous uncertainty and recourse variables. The script solves it with the quick method.

Run the case:

```matlab
run('examples/TRO-IES/TRO_IES_example.m');
```

The script uses CPLEX. To use another solver, change `'solver', 'cplex'` in its `TROsettings` call. The relative gap tolerance is 0.1%.

Reference:

1. S. Lu, W. Gu, S. Zhou et al., "Adaptive robust dispatch of integrated energy system considering uncertainties of electricity and outdoor temperature," *IEEE Transactions on Industrial Informatics*, vol. 16, no. 7, pp. 4691–4702, 2020.

## Standard BiMIP and TRO benchmarks

Folder: `matlab/examples/BiMIP_benchmarks`

[Getting started](getting_started.md) walks through both toy examples. The nine numbered scripts load standard instances from `.mps` and `.aux` files with `mpsaux2yalmip` and solve them with `solve_BiMIP`.

| Script | Type | Source instance |
| :--- | :--- | :--- |
| `BiMIP_toy_example1.m` | Optimistic, coupled | Moore and Bard (1990); optimum −22 |
| `TRO_LP_toy_example1.m` | Two-stage robust | Zeng and Zhao (2013); optimum 33680 |
| `P1_run_milp_4_20_10_0110.m` | Optimistic | `milp_4_20_10_0110` |
| `P2_VSP_N22_L77_B200_C14.m` | Optimistic | `VSP_N22_L77_B200_C14` |
| `P3_run_noswot_0_100.m` | Optimistic | `noswot_0_100` |
| `P4_run_nexp_150_20_8_5_0_100.m` | Optimistic | `nexp-150-20-8-5_0_100` |
| `P5_run_pigeon_10_0_100.m` | Optimistic | `pigeon-10_0_100` |
| `P6_run_bmilplib_10_1.m` | Optimistic | `bmilplib_10_1` |
| `P7_run_neos5_50_50.m` | Optimistic | `neos5_50_50` |
| `P8_PBLNetwork_Zeng.m` | Pessimistic | `VSP_N22_L77_B200_C9` |
| `P9_PBLNetwork_Zeng.m` | Pessimistic | `VSP_N23_L78_B200_C7` |

To exchange models with MibS, use `mpsaux2yalmip` to import an instance and `exportBiMIPToMibS` or `Yalmip2MpsAux` to export one. All three are in `matlab/src/utils`.
