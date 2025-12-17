function getValue(varargin)
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
    fprintf('%-40s\t\t','  - Get variables values');
    t0 = clock;
end

%%
global model var_1st var_2st;
var_name = varargin{1};
get_value(var_name);

%% time
t1 = clock;
fprintf('%8.2f%s\n', etime(t1,t0), 's');

%% -------------------------- getVarName ---------------------------
    function get_value(var_name)
        if strcmp(eval(['class(' var_name ')']),'struct')
            for i = 1:eval(['length(' var_name ')'])
                subfield = fieldnames(eval([var_name '(i)']));
                for j = 1:length(subfield)
                    get_value([var_name '(' num2str(i) ')' '.' subfield{j}]);
                end
            end
        elseif strcmp(eval(['class(' var_name ')']),'sdpvar') || ...
                strcmp(eval(['class(' var_name ')']),'ndsdpvar')
            temp =  value(eval([var_name]));
            eval([var_name '=' 'temp' ';']);
            
        end
    end
end