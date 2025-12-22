# TRO-IES Example

This directory contains the refactored code for the Two-Stage Robust Optimization (TRO) problem of an Integrated Energy System (IES), migrated from `examples/original_code/` to use the PowerBiMIP `solve_Robust` interface.

## Files

- **TRO_IES_example.m**: Main script that sets up and solves the TRO-IES problem
- **readData.m**: Data reading function (refactored from `ReadData.m`, global removed)
- **initializeParameters.m**: Parameter initialization (refactored from `myIntialize.m`, global removed)
- **calculateBuildingParameters.m**: Building parameter calculation (refactored from `cal_buildingParam.m`, global removed)
- **defineBaseVars.m**: First-stage variable definitions (refactored from `define_baseVars.m`, global removed)
- **defineSubProblemVars.m**: Second-stage and uncertainty variable definitions (refactored from `define_subProblemVars.m`, global removed)
- **defineFirstStageConstraints.m**: First-stage constraint definitions (extracted from `model_grid_1st.m`, `model_heatingnetwork_1st.m`, `model_building_1st.m`)
- **defineSecondStageConstraints.m**: Second-stage constraint definitions (extracted from `model_grid_2st.m`, `model_heatingwork_2st.m`, `model_building_2st.m`, `model_coupling_1st.m`)
- **defineUncertaintyConstraints.m**: Uncertainty set constraint definitions (extracted from `define_uncertaintyParam.m`)

## Status

This is a **work-in-progress** implementation. The following components are complete:

✅ Data reading and initialization (global variables removed)  
✅ Variable definitions (first-stage, second-stage, uncertainty)  
✅ Uncertainty set constraints  
✅ Basic first-stage constraints (ES, TST, cost)  
✅ Basic second-stage constraints (uncertainty in RES/load, coupling)  
✅ Objective functions  
✅ Main program structure and `solve_Robust` interface call  

## Remaining Work

The constraint definitions are **incomplete**. The original code contains very complex constraint definitions spread across multiple files. Users need to extract and adapt the following constraints:

### First-Stage Constraints (to be added to `defineFirstStageConstraints.m`):
- PCC constraints (from `model_grid_1st.m`, `model_pcc` function)
- GT device constraints (from `model_grid_1st.m`, `model_device` function)
- EB device constraints (from `model_grid_1st.m`, `model_device` function)
- RES device constraints (from `model_grid_1st.m`, `model_device` function)
- Heating network constraints (from `model_heatingnetwork_1st.m`)
- Building constraints (from `model_building_1st.m`)

### Second-Stage Constraints (to be added to `defineSecondStageConstraints.m`):
- Power flow constraints (from `model_grid_2st.m`, `model_distflow` function)
- Bus balance constraints (from `model_grid_2st.m`, `model_distflow` function)
- Voltage constraints (from `model_grid_2st.m`, `model_distflow` function)
- Device constraints (from `model_grid_2st.m`, `model_device` function)
- Heating network dynamics (from `model_heatingwork_2st.m`)
- Building thermal dynamics (from `model_building_2st.m`)
- Temperature constraints (from `model_building_2st.m`)

**Important**: When extracting constraints from the original code:
1. Remove all `global` variable declarations
2. Pass data and variables as function parameters
3. Convert uncertainty parameters from numerical values (`model.uncertainty_set(k).*`) to variable expressions (`var_u.*`)
4. Replace `var_1st.recourse(k).*` with `var.primal.*` (since we don't use recourse variables in the new structure)
5. Replace `var_1st.base.*` with `var.base.*`

## Usage

1. Ensure the original data file `testdata_33bus.xlsx` is in the `examples/original_code/` directory (or update the path in `readData.m`)
2. Run `TRO_IES_example.m`
3. The script will:
   - Read data and initialize parameters
   - Define variables
   - Define constraints (currently incomplete)
   - Define objectives
   - Call `solve_Robust` to solve the problem
   - Display results

## Notes

- All `global` variables have been removed
- Variable naming follows the original code structure (`var.base.*`, `var.primal.*`)
- Constraints and objectives are organized as `model.cons_1st`, `model.cons_2nd`, `model.cons_uncertainty`, `model.obj_1st`, `model.obj_2nd`
- Initial scenario sets all uncertainty deviations to 0 (as required)
- The code follows the principle of reusing original code segments with minimal modifications

