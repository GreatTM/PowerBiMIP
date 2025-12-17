function myIntialize(num_initialtime,interval_heat)
fprintf('%-40s\t\t','- Initialize paramters');
t0 = clock;
global data;
data.heatingnetwork.initial = [80 55 -10];
data.buildings.limit = [18 24 21];
data.num_initialtime = num_initialtime;
data.interval.heat = interval_heat;

t1 = clock;
fprintf('%8.2f%s\n', etime(t1,t0), 's');
end