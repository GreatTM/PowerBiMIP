# PowerBiMIP: Bilevel Mixed-Integer Programming for Power Systems

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/GreatTM/PowerBiMIP)](https://github.com/GreatTM/PowerBiMIP/releases)
[![View on GitHub](https://img.shields.io/badge/View%20on-GitHub-blue?logo=GitHub)](https://github.com/GreatTM/PowerBiMIP)
[![Official Website](https://img.shields.io/badge/Website-docs.powerbimip.com-green)](https://docs.powerbimip.com)

**PowerBiMIP** is an open-source, efficient MATLAB toolbox for modeling and solving bilevel mixed-integer programming (BiMIP) problems, with a special focus on applications in power and energy systems.

## Overview

PowerBiMIP provides a user-friendly framework to formulate complex bilevel optimization problems involving both continuous and integer variables at both the upper and lower levels.

The toolbox currently supports:
* Bilevel Mixed-Integer Programs (BiMIP).
* Automatically converts user-input models into standard-form BiMIP, allowing users to focus on model construction.
* Automatically transforms BiMIP with coupling constraints into BiMIP without coupling constraints.
* Optimistic solution perspectives. (The pessimistic perspective is comming soon)
* Multiple solution methods, including exact mode and quick mode.

### Quick Start Example

Let's walk through a simple example to illustrate how to use PowerBiMIP. The following problem is defined in `examples/toy_examples/BiMIP_toy_example1.m`.

**Mathematical Formulation:**

* **Upper-Level Problem:**
    ```
    min_{x}  -x - 10*z
    s.t.
        x >= 0
        -25*x + 20*z <= 30
        x   + 2*z  <= 10
        2*x - z    <= 15
        2*x + 10*z >= 15
    ```

* **Lower-Level Problem:**
    Where `z` is determined by the solution of:
    ```
    min_{y,z}  z + 1000 * sum(y)
    s.t.
        -25*x + 20*z <= 30 + y(1)
        x   + 2*z  <= 10 + y(2)
        2*x - z    <= 15 + y(3)
        2*x + 10*z >= 15 - y(4)
        z >= 0
        y >= 0
    ```

**MATLAB Implementation:**

To ensure compatibility with the toolbox's internal matrix operations, please adhere to the following input specifications:
* **Variables**: All variable sets (`var_xu`, `var_zu`, `var_xl`, `var_zl`) passed to the solver must be formatted as N x 1 column vectors. You can use `reshape(var, [], 1)` to achieve this.
* **Constraints & Objectives**: The constraint sets and objective functions must be standard YALMIP objects.
* **Problem Type**: Currently, PowerBiMIP officially supports **Bilevel Mixed-Integer Linear Programs**. Support for quadratic terms is under development.

Here is the code to model and solve this problem using PowerBiMIP.

```matlab
% 1. Initialization
clear; close all; clc; yalmip('clear');

% 2. Variable Definition using YALMIP
model.var.x = intvar(1,1,'full'); % Upper-level integer variable
model.var.z = intvar(1,1,'full'); % Lower-level integer variable
model.var.y = sdpvar(4,1,'full'); % Lower-level continuous variables

% 3. Model Formulation
% --- Upper-Level Constraints ---
model.constraints_upper = [];
model.constraints_upper = model.constraints_upper + (model.var.x >= 0);
model.constraints_upper = model.constraints_upper + (-25 * model.var.x + 20 * model.var.z <= 30);
model.constraints_upper = model.constraints_upper + (model.var.x + 2 * model.var.z <= 10);
model.constraints_upper = model.constraints_upper + (2 * model.var.x - model.var.z <= 15);
model.constraints_upper = model.constraints_upper + (2 * model.var.x + 10 * model.var.z >= 15);

% --- Lower-Level Constraints ---
model.constraints_lower = [];
model.constraints_lower = model.constraints_lower + (-25 * model.var.x + 20 * model.var.z <= 30 + model.var.y(1,1) );
model.constraints_lower = model.constraints_lower + (model.var.x + 2 * model.var.z <= 10 + model.var.y(2,1) );
model.constraints_lower = model.constraints_lower + (2 * model.var.x - model.var.z <= 15 + model.var.y(3,1) );
model.constraints_lower = model.constraints_lower + (2 * model.var.x + 10 * model.var.z >= 15 - model.var.y(4,1) );
model.constraints_lower = model.constraints_lower + (model.var.z >= 0);
model.constraints_lower = model.constraints_lower + (model.var.y >= 0);

% --- Objective Functions ---
model.objective_upper = -model.var.x - 10 * model.var.z;
model.objective_lower = model.var.z + 1e3 * sum(model.var.y,'all');

% 4. Define Variable Sets for the Solver
model.var_xu = []; % Upper-level continuous variables
model.var_zu = [reshape(model.var.x, [], 1)]; % Upper-level integer variables
model.var_xl = [reshape(model.var.y, [], 1)]; % Lower-level continuous variables
model.var_zl = [reshape(model.var.z, [], 1)]; % Lower-level integer variables

% 5. Configure and Run the Solver
ops = BiMIPsettings( ...
    'perspective', 'optimistic', ...
    'method', 'exact_KKT', ...
    'solver', 'gurobi', ...
    'verbose', 2 ...
    );
[Solution, BiMIP_record] = solve_BiMIP(model.var, ...
    model.var_xu, model.var_zu, model.var_xl, model.var_zl, ...
    model.constraints_upper, model.constraints_lower, ...
    model.objective_upper, model.objective_lower, ops);
```
Running this script will solve the problem and return the optimal solution, which is $x = 2$, $z = 2$, with an upper-level objective of $-22$.

## Installation

### Prerequisites
Before installing PowerBiMIP, ensure you have the following dependencies installed:

1.  **MATLAB**: R2018a or newer.
2.  **YALMIP**: The latest version is highly recommended. You can download it from the [YALMIP GitHub repository](https://github.com/yalmip/YALMIP).
3.  **A MILP Solver**: At least one MILP solver is required. We strongly recommend **Gurobi** for its performance and robustness. Other supported solvers include CPLEX\COPT\MOSEK.

### Installation Steps

1.  **Download PowerBiMIP**: Clone or download the repository from [https://github.com/GreatTM/PowerBiMIP](https://github.com/GreatTM/PowerBiMIP).
2.  **Add to MATLAB Path**: Add the PowerBiMIP root folder and its subfolders to your MATLAB path. You can do this by running the following command in the MATLAB console from the PowerBiMIP root directory:
    ```matlab
    addpath(genpath(pwd));
    ```
    Alternatively, you can use the "Set Path" dialog in the MATLAB environment.
3.  **Verify Installation**: Run one of the toy examples to ensure that PowerBiMIP and all its dependencies are correctly configured.
    ```matlab
    run('examples/toy_examples/BiMIP_toy_example1.m');
    ```

## Documentation

For detailed documentation, including tutorials, advanced examples, and API references, please visit our official website:

**[https://docs.powerbimip.com](https://docs.powerbimip.com)**

## Development Status & Contribution

PowerBiMIP is under active development. As an early-stage project, it may have known or potential bugs, and some features are still being improved. We are committed to long-term maintenance and plan to release a major update annually and minor updates monthly.

We highly welcome feedback and contributions from the community! If you have any feature requests or encounter a bug, please feel free to:
* Contact Yemin Wu directly via email: [yemin.wu@seu.edu.cn](mailto:yemin.wu@seu.edu.cn)
* Open an issue on our [GitHub Issues page](https://github.com/GreatTM/PowerBiMIP/issues).

## Acknowledgements

This work is performed under the supervision of **Prof. Shuai Lu** at Southeast University.

We extend our sincere gratitude to **Prof. Bo Zeng** from the University of Pittsburgh for his significant support. The algorithms implemented in our `exact_mode` are based on his pioneering research:
* [1] Zeng, Bo, and Yu An. "Solving bilevel mixed integer program by reformulations and decomposition." *Optimization online* (2014): 1-34.
* [2] Zeng, Bo. "A practical scheme to compute the pessimistic bilevel optimization problem." *INFORMS Journal on Computing* 32.4 (2020): 1128-1142.

Furthermore, the development of the `quick_mode` algorithm was carefully guided by Prof. Zeng.

We also thank **Dr. Ruizhi Yu** ([@rzyu45](https://github.com/rzyu45)) for his technical support and guidance on the development of the PowerBiMIP documentation website.

## License and Citation

### License

**Copyright © 2024 Yemin Wu (yemin.wu@seu.edu.cn), Southeast University**

This software is provided for academic and non-commercial research purposes only.

* **Permitted Use**: You are granted a non-exclusive, non-transferable license to use, copy, and modify PowerBiMIP for your own academic and non-commercial research.
* **Restrictions**: PowerBiMIP, or any of its forks or derivative versions, may not be redistributed or used as part of a commercial product or service without a separate written agreement with the copyright owner.
* **Disclaimer of Warranty**: PowerBiMIP is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. The user assumes all risks associated with the use of this software. The authors and copyright holders are not liable for any direct or indirect damages that may arise from its use.
* **Distribution**: Any authorized distribution of forks or derivative versions of PowerBiMIP must include this license and adhere to its terms.

### Citation

If you use PowerBiMIP in your research and public presentations, please cite it. This helps us to secure funding and continue developing the toolbox. We will provide a specific citation format once our work is published in a peer-reviewed journal.
