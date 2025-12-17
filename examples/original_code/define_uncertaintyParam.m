function define_uncertaintyParam(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','- Difine uncertainty parameters');
    t0 = clock;
end
%% 
global data;
data.uncertainty.Deviation.p_res = varargin{1};
data.uncertainty.Deviation.p_load = varargin{2};
data.uncertainty.Deviation.Tau_out = varargin{3};
data.uncertainty.Deviation.Tau_act = varargin{4};
data.uncertainty.Gamma.p_res = varargin{5};
data.uncertainty.Gamma.p_load = varargin{6};
data.uncertainty.Gamma.Tau_out = varargin{7};
data.uncertainty.Gamma.Tau_act = varargin{8};

%%
if DisplayTime
    t1 = clock;
    fprintf('%8.2f%s\n', etime(t1,t0), 's');
end
end