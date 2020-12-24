function [set, ivarargin] = parseConstrained(obj,pname, type, varargin)
assert(mod(length(varargin),2) == 0, 'Malformed varargin.  Should be even');
ikeys = false(size(varargin));
defprops = properties(obj);
for i=1:2:length(varargin)
    ikeys(i) = isa(varargin{i+1}, type) && ~any(strcmp(varargin{i}, defprops));
end
ivals = circshift(ikeys,1);
if any(ikeys)
    map = containers.Map(varargin(ikeys), varargin(ivals));
    set = types.untyped.Set(map,...
        @(nm, val)types.util.checkConstraint(pname, nm, struct(), {type}, val));
else
    set = types.untyped.Set();
end
ivarargin = ikeys | ivals;
end