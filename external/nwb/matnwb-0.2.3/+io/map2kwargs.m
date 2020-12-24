function kwargs = map2kwargs(map)
%containers.Map -> keyword args for types
kwargs = cell(1, map.Count * 2);
mapkeys = keys(map);
for i=1:length(mapkeys)
    k = mapkeys{i};
    kwargs{(i*2)-1} = k;
    kwargs{i*2} = map(k);
end
end