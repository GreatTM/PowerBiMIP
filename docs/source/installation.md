# Installation

PowerBiMIP runs in MATLAB on top of YALMIP and an external mixed-integer linear programming (MILP) solver.

## Requirements

- **MATLAB** R2019b or newer.
- **YALMIP**, a current version from the [YALMIP GitHub repository](https://github.com/yalmip/YALMIP).
- **A MILP solver** supported by YALMIP: Gurobi, CPLEX, COPT or MOSEK.

### Solver choice for academic users in China

Gurobi has discontinued free academic licensing in mainland China, Hong Kong and Macau. For commercial licensing, see the [Gurobi notice](https://support.gurobi.com/hc/en-us/articles/33982552193937-As-a-student-at-a-university-in-China-how-do-I-request-a-Free-Academic-License).

We recommend [COPT](https://www.shanshu.ai/copt) for affected academic users.

````{warning}
Update YALMIP before using COPT. Older versions of YALMIP's COPT interface can silently drop a quadratic objective while still reporting a successful solve. Updating COPT alone does not fix this; use the current YALMIP `develop` branch, where `solvers/yalmip2copt.m` contains the fix.

Restart MATLAB after updating. Then run this command to confirm that the updated interface is first on the path.

```matlab
which yalmip2copt -all
```
````

Purely linear MILPs are not affected by this bug. The README describes the [technical details](https://github.com/GreatTM/PowerBiMIP#important-update-yalmip-before-using-copt).

## Install PowerBiMIP

### 1. Clone the repository

Clone with Git or [GitHub Desktop](https://desktop.github.com/).

```bash
git clone https://github.com/GreatTM/PowerBiMIP.git
```

### 2. Add PowerBiMIP to the MATLAB path

From the folder that contains the cloned `PowerBiMIP` directory, run these commands in MATLAB.

```matlab
cd PowerBiMIP/matlab
install
```

The installer adds `config`, `examples` and `src` to the MATLAB path, removes stale entries from older repository layouts and saves the path.

If MATLAB cannot save the path (for example, when it is installed under `C:\Program Files`), it warns that the path will be lost on restart. Make `pathdef.m` writable, or run MATLAB once as administrator, then run `install` again.

### 3. Verify the installation

From the `matlab` folder, run the first toy example:

```matlab
run('examples/BiMIP_benchmarks/BiMIP_toy_example1.m');
```

The script uses Gurobi by default. If you use another solver, change `'solver', 'gurobi'` in the script to `'cplex'`, `'copt'` or `'mosek'`.

With the default solver, the example converges in three iterations and prints the following summary.

```text
Objective value: -22.0000
Best bound:      -22.0000
Gap:             0.00%
```

## Updating

Run `git pull` from the repository root. In GitHub Desktop, select **Fetch origin**, then **Pull origin** if updates are available. If an update moves or renames folders, run `install` once more from the `matlab` folder and restart MATLAB.
