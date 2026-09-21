function y = myFun_GetValue(varargin)
% **************************************************
% Get the value of yalmip variables
% Shuai Lu, Nanjing, China
% lushuai1004@outlook.com
% 2019-07-21
% **************************************************
if find(strcmp(varargin, 'DisplayTime'))
    DisplayTime = varargin{find(strcmp(varargin, 'DisplayTime'))+1};
else
    DisplayTime = 1;
end
if DisplayTime
%     fprintf('%-40s\t\t','  -- Get variables values');
    t0 = clock;
end

%%
get_value('varargin');
y = varargin{1};
%% time
if DisplayTime
    t1 = clock;
%     fprintf('%10.2f%s\n', etime(t1,t0), 's');
end

%% -------------------------- getVarName ---------------------------
    function get_value(var_name)
        % % cell
        if iscell(eval(var_name))
            size_temp = size(eval(var_name));
            eval([var_name '=' 'reshape' '(' var_name ',' num2str(1) ',' '[]' ')' ';']);
            for i = 1:size(eval(var_name),2)
                get_value([var_name '{' num2str(i) '}']);
            end
            eval([var_name '=' 'reshape' '(' var_name ',' 'size_temp' ')' ';']);
            
        % % struct
        elseif isstruct(eval(var_name))
            size_temp = size(eval(var_name));
            eval([var_name '=' 'reshape' '(' var_name ',' num2str(1) ',' '[]' ')' ';']);
            for i = 1:size(eval(var_name),2)
                subfield = fieldnames(eval([var_name '(i)']));
                for num_subfield = 1:length(subfield)
                    get_value([var_name '(' num2str(i) ')' '.' subfield{num_subfield}]);
                end
            end
            eval([var_name '=' 'reshape' '(' var_name ',' 'size_temp' ')' ';']);
            
        % % sdpvar or nsdpvar
        elseif isa(eval(var_name), 'sdpvar') || ...
                isa(eval(var_name), 'ndsdpvar')
            eval([var_name '=' 'value' '(' var_name ')' ';']);
        else
            eval([var_name '='  var_name ';']);
        end
    end

end