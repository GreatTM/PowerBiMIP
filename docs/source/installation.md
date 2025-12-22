# Installation

This guide will help you install PowerBiMIP and get it ready for use in MATLAB.

## Prerequisites

Before installing PowerBiMIP, ensure you have the following dependencies installed:

1.  **MATLAB**: R2018a or newer.
2.  **YALMIP**: The latest version is highly recommended. You can download it from the [YALMIP GitHub repository](https://github.com/yalmip/YALMIP).
3.  **A MILP Solver**: At least one MILP solver is required. We strongly recommend **Gurobi** for its performance and robustness. Other supported solvers include CPLEX, COPT, and MOSEK.

## Installation Steps

We recommend using **GitHub Desktop** or `git` command line to install PowerBiMIP. This ensures you can easily receive the latest updates.

### 1. Clone the Repository

Choose one of the following methods to download the source code:

*   **Option A: Using GitHub Desktop (Recommended)**
    1.  Open GitHub Desktop.
    2.  Go to `File` > `Clone repository`.
    3.  Enter the repository URL: `https://github.com/GreatTM/PowerBiMIP`.
    4.  Choose a local path and click **Clone**.

*   **Option B: Using Git Command Line**
    Run the following command in your terminal:
    ```bash
    git clone https://github.com/GreatTM/PowerBiMIP.git
    ```

### 2. Run the Installer

1.  Open **MATLAB**.
2.  Navigate to the **PowerBiMIP root directory** (the folder you just cloned).
3.  In the MATLAB Command Window, type the following command and press Enter:
    ```matlab
    install
    ```
4.  The script will automatically add all necessary folders (`src`, `config`, `examples`) to your MATLAB path.

### 3. Verify Installation

To confirm that PowerBiMIP is correctly installed and configured, run one of the included toy examples:

```matlab
run('examples/BiMIP_benchmarks/BiMIP_toy_example1.m');
```

If the solver runs and produces an optimal solution, you are all set!

## Keeping Up to Date

To update PowerBiMIP to the latest version:
1.  **Pull changes**: Click "Fetch origin" in GitHub Desktop or run `git pull` in your terminal.
2.  **Restart MATLAB**: This ensures all changes are reloaded.
