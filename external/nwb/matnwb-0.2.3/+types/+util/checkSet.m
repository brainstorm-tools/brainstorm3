function checkSet(pname, namedprops, constraints, val)
if isempty(val)
    return;
end
if ~isa(val, 'types.untyped.Set')
    error('Property `%s` must be a `types.untyped.Set`', pname);
end

val.setValidationFcn(...
    @(nm, val)types.util.checkConstraint(pname, nm, namedprops, constraints, val));
val.validateAll();
end