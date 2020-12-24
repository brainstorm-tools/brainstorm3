function fsstr = fillSetters(propnames)
fsstr = cell(size(propnames));
for i=1:length(propnames)
    nm = propnames{i};
    fsstr{i} = strjoin({...
        ['function obj = set.' nm '(obj, val)']...
        ['    obj.' nm ' = obj.validate_' nm '(val);']...
        'end'}, newline);
end
fsstr = strjoin(fsstr, newline);
end