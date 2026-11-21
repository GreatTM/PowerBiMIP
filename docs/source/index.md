---
hide-toc: true
myst:
  html_meta:
    description: MATLAB toolbox built on YALMIP for linear bilevel mixed-integer programming and two-stage robust optimization in power and energy systems.
---

(powerbimip)=
# Bilevel mixed-integer programming for power and energy systems

:::{container} pb-landing

PowerBiMIP is a MATLAB toolbox built on YALMIP for linear bilevel mixed-integer programs (BiMIP) and two-stage robust optimization with linear recourse (<span class="pb-nowrap">TRO-LP</span>). Its bilevel solver supports continuous, binary, and integer variables at both levels under optimistic and pessimistic formulations.

<div class="pb-actions">
  <a class="pb-button pb-button-primary" href="installation.html">Install PowerBiMIP</a>
  <a href="getting_started.html">Read the tutorial</a>
  <a class="pb-quiet-link" href="https://github.com/GreatTM/PowerBiMIP">GitHub</a>
</div>

<p class="pb-hero-meta"><code>v0.1.5</code> · MATLAB R2019b+ · YALMIP · Gurobi, CPLEX, COPT, MOSEK</p>

:::

(start-heading)=
## Formulate and solve in YALMIP syntax

::::{container} pb-example-layout

:::{container} pb-example-code

``` matlab
yalmip('clear');

model.var_upper.x = intvar(1, 1, 'full');   % Upper-level integer variable
model.var_lower.z = intvar(1, 1, 'full');   % Lower-level integer variable
model.var_lower.y = sdpvar(4, 1, 'full');   % Lower-level continuous variables

A = [-25, 20; 1, 2; 2, -1; -2, -10];
b = [30; 10; 15; -15];
u = [model.var_upper.x; model.var_lower.z];

model.cons_upper = (model.var_upper.x >= 0) + (A * u <= b);
model.cons_lower = (A * u <= b + model.var_lower.y) + ...
                   (model.var_lower.z >= 0) + (model.var_lower.y >= 0);
model.obj_upper  = -model.var_upper.x - 10 * model.var_lower.z;
model.obj_lower  = model.var_lower.z + 1e3 * sum(model.var_lower.y, 'all');

ops = BiMIPsettings('perspective', 'optimistic', ...
                    'method', 'exact_KKT', 'solver', 'gurobi');
[Solution, BiMIP_record] = solve_BiMIP(model, ops);
```

:::

:::{container} pb-example-companion

$$
\begin{aligned}
\min_{x_u, z_u, x_l, z_l} \;& c_u^{\top} x_u + d_u^{\top} z_u + e_u^{\top} x_l + f_u^{\top} z_l \\
\text{s.t.} \;& (x_u, z_u, x_l, z_l) \in \Omega_u, \quad (x_u, z_u) \in \mathbb{R}^{n_u} \times \mathbb{Z}^{p_u}, \\
& (x_l, z_l) \in \arg\min_{\tilde{x}_l, \tilde{z}_l} \bigl\{ e_l^{\top} \tilde{x}_l + f_l^{\top} \tilde{z}_l : (\tilde{x}_l, \tilde{z}_l) \in \Omega_l(x_u, z_u) \cap (\mathbb{R}^{n_l} \times \mathbb{Z}^{p_l}) \bigr\}
\end{aligned}
$$

Upper-level constraints $\Omega_u$ and lower-level constraints $\Omega_l(x_u, z_u)$ are polyhedral sets defined by linear inequalities and equalities.

<p class="pb-example-result">With the default solver, the example converges in three iterations to <var>x</var> = 2 and <var>z</var> = 2, with an upper-level objective of −22. See <a href="getting_started.html">Getting started</a> for the solver output and a <code>solve_TRO</code> example.</p>

:::

::::

(capabilities-heading)=
## Supported models and methods

<dl class="pb-capabilities simple">
  <div>
    <dt>Mixed-integer variables at both levels</dt>
    <dd>Declare continuous (<code>sdpvar</code>), binary (<code>binvar</code>), and integer (<code>intvar</code>) variables in both upper and lower problems. Objectives and constraints must be linear.</dd>
  </div>
  <div>
    <dt>Optimistic and pessimistic perspectives</dt>
    <dd>Solve optimistic bilevel models (including coupled upper-level constraints) and pessimistic bilevel models. Pessimistic mode currently requires uncoupled upper-level constraints and exact methods.</dd>
  </div>
  <div>
    <dt>Exact R&amp;D and the quick method</dt>
    <dd>Choose reformulation and decomposition (R&amp;D) with KKT or strong-duality master problems, or an L1-penalty alternating direction method (<code>quick</code>). Quick mode applies to optimistic BiMIP and <span class="pb-nowrap">TRO-LP</span> models.</dd>
  </div>
  <div>
    <dt>Two-stage robust optimization and MPS/AUX I/O</dt>
    <dd>Use <code>solve_TRO</code> for two-stage robust optimization with linear programming (LP) recourse via column-and-constraint generation (C&amp;CG). Import or export MibS <code>.mps</code>/<code>.aux</code> files.</dd>
  </div>
</dl>

### Comparison with existing toolboxes

:::{container} pb-comparison

<p class="pb-table-hint">Scroll to see all columns.</p>

| Toolbox | Platform | Lower-level integers | Optimistic | Pessimistic |
| :--- | :--- | :---: | :---: | :---: |
| YALMIP | MATLAB | | **✓** | |
| Pyomo/PAO | Python | | **✓** | |
| BilevelJuMP | Julia | | **✓** | |
| GAMS/EMP | GAMS | | **✓** | |
| MibS | C++ | **✓** | **✓**<sup>1</sup> | |
| **PowerBiMIP** | **MATLAB (Python<sup>2</sup>)** | **✓** | **✓** | **✓** |

<sup>1</sup> MibS currently only supports cases where connecting variables are pure integer variables.<br>
<sup>2</sup> The Python version with Pyomo modeling support is under development; checkmarks describe the current MATLAB version.

:::

## Power and energy system cases

<ul class="pb-case-list" role="list">
  <li>
    <a class="pb-case-title" href="case_library.html#transmission-grid-vulnerability-analysis">Transmission grid vulnerability analysis</a>
    <div><p>An attacker disconnects exactly <var>K</var> transmission lines while the operator minimizes load shedding through DC redispatch and corrective line switching.</p>
    <p class="pb-case-scale"><em>Scale</em>: One-area IEEE RTS-96 (24-bus, 38-branch) · 38 lower-level switching binaries</p></div>
  </li>
  <li>
    <a class="pb-case-title" href="case_library.html#decision-focused-forecasting-and-unit-commitment">Decision-focused forecasting and unit commitment</a>
    <div><p>A closed-loop model tunes renewable forecast parameters jointly with day-ahead unit commitment and real-time redispatch to reduce operating cost.</p>
    <p class="pb-case-scale"><em>Scale</em>: IEEE 118-bus · 22,680 lower-level binaries</p></div>
  </li>
  <li>
    <a class="pb-case-title" href="case_library.html#adaptive-robust-dispatch-of-integrated-energy-systems">Adaptive robust dispatch of integrated energy systems</a>
    <div><p>A two-stage robust model schedules power distribution, district heating, and storage while accounting for building thermal inertia and uncertainty in renewable generation, electric load, and temperatures.</p>
    <p class="pb-case-scale"><em>Scale</em>: 33-bus electricity-heat network · 24-hour C&amp;CG dispatch</p></div>
  </li>
</ul>

Eleven smaller BiMIP, robust, and MPS/AUX benchmark scripts are also included in `matlab/examples/BiMIP_benchmarks/` (<a href="case_library.html#standard-bimip-and-tro-benchmarks">Case library</a>).

:::{container} pb-python-status

A Python version of PowerBiMIP with Pyomo modeling support is in development; updates are posted on [GitHub](https://github.com/GreatTM/PowerBiMIP).

:::

(paper-heading)=
## Citation and license

<p>[1] Y. Wu, S. Lu, W. Gu, B. Zeng, Y. Xu and M. Chen, "PowerBiMIP: A Standardized Modeling Framework and Solver for Bilevel Mixed-Integer Programming in Power and Energy Systems," Proceedings of the CSEE, 2026, pp. 1-18, doi: <a href="https://doi.org/10.13334/j.0258-8013.pcsee.261230">10.13334/j.0258-8013.pcsee.261230</a>.</p>

<p lang="zh-CN">[1] 吴晔敏,陆帅,顾伟,等.PowerBiMIP：面向电力能源系统优化的规范化双层混合整数规划建模与求解器[J/OL].中国电机工程学报,1-18[2026-09-21].DOI:10.13334/j.0258-8013.pcsee.261230.</p>

[BibTeX and citation details](citation.md)

PowerBiMIP is licensed for academic and non-commercial research only ([LICENSE](https://github.com/GreatTM/PowerBiMIP/blob/main/LICENSE)).

(community-heading)=
## Contact

<p class="pb-contact-links">
  <a href="https://github.com/GreatTM/PowerBiMIP/issues">GitHub Issues</a>
  <a href="mailto:yemin.wu@seu.edu.cn">yemin.wu@seu.edu.cn</a>
</p>

```{toctree}
:hidden:
:maxdepth: 2

Installation <installation>
Getting started <getting_started>
Case library <case_library>
Citation and license <citation>
```
