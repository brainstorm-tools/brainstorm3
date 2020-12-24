function str = formatStruct(s, fields)
if nargin < 2
    fields = fieldnames(s);
end

str = cell(length(fields), 1);
for i=1:length(fields)
    val = s.(fields{i});
    if iscell(val)
        if ~iscellstr(val)
            for j=1:length(val)
                if isnumeric(val{j})
                    val{j} = ['[' num2str(val{j}) ']'];
                end
            end
        end
        val = strjoin(val, ', ');
    elseif isnumeric(val)
        val = num2str(val);
    end
    str{i} = strjoin({fields{i}; val}, ': ');
end
str = strjoin(str, sprintf('\n'));
end