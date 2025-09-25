# Getting Started

This tutorial provides a step-by-step guide to modeling and solving a bilevel mixed-integer programming (BiMIP) problem using PowerBiMIP. By the end of this guide, you'll understand the basic workflow and be able to apply it to your own optimization problems.

## Installation

Before we begin, please make sure you have successfully installed PowerBiMIP and its dependencies (MATLAB, YALMIP, and a MILP solver like Gurobi). If you haven't, please follow the instructions on the **[Installation](installation.md)** page.

---

## A Simple Bilevel Programming Example

Let's start with a classic textbook example of a BiMIP problem. This will help us illustrate the core components of a PowerBiMIP model. The full script for this example can be found in `examples/toy_examples/BiMIP_toy_example1.m`.

### 1. Mathematical Formulation

The problem is composed of two levels: an upper-level problem and a lower-level problem. The decision variables of the upper level affect the constraints of the lower level, and the solution of the lower level, in turn, influences the upper level's objective function.

* **Upper-Level Problem:** The leader's goal is to minimize its objective function by choosing the variable `x`.
    ```
    min_{x}   -x - 10*z
    s.t.
          x >= 0
          -25*x + 20*z <= 30
          x   + 2*z  <= 10
          2*x - z    <= 15
          2*x + 10*z >= 15
    ```

* **Lower-Level Problem:** The follower's problem is to minimize its objective by choosing variables `y` and `z`, given the upper-level decision `x`.
    ```
    min_{y,z}   z + 1000 * sum(y)
    s.t.
          -25*x + 20*z <= 30 + y(1)
          x   + 2*z  <= 10 + y(2)
          2*x - z    <= 15 + y(3)
          2*x + 10*z >= 15 - y(4)
          z >= 0
          y >= 0
    ```

### 2. MATLAB Implementation with PowerBiMIP

Now, let's translate this mathematical model into MATLAB code using PowerBiMIP.

#### Step 1: Initialization

It's good practice to start with a clean slate. This command clears the MATLAB workspace, closes all figures, clears the command window, and resets YALMIP's internal memory.

```matlab
clear; close all; clc; yalmip('clear');
```

#### Step 2: Define Variables

We use YALMIP's syntax to define the decision variables. `intvar` is used for integer variables and `sdpvar` for continuous variables.

```matlab
model.var.x = intvar(1,1,'full'); % Upper-level integer variable
model.var.z = intvar(1,1,'full'); % Lower-level integer variable
model.var.y = sdpvar(4,1,'full'); % Lower-level continuous variables
````

#### Step 3: Formulate the Model

Next, we define the constraints and objective functions for both levels. The constraints are created as standard YALMIP objects.

  * **Upper-Level Constraints & Objective:**

<!-- end list -->

```matlab
% --- Upper-Level Constraints ---
model.constraints_upper = [];
model.constraints_upper = model.constraints_upper + (model.var.x >= 0);
model.constraints_upper = model.constraints_upper + (-25 * model.var.x + 20 * model.var.z <= 30);
model.constraints_upper = model.constraints_upper + (model.var.x + 2 * model.var.z <= 10);
model.constraints_upper = model.constraints_upper + (2 * model.var.x - model.var.z <= 15);
model.constraints_upper = model.constraints_upper + (2 * model.var.x + 10 * model.var.z >= 15);

% --- Upper-Level Objective ---
model.objective_upper = -model.var.x - 10 * model.var.z;
```

  * **Lower-Level Constraints & Objective:**

<!-- end list -->

```matlab
% --- Lower-Level Constraints ---
model.constraints_lower = [];
model.constraints_lower = model.constraints_lower + (-25 * model.var.x + 20 * model.var.z <= 30 + model.var.y(1,1) );
model.constraints_lower = model.constraints_lower + (model.var.x + 2 * model.var.z <= 10 + model.var.y(2,1) );
model.constraints_lower = model.constraints_lower + (2 * model.var.x - model.var.z <= 15 + model.var.y(3,1) );
model.constraints_lower = model.constraints_lower + (2 * model.var.x + 10 * model.var.z >= 15 - model.var.y(4,1) );
model.constraints_lower = model.constraints_lower + (model.var.z >= 0);
model.constraints_lower = model.constraints_lower + (model.var.y >= 0);

% --- Lower-Level Objective ---
model.objective_lower = model.var.z + 1e3 * sum(model.var.y,'all');
```

#### Step 4: Define Variable Sets

PowerBiMIP requires the user to explicitly categorize the variables into four sets: upper-level continuous (`var_xu`), upper-level integer (`var_zu`), lower-level continuous (`var_xl`), and lower-level integer (`var_zl`). This allows the solver to correctly understand the model's structure.

**Important**: All variable sets must be formatted as N x 1 column vectors. You can use `reshape(var, [], 1)` to ensure this.

```matlab
model.var_xu = []; % Upper-level continuous variables (none in this model)
model.var_zu = [reshape(model.var.x, [], 1)]; % Upper-level integer variables
model.var_xl = [reshape(model.var.y, [], 1)]; % Lower-level continuous variables
model.var_zl = [reshape(model.var.z, [], 1)]; % Lower-level integer variables
```

#### Step 5: Configure and Run the Solver

Finally, we configure the solver settings using `BiMIPsettings` and then call the main solver function `solve_BiMIP`.

  * `perspective`: Set to `'optimistic'` for this problem.
  * `method`: We use the `'exact_KKT'` method, which is an exact algorithm. （You can also try `'exact_strong_duality'` or `'quick'`）
  * `solver`: We specify `'gurobi'` as our underlying MILP solver.
  * `verbose`: A setting of `2` provides detailed solver output.

<!-- end list -->

```matlab
% Configure solver settings
ops = BiMIPsettings( ...
    'perspective', 'optimistic', ...
    'method', 'exact_KKT', ...
    'solver', 'gurobi', ...
    'verbose', 2 ...
    );

% Call the solver
[Solution, BiMIP_record] = solve_BiMIP(model.var, ...
    model.var_xu, model.var_zu, model.var_xl, model.var_zl, ...
    model.constraints_upper, model.constraints_lower, ...
    model.objective_upper, model.objective_lower, ops);
```

### 3\. Understanding the Results

After running the script, PowerBiMIP will return two main outputs:

  * **`Solution`**: A structure containing the optimal values of the variables and the objective functions. For this example, the optimal solution is **x = 2**, **z = 2**, resulting in an upper-level objective value of **-22**.
  * **`BiMIP_record`**: A structure that records detailed information about the solution process, such as solving time and algorithm iterations, which is useful for analysis and debugging.

-----

## Next Steps

Congratulations\! 🎉 You've successfully solved your first bilevel problem with PowerBiMIP.

From here, you can:

  * Explore other examples in the `/examples` folder.
  * Learn about more advanced features from [Github](https://github.com/GreatTM/PowerBiMIP).
  * Apply PowerBiMIP to your own research problems in power and energy systems.