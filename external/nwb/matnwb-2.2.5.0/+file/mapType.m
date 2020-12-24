% converts dtype name to type name.  If struct, then returns a struct of mapped types
% all this does is narrow the possible range of names per type.
function dt = mapType(dtype)
if iscell(dtype)
    %compound type
    dt = struct();
    numTypes = length(dtype);
    doc = cell(size(dtype));
    for i=1:numTypes
        typeMap = dtype{i};
        typeName = typeMap('name');
        type = file.mapType(typeMap('dtype'));
        docText = typeMap('doc');
        dt.(typeName) = type;
        doc{i} = [typeName ': ' docText];
    end
elseif isempty(dtype) || any(strcmp({'None', 'any'}, dtype))
    dt = 'any';
elseif iscell(dtype)
elseif isa(dtype, 'containers.Map')
    dt = dtype;
elseif any(strcmpi({'ascii', 'str', 'text', 'utf8'}, dtype))
    dt = 'char';
elseif strcmp('bool', dtype)
    dt = 'logical';
elseif strcmpi('isodatetime', dtype)
    dt = 'isodatetime';
else
    dt = dtype;
end
end