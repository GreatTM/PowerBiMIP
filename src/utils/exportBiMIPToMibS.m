function meta = exportBiMIPToMibS(bimip_model, case_name, output_dir, varargin)
%EXPORTBIMIPTOMIBS Export a PowerBiMIP model to MibS MPS/AUX/PAR files.
%
% The MPS file is the high-point relaxation: all upper/lower variables and
% constraints with the upper objective. The AUX file uses MibS name-based
% format to mark lower-level variables, constraints, and objective
% coefficients.

p = inputParser;
addParameter(p, 'solver', 'gurobi');
addParameter(p, 'time_limit', []);
parse(p, varargin{:});
params = p.Results;

if nargin < 3 || isempty(output_dir)
    output_dir = pwd;
end
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

case_name = char(case_name);
mps_path = fullfile(output_dir, [case_name '.mps']);
aux_path = fullfile(output_dir, [case_name '.aux']);
par_path = fullfile(output_dir, [case_name '.par']);

all_vars = unique([getvariables(bimip_model.cons_lower), ...
                   getvariables(bimip_model.cons_upper), ...
                   getvariables(bimip_model.obj_upper), ...
                   getvariables(bimip_model.obj_lower)]);
all_vars = sort(all_vars(:).');
lower_vars_idx = unique(get_vars_recursive(bimip_model.var_lower));

ops = sdpsettings('verbose', 0, 'solver', params.solver);
if strcmpi(params.solver, 'gurobi')
    ops.gurobi.ResultFile = mps_path;
    if ~isempty(params.time_limit)
        ops.gurobi.TimeLimit = params.time_limit;
    end
end

solution = optimize(bimip_model.cons_lower + bimip_model.cons_upper, bimip_model.obj_upper, ops);
if ~isfile(mps_path)
    error('PowerBiMIP:MibSExport', 'MPS export failed; file not found: %s', mps_path);
end

file_content = fileread(mps_path);
file_content = regexprep(file_content, '^NAME\s+\S+', ['NAME          ' case_name], 'once', 'lineanchors');
fid = fopen(mps_path, 'w');
if fid == -1
    error('PowerBiMIP:MibSExport', 'Could not rewrite MPS file: %s', mps_path);
end
fprintf(fid, '%s', file_content);
fclose(fid);

lower_obj_base = getbase(bimip_model.obj_lower);
lower_obj_vars = getvariables(bimip_model.obj_lower);
coeff_map = containers.Map('KeyType', 'double', 'ValueType', 'double');
for k = 1:numel(lower_obj_vars)
    coeff_map(lower_obj_vars(k)) = lower_obj_base(k + 1);
end

exported_lower = export(bimip_model.cons_lower);
num_lower_rows = size(exported_lower.A, 1);

fid = fopen(aux_path, 'w');
if fid == -1
    error('PowerBiMIP:MibSExport', 'Could not create AUX file: %s', aux_path);
end

lower_mask = ismember(all_vars, lower_vars_idx);
fprintf(fid, '@NUMVARS\n%d\n', nnz(lower_mask));
fprintf(fid, '@NUMCONSTRS\n%d\n', num_lower_rows);
fprintf(fid, '@VARSBEGIN\n');
for i = 1:numel(all_vars)
    if ~lower_mask(i)
        continue;
    end
    var_id = all_vars(i);
    if isKey(coeff_map, var_id)
        coeff = coeff_map(var_id);
    else
        coeff = 0;
    end
    fprintf(fid, 'C%d %s\n', i - 1, format_number(coeff));
end
fprintf(fid, '@VARSEND\n');
fprintf(fid, '@CONSTRSBEGIN\n');
for row = 0:(num_lower_rows - 1)
    fprintf(fid, 'R%d\n', row);
end
fprintf(fid, '@CONSTRSEND\n');
fprintf(fid, '@NAME\n%s\n', case_name);
fprintf(fid, '@MPS\n%s\n', [case_name '.mps']);
fclose(fid);

fid = fopen(par_path, 'w');
if fid == -1
    error('PowerBiMIP:MibSExport', 'Could not create PAR file: %s', par_path);
end
fprintf(fid, 'Alps_instance %s\n', [case_name '.mps']);
fprintf(fid, 'MibS_auxiliaryInfoFile %s\n', [case_name '.aux']);
if ~isempty(params.time_limit)
    fprintf(fid, 'Alps_timeLimit %g\n', params.time_limit);
end
fprintf(fid, 'Alps_msgLevel 1\n');
fprintf(fid, 'MibS_inputFormat 0\n');
fclose(fid);

meta = struct();
meta.case_name = case_name;
meta.output_dir = output_dir;
meta.mps_path = mps_path;
meta.aux_path = aux_path;
meta.par_path = par_path;
meta.num_all_vars = numel(all_vars);
meta.num_lower_vars = nnz(lower_mask);
meta.num_lower_constraints = num_lower_rows;
meta.export_status = solution.problem;
meta.export_status_text = yalmiperror(solution.problem);
end

function indices = get_vars_recursive(obj)
indices = [];
if isa(obj, 'sdpvar')
    indices = getvariables(obj);
elseif isstruct(obj)
    fields = fieldnames(obj);
    for i = 1:numel(fields)
        indices = [indices, get_vars_recursive(obj.(fields{i}))]; %#ok<AGROW>
    end
elseif iscell(obj)
    for i = 1:numel(obj)
        indices = [indices, get_vars_recursive(obj{i})]; %#ok<AGROW>
    end
end
indices = unique(indices);
end

function txt = format_number(value)
if abs(value - round(value)) < 1e-12
    txt = sprintf('%d.', round(value));
else
    txt = sprintf('%.12g', value);
end
end
