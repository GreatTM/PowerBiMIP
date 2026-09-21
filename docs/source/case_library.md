# Case Library

Explore applications of bilevel optimization and two-stage robust optimization in power and energy systems. All examples below are included in the `matlab/examples/` directory.

## RTS-96 Vulnerability Analysis

The `matlab/examples/Vulnerability_Analysis` folder contains the RTS-96
transmission-line interdiction case. It includes:

- MATLAB data/model builders for the Zhao-Zeng RTS-96 benchmark.
- A compact demo entry point: `main_Vulnerability_Analysis.m`.
- Exported MibS MPS/AUX/PAR instances under `mibs`.

After [installation](installation.md), run the demo from the repository's `matlab/` folder:

```matlab
run('examples/Vulnerability_Analysis/main_Vulnerability_Analysis.m');
```

## Robust Dispatch of Integrated Energy Systems

The `matlab/examples/TRO-IES` case models two-stage adaptive robust dispatch under electricity-load and outdoor-temperature uncertainty. The C&CG subproblem is formulated as a bilevel mixed-integer program.

Run from the `matlab/` folder:

```matlab
run('examples/TRO-IES/TRO_IES_example.m');
```

[Read the model description](https://github.com/GreatTM/PowerBiMIP/tree/main/matlab/examples/TRO-IES)

## Prediction and Decision Making

The `matlab/examples/SPO` case connects prediction with unit commitment. Upper-level decisions adjust the prediction model; the lower level optimizes day-ahead unit commitment using those predictions.

[Explore the SPO case and its model](https://github.com/GreatTM/PowerBiMIP/tree/main/matlab/examples/SPO)

## Bilevel Benchmarks

Start with the small examples in `matlab/examples/BiMIP_benchmarks/` to learn the modeling interface before moving to larger systems. The [Getting Started tutorial](getting_started.md) walks through the first toy model.
