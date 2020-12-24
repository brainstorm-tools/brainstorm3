function valid = str2validName(propname, prefix)
% STR2VALIDNAME
% Converts the property name into a valid matlab property name.
% propname: the offending propery name
% prefix: optional prefix to use instead of the ambiguous "dyn"
if ~iscell(propname) && isvarname(propname)
    valid = propname;
    return;
end

if nargin < 2 || isempty(prefix)
    prefix = 'dyn_';
else
    if ~isvarname(prefix)
        warning('Prefix contains invalid variable characters.  Reverting to "dyn"');
        prefix = 'dyn_';
    end
end

% general regex /[a-zA-Z]\w*/
if ~iscell(propname)
    propname = {propname};
end
valid = cell(size(propname));
for i=1:length(propname)
    p = propname{i};
    %find all alphanumeric and '_' characters
    validIdx = isstrprop(p, 'alphanum');
    validIdx(strfind(p, '_')) = true;
    %replace all invalid with '_'
    p(~validIdx) = '_';
    if isempty(p) || ~isstrprop(p(1), 'alpha') || iskeyword(p)
        p = [prefix p];
    end
    valid{i} = p(1:min(length(p),namelengthmax));
end

if isscalar(valid)
    valid = valid{1};
end
end