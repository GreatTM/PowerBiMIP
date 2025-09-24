# Installation

Follow these steps to get PowerBiMIP up and running in your MATLAB environment.

## 1. Prerequisites

Before installing PowerBiMIP, please ensure you have the following dependencies correctly installed and configured.

* **MATLAB**: **R2018a** or a newer version is required.
* **YALMIP**: The latest version is strongly recommended. YALMIP is a free MATLAB toolbox for modeling and optimization. You can download it from the [YALMIP GitHub repository](https://github.com/yalmip/YALMIP). Follow their instructions for installation.
* **A MILP Solver**: PowerBiMIP requires at least one efficient Mixed-Integer Linear Programming (MILP) solver. We highly recommend **Gurobi** for its exceptional performance and robustness. Other supported solvers include **CPLEX**, **COPT**, and **MOSEK**. Ensure your chosen solver is installed and its MATLAB interface is correctly set up.

## 2. Install PowerBiMIP

Once the prerequisites are in place, you can install PowerBiMIP.

* **Step 1: Download the Toolbox**
    Clone or download the PowerBiMIP repository from GitHub:
    [https://github.com/GreatTM/PowerBiMIP](https://github.com/GreatTM/PowerBiMIP)

* **Step 2: Add to MATLAB Path**
    Add the PowerBiMIP root folder and all its subfolders to your MATLAB path. This ensures that MATLAB can find all the necessary functions.

    Navigate to the PowerBiMIP root directory in the MATLAB Command Window and run the following command:
    ```matlab
    addpath(genpath(pwd));
    ```
    Alternatively, you can use the "Set Path" dialog in the MATLAB "Home" tab and add the PowerBiMIP folder with its subfolders.

## 3. Verify the Installation

To confirm that PowerBiMIP and all its dependencies are working correctly, run one of the provided examples.

In the MATLAB Command Window, run the following script:
```matlab
run('examples/toy_examples/BiMIP_toy_example1.m');
```
If the script runs without errors and outputs a solution, your installation is successful. Congratulations! You are now ready to use PowerBiMIP.

If you encounter any issues, please double-check that all prerequisites are correctly installed and on the MATLAB path. If problems persist, feel free to open an issue on [Github](https://github.com/GreatTM/PowerBiMIP/issues)