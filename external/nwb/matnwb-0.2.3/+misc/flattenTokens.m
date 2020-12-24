% flattens tokens from regexp tokens.
function flatlist = flattenTokens(nestedList)
    nllen = length(nestedList);
    flatlist = cell(1, nllen);
    for i=1:nllen
        flatlist{i} = nestedList{i}{1};
    end
end