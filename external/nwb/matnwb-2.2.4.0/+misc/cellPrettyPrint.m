function s = cellPrettyPrint(val)
%NOTE: Returns str without curly brackets
%allows for numerical and casting values (0.0, NaN, int64(2.0), etc.)
% nummatch = regexp(val, '^(?:.+\()?(Inf|NaN|\d+(?:\.\d+)?)\)?', 'match', 'once');
% iNonNums = ~strcmp(val, nummatch);

%strip quotes
iHasQuotes = startsWith(val, '''') & endsWith(val, '''');
valHasQuotes = val(iHasQuotes);
for i=1:length(valHasQuotes)
    vhq = valHasQuotes{i};
    valHasQuotes{i} = vhq(2:end-1);
end
val(iHasQuotes) = valHasQuotes;

%escape interior quotes
val(iHasQuotes) = strrep(val(iHasQuotes), '''', '`');
%re-add surrounding quotes for all non-numeric values
val(iHasQuotes) = strcat('''', val(iHasQuotes), '''');

s = strjoin(val, ' ');
end