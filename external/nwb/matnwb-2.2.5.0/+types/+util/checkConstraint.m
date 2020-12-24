function checkConstraint(pname, name, namedprops, constrained, val)
if isempty(val)
    return;
end

names = fieldnames(namedprops);
if any(strcmp(name, names))
    types.util.checkDtype([pname '.' name], namedprops.(name), val);
else
    for i=1:length(constrained)
        allowedType = constrained{i};
        try
            types.util.checkDtype([pname '.' name], allowedType, val);
            return;
        catch ME
            if ~strcmp(ME.identifier, 'MATNWB:INVALIDTYPE')
                rethrow(ME);
            end
        end
    end
    error('MATNWB:INVALIDCONSTR',...
        'Property `%s.%s` should be one of type(s) {%s}.',...
        pname, name, misc.cellPrettyPrint(constrained));
end
end