function s = fillProps(props, names, options)
proplines = cell(size(names));
for i=1:length(names)
    pnm = names{i};
    property = props(pnm);
    if ischar(property)
        doc = ['property of type ' property];
    elseif isa(property, 'containers.Map')
        doc = ['reference to type ' property('target_type')];
    elseif isstruct(property)
        propertyNames = fieldnames(property);
        doc = ['table with properties {' misc.cellPrettyPrint(propertyNames) '}'];
    else
        doc = property.doc;
    end
    proplines{i} = [pnm '; % ' doc];
end

if nargin >= 3
    opt = ['(' options ')'];
else
    opt = '';
end

if isempty(proplines)
    s = '';
else
    s = strjoin({...
        ['properties' opt]...
        file.addSpaces(strjoin(proplines, newline), 4)...
        'end'}, newline);
end
end