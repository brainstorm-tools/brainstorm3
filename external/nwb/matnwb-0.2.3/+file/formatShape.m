function sz = formatShape(shape)
%check for optional dims
assert(iscell(shape), '`shape` must be a cell.');

if isempty(shape)
    sz = {};
    return;
end

sz = shape;
if iscellstr(sz)
    sz = strrep(sz, 'null', 'Inf');
    emptySz = cellfun('isempty', sz);
    sz(emptySz) = {'Inf'};
    sz = sz(end:-1:1); %reverse dimensions
    sz = misc.cellPrettyPrint(sz);
else
    for i=1:length(sz)
        sz{i} = strrep(sz{i}, 'null', 'Inf');
        sz{i} = sz{i}(end:-1:1); %reverse dimensions
        sz{i} = misc.cellPrettyPrint(sz{i});
    end
end
end