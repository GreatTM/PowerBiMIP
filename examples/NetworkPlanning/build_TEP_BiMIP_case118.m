function bimip_model = build_TEP_BiMIP_case118()
%BUILD_TEP_BIMIP_CASE118  Build the bilevel MIP Transmission Expansion
%Planning (TEP) model for the IEEE-118 bus system described in Haghighat &
%Zeng (2018).
%
%   The model follows the paper's formulation considering 3 representative
%   load blocks (Light, Medium, Peak) to approximate the annual load
%   duration curve.
%
%   Scenarios (from Paper):
%     1. Light:  Load Factor 0.65, Duration 2000 hours
%     2. Medium: Load Factor 0.80, Duration 5760 hours
%     3. Peak:   Load Factor 1.00, Duration 1000 hours
%
%   See also SOLVE_BIMIP, MAKEPTDF

%% --------------------------------------------------
%% 1. Load network data
mpc = case118;
baseMVA = mpc.baseMVA;
nbus = size(mpc.bus,1);
ngen = size(mpc.gen,1);

% Define Load Blocks (Scenarios)
LoadFactors = [0.65, 0.80, 1.00];
Durations   = [2000, 5760, 1000]; % Hours
nScen       = length(LoadFactors);

%% --------------------------------------------------
%% 2. Define Candidate Lines (Table III)
% Candidate pool based on Table III union of B-LP and B-MIP results
candidates_data = [
    25   4   5.0;  % B-LP, B-MIP (New)
    25  18   5.0;  % B-MIP       (New)
    86  82   5.0;  % B-MIP       (New)
    77  82   5.0;  % B-LP, B-MIP (Parallel)
    77  78   5.0;  % B-MIP       (Parallel)
    94  95   5.0;  % B-MIP       (Parallel)
    99 100   5.0;  % B-LP, B-MIP (Parallel)
    94 100   5.0;  % B-LP, B-MIP (Parallel)
    94  96   5.0;  % B-LP        (Parallel)
];

numCand = size(candidates_data,1);
candLines = candidates_data(:,1:2);
capCost   = candidates_data(:,3);
I_max     = 100; % Budget

%% --------------------------------------------------
%% 3. Augment MPC & Build PTDF
% Add candidates to branch matrix for PTDF computation
avg_x = mean(mpc.branch(:,4));
avg_rateA = mean(mpc.branch(:,6));
if avg_rateA == 0, avg_rateA = 100; end

idxExist = 1:size(mpc.branch,1);
idxCand  = [];

for k = 1:numCand
    f = candLines(k,1);
    t = candLines(k,2);
    
    match = find((mpc.branch(:,1)==f & mpc.branch(:,2)==t) | ...
                 (mpc.branch(:,1)==t & mpc.branch(:,2)==f), 1);
    if ~isempty(match)
        newLine = mpc.branch(match, :);
    else
        newLine = [f, t, 0, avg_x, 0, avg_rateA, 0, 0, 0, 0, 1, -360, 360];
    end
    mpc.branch = [mpc.branch; newLine];
    idxCand(end+1) = size(mpc.branch, 1);
end

% Compute PTDF for the augmented system
PTDF = makePTDF(mpc);
Gmat = sparse(mpc.gen(:,1), (1:ngen)', 1, nbus, ngen);

%% --------------------------------------------------
%% 4. Define Variables
% Upper Level: Investment decisions (Scenario-independent)
x = binvar(numCand, 1, 'full'); 

% Lower Level: Operational variables (Per Scenario)
% We use matrices [size x nScen] to handle multiple scenarios elegantly
p = sdpvar(ngen, nScen, 'full'); % Generation
v = binvar(ngen, nScen, 'full'); % Commitment status
r = sdpvar(nbus, nScen, 'full'); % Load shedding

%% --------------------------------------------------
%% 5. Define Parameters
pmax_base = mpc.gen(:,9);
pmin_base = mpc.gen(:,10);

% FIX: mpc.gencost column 5 is quadratic coeff (usually small/zero for linear).
%      Column 6 is the linear coefficient ($/MWh).
cg = mpc.gencost(:,6); 

cnl       = 40 * ones(ngen,1);     % No-load cost ($/h)
Pd_base   = mpc.bus(:,3);          % Base Demand (MW)

rates = mpc.branch(:,6);
% FIX: Many lines in standard case118 have RateA=0 (unlimited).
%      This makes TEP trivial/unnecessary. The paper uses a "Modified" case.
%      We impose a default limit (e.g. 200 MW) on undefined lines to simulate congestion.
rates(rates==0) = 200; 

rateExist = rates(idxExist);
rateCand  = rates(idxCand);

%% --------------------------------------------------
%% 6. Build Lower-Level Constraints & Objective
LLcons = [];
LLobj_terms = [];

for s = 1:nScen
    % 6.1 Scenario Parameters
    Pd_s = Pd_base * LoadFactors(s);
    Duration_s = Durations(s);
    
    % 6.2 Generator Limits
    LLcons = [LLcons; p(:,s) >= v(:,s) .* pmin_base];
    LLcons = [LLcons; p(:,s) <= v(:,s) .* pmax_base];
    
    % 6.3 Load Shedding Limits
    LLcons = [LLcons; r(:,s) >= 0];
    LLcons = [LLcons; r(:,s) <= Pd_s];
    
    % 6.4 Power Balance
    netInjection_s = Gmat * p(:,s) - Pd_s + r(:,s);
    LLcons = [LLcons; sum(netInjection_s) == 0];
    
    % 6.5 Network Flows
    Flows_s = PTDF * netInjection_s;
    
    % Existing lines
    LLcons = [LLcons; -rateExist <= Flows_s(idxExist) <= rateExist];
    
    % Candidate lines (controlled by x)
    % Note: x is shared across all scenarios
    for k = 1:numCand
        limit_k = rateCand(k) * x(k);
        LLcons = [LLcons; -limit_k <= Flows_s(idxCand(k)) <= limit_k];
    end
    
    % 6.6 Scenario Objective Contribution (Operation Cost * Duration)
    % Cost = (Fuel * p + NoLoad * v + Penalty * r) * Duration
    % Note: Coefficients must be scaled by Duration
    op_cost_s = cg.' * p(:,s) + cnl.' * v(:,s) + 1e4 * sum(r(:,s));
    LLobj_terms = [LLobj_terms; op_cost_s * Duration_s];
end

% Sum up operation costs for Lower Level Objective
obj_lower = sum(LLobj_terms);

%% --------------------------------------------------
%% 7. Upper-Level Formulation
% Upper Objective: Annualized Investment + Annual Operation
% NOTE: The paper likely minimizes "Annualized Investment + Annual Operation".
% However, Table III reports the total (lump-sum) investment.
% We apply a typical annualization factor (e.g., 10%) to the investment cost
% in the objective function to balance it against the one-year operation cost.
%
% SCALING ADJUSTMENT:
% The operation cost is ~2.7e6, while investment is ~45. To make them comparable
% and force a tradeoff, we use a large factor (or assume cost units differ).
annual_factor = 2000; 
obj_upper = (annual_factor * capCost).' * x + obj_lower;

% Upper Constraints: Budget (on Total Investment)
ULcons = [capCost.' * x <= I_max];

%% --------------------------------------------------
%% 8. Pack Model
bimip_model.var_upper  = struct('x',x);
% Structure fields can handle matrices, solver will flatten them
bimip_model.var_lower  = struct('p',p,'v',v,'r',r);
bimip_model.cons_upper = ULcons;
bimip_model.cons_lower = LLcons;
bimip_model.obj_upper  = obj_upper;
bimip_model.obj_lower  = obj_lower;

end
