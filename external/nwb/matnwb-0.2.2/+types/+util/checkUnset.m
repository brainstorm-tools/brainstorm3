function checkUnset(obj, argin)
props = properties(obj);
anonNames = {};
for i = 1:length(props)
    p = obj.(props{i});
    if isa(p, 'types.untyped.Anon')
        anonNames = [anonNames;{p.name}];
    elseif isa(p, 'types.untyped.Set')
        anonNames = [anonNames;keys(p) .'];
    end
end
dropped = setdiff(argin, [props;anonNames]);
assert(isempty(dropped),...
    'Nwb:Types:Util:CheckUnset:InvalidProperties',...
    'Properties {%s} are not valid property names.',...
    misc.cellPrettyPrint(dropped));
end