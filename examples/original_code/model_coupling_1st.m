function model_coupling_1st(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Model coupling relationship');
    t0 = clock;
end
%%
global data var_1st model;
%%
num_scenario = length(model.uncertainty_set);
num_start = data.num_initialtime+1;
num_end = data.num_initialtime + ...
    data.period*data.interval.electricity/data.interval.heat;
for k = 1:num_scenario
%% h_souce
model.main_problem.cons = model.main_problem.cons + ( ...
    (var_1st.recourse(k).gt.h + var_1st.recourse(k).eb.h + ...
    sum(var_1st.base.tst.h_dis,2) - sum(var_1st.base.tst.h_chr,2) == ...
    var_1st.recourse(k).heatingnetwork.h_source(num_start:num_end,1)) : ...
    'h balance between eps and heating network'); %#ok<*BDSCA>

%% h_load
model.main_problem.cons = model.main_problem.cons + ( ...
    (var_1st.recourse(k).heatingnetwork.h_load(num_start:num_end,:) == ...
    var_1st.recourse(k).building.h_load) : ...
    'h balance between heating network and buildings');
end

%%
if DisplayTime
    t1 = clock;
    fprintf('%8.2f%s\n', etime(t1,t0), 's');
end
end