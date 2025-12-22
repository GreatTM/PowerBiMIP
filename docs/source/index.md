# Welcome to PowerBiMIP's Documentation!

<div class="custom-header">
    <img src="_static/PowerBiMIP_logo.svg" alt="PowerBiMIP Logo">
    <p class="tagline">An open-source, efficient MATLAB toolbox for bilevel mixed-integer programming in power and energy systems.</p>
</div>

**PowerBiMIP** is a powerful, open-source MATLAB toolbox designed for researchers and engineers in the power and energy sector. It provides a user-friendly yet robust framework for modeling and solving complex bilevel mixed-integer programming (BiMIP) problems, which are essential for analyzing hierarchical decision-making processes in modern energy systems.

Whether you are modeling strategic interactions between market participants, planning resilient energy infrastructure, or exploring complex control strategies, PowerBiMIP simplifies the formulation process and provides efficient solution algorithms.

## Core Features

*   **Bilevel Mixed-Integer Programs (BiMIP)**:
    *   Support for continuous and **integer variables** **at both levels**.
    *   Automatic conversion to standard forms.
    *   Handling of coupling constraints.
    *   Optimistic solution perspectives (Pessimistic perspective coming soon).
*   **Two-Stage Robust Optimization (TRO)**:
    * The subproblem of the C&CG procedure is a special BiMIP, thus can be solved by PowerBiMIP efficiently.
    * PowerBiMIP now offers a solver interface specifically designed for two-stage robust optimization requirements (currently supporting only LP recourse scenarios; MIP recourse is coming soon).
*   **Multiple Solution Methods**: Including exact modes (KKT, Strong Duality) and quick modes (Approximately 1-3 orders of magnitude faster than existing global optimal algorithms for BiMIP).
*   **Power and Energy Systems Case Library**: We are actively building a library of benchmark cases for classic BiMIP and TRO problems in power and energy systems, which will be continuously updated and expanded.

## Getting Started

New to PowerBiMIP? The **[Getting Started](getting_started.md)** guide will walk you through solving your first bilevel optimization problem in just a few minutes.

## How to Cite

If you use PowerBiMIP in your academic work, please cite our GitHub repository:

> Y. Wu, "PowerBiMIP: An Open-Source, Efficient Bilevel Mixed-Integer Programming Solver for Power and Energy Systems," GitHub repository, 2025. [Online]. Available: https://github.com/GreatTM/PowerBiMIP

**We will provide a specific citation format once our work is published in a peer-reviewed journal.**

## License & Contribution

PowerBiMIP is available for academic and non-commercial research purposes. For more details, see the **[LICENSE](https://github.com/GreatTM/PowerBiMIP/blob/main/LICENSE)** file.

We welcome community contributions! If you find a bug or have a feature request, please open an issue on our [GitHub Issues page](https://github.com/GreatTM/PowerBiMIP/issues) or contact Yemin Wu at [yemin.wu@seu.edu.cn](mailto:yemin.wu@seu.edu.cn).

```{toctree}
:maxdepth: 2
:caption: Contents:

installation
getting_started