function valstr = m2json(val)
    if isstruct(val)
        valstr = struct2json(val);
    elseif iscell(val)
        valstr = cell2json(val);
    elseif isa(val, 'numeric')
        sz = size(val);
        if length(find(sz>1))>1 % 2D or higher array
            valstr = '';
            for i = 1:sz(1)
                valsubstr = [sprintf('%.15g, ', val(i,:))];
                valsubstr = valsubstr(1:(end-2));
                valstr = [valstr ', [' valsubstr ']'];
            end
            valstr = valstr(3:end); % trail leading commas
        else
            valstr = [sprintf('%.15g, ', val)];
            valstr = valstr(1:(end-2));
        end
        if length(val)>1
            valstr = ['[' valstr ']'];
        elseif length(val) == 0
            valstr = '[]';
        end
        valstr = strrep(valstr, 'Inf', 'null');
        valstr = strrep(valstr, 'NaN', 'null');
    elseif ischar(val)
         val = checkescape(val); %add escape characters
         valstr = ['"' val '"'];
    elseif islogical(val)
        if val
            valstr = 'true';
        else
            valstr = 'false';
        end
    else
        valstr = ''; % wtf is it?
    end
