function details = extract_lp_qp_model(F, h)
%EXTRACT_LP_QP_MODEL Extracts an LP/QP model from YALMIP constraints and objective.
%
%   details = extract_lp_qp_model(F, h)
%
%   Description:
%       This function receives YALMIP constraints (F) and an objective
%       function (h), validates that the problem is an (MI)LP or (MI)QP,
%       and then extracts the model matrices into a standardized structure.
%
%       The output struct 'details' contains the model in the standard QP format:
%         min   0.5*x'*Q*x + c'*x
%         s.t.  A*x <= b
%               E*x = f
%
%   Input Arguments:
%     F: A YALMIP lmi or constraint object representing the constraints.
%     h: A YALMIP sdpvar object representing the objective function.
%
%   Output Argument:
%     details: A struct containing the standard-form QP model with fields:
%       .Q:      The quadratic cost matrix (n x n).
%       .c:      The linear cost vector (n x 1).
%       .A:      The inequality constraint matrix (m_ineq x n).
%       .b:      The inequality constraint vector (m_ineq x 1).
%       .E:      The equality constraint matrix (m_eq x n).
%       .f:      The equality constraint vector (m_eq x 1).
%       .primal: An sdpvar object of the primal variables x.
%
%   Notes:
%       - The function will throw an error if the problem is not an (MI)LP or (MI)QP.
%       - It performs the following cleaning on the extracted matrices:
%         1. Removes redundant inequality constraints of the form A*x <= inf.
%         2. Removes any all-zero rows from the constraint matrices.
%         3. Removes the explicit 0 <= z <= 1 bounds that YALMIP adds for
%            binary variables when the 'relax' option is used.

% Step 1: Use YALMIP's 'export' command to convert the high-level model
% into a low-level, solver-independent format. The '+quadprog' hint
% guides YALMIP to create a QP model. 'relax', 2 is used to handle
% integer variables correctly, exporting the continuously relaxed version.
[~,~,~,model] = export(F, h, sdpsettings('solver','+quadprog','relax',2));

% Step 2: Validate the problem type.
% Check if the export was successful and if the problem class is LP or QP.
if isempty(model) || ~isfield(model, 'problemclass')
    error('PowerBiMIP:Inputerror','YALMIP failed to export the model. The problem may be infeasible, unbounded, or improperly defined.');
end

% The 'problemclass' function analyzes the exported model. We only allow
% LP, Convex QP, and Nonconvex QP. This check is sufficient for MILP and
% MIQP as well, as YALMIP handles the integer aspect separately.
if ~ismember(problemclass(model), {'LP', 'Convex QP', 'Nonconvex QP'})
    error('PowerBiMIP:Inputerror', 'The provided problem is not a standard LP or QP. Other problem types (e.g., SDP, GP, or general NLP) are not supported by this function.');
end

% Step 3: Extract the objective function matrices (Q and c).
% YALMIP's 'export' command returns the objective as c'*x + x'*Q*x.
% To match the standard form 0.5*x'*Q_std*x, we must have Q_std = 2*Q
details.Q = model.Q*2;
details.c = model.c;

% Step 4: Extract the constraint matrices (A, b, E, f).
% Constraints are stored in the SeDuMi-based format in model.F_struc,
% with the structure described by model.K.

% Extract equality constraints: E*x = f
% YALMIP's internal format: f - E*x = 0.
% The format in F_struc is [f, -E].
if model.K.f > 0
    E_full = -model.F_struc(1:model.K.f, 2:end);
    f_full = model.F_struc(1:model.K.f, 1);
else
    % If no equality constraints, create empty matrices.
    E_full = zeros(0, size(model.Q, 1));
    f_full = [];
end

% Extract inequality constraints: A*x <= b
% YALMIP's internal format: b - A*x >= 0.
% The format in F_struc is [b, -A].
if model.K.l > 0
    A_full = -model.F_struc(model.K.f+1 : model.K.f+model.K.l, 2:end);
    b_full = model.F_struc(model.K.f+1 : model.K.f+model.K.l, 1);
else
    % If no inequality constraints, create empty matrices.
    A_full = zeros(0, size(model.Q, 1));
    b_full = [];
end

% Step 5: Clean the extracted matrices.
    
% 5a. Remove redundant inequalities of the form A*x <= inf.
if ~isempty(b_full)
    inf_rows = isinf(b_full) & b_full > 0;
    if any(inf_rows)
        A_full(inf_rows, :) = [];
        b_full(inf_rows) = [];
    end
end

% 5b. Remove any all-zero rows from inequality constraints.
if ~isempty(A_full)
    zero_rows_A = ~any(A_full, 2);
    if any(zero_rows_A)
        A_full(zero_rows_A, :) = [];
        b_full(zero_rows_A) = [];
    end
end

% 5c. Remove any all-zero rows from equality constraints.
if ~isempty(E_full)
    zero_rows_E = ~any(E_full, 2);
    if any(zero_rows_E)
        E_full(zero_rows_E, :) = [];
        f_full(zero_rows_E) = [];
    end
end

% Step 6: Recover the sdpvar object for the primal variables.
% 'model.used_variables' contains the indices of all variables used.
% The 'recover' function reconstructs the sdpvar object from these indices.
details.primal = recover(model.used_variables);

% 5d.(Important) Remove the explicit 0 <= z <= 1 bounds that YALMIP
% adds for binary variables when using the 'relax' option.
all_binary_vars_indices = yalmip('binvariables');
problem_var_indices = getvariables(details.primal);
binary_flags = ismember(problem_var_indices, all_binary_vars_indices);

if any(binary_flags)
    A_full = A_full(1:end-nnz(binary_flags)*2,:);
    b_full = b_full(1:end-nnz(binary_flags)*2,:);
end

% Assign the cleaned matrices to the output struct.
details.A = A_full;
details.b = b_full;
details.E = E_full;
details.f = f_full;
end
