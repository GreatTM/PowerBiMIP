function data = initializeParameters(data, num_initialtime, interval_heat)
%INITIALIZEPARAMETERS Initialize parameters
%
%   This function is refactored from examples/original_code/myIntialize.m
%   with global variables removed.

data.heatingnetwork.initial = [80 55 -10];
data.buildings.limit = [18 24 21];
data.num_initialtime = num_initialtime;
data.interval.heat = interval_heat;

end

