function checkDims(valsize, validSizes)
if any(valsize == 0)
    return; %ignore empty arrays
end

isVector = sum(valsize > 1) == 1 && all(valsize(3:end) == 1);
vszmaxlen = max(cellfun('length', validSizes));
adjsz = valsize;
if vszmaxlen > length(adjsz)
    adjsz(end+1:vszmaxlen) = 1;
else
    vszmaxlen = length(adjsz);
end

if isVector
    if isscalar(adjsz)
        flipsz = [1 adjsz];
    else
        flipsz = [adjsz(2:-1:1) adjsz(3:end)];
    end
end

for i=1:length(validSizes)
    expected = validSizes{i};
    expected(end+1:vszmaxlen) = 1;
    i_expectSig = ~isinf(expected);
    expected = expected(i_expectSig);
    if all(expected == adjsz(i_expectSig)) ||...
            (isVector && all(expected == flipsz(i_expectSig)))
        return;
    end
end

valsizef = ['[' sizeFormatStr(valsize) ']'];

%format into cell array of strings of form `[Inf]` then join
validSizesStrings = cell(size(validSizes));
for i=1:length(validSizes)
    validSizesStrings{i} = ['[' sizeFormatStr(validSizes{i}) ']'];
end
validSizesf = ['{' strjoin(validSizesStrings, ' ') '}'];
msg = sprintf(['Values size ' valsizef ' is invalid.  Must be one of ' validSizesf],...
    valsize, validSizes{:});
error(msg);
end

function s = sizeFormatStr(sz)
s = strjoin(repmat({'%d'}, size(sz)), ' ');
end