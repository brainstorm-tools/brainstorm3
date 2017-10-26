function str = struct2json(s)
    f = fieldnames(s);
    str = '';
    for i = 1:length(fieldnames(s))
        val = s.(f{i});
        valstr = m2json(val);
        str = [str '"' f{i} '"' ': ' valstr ', ' ];
    end
    str = str(1:(end-2)); % trim trailing comma
    str = ['{' str '}']; 
end