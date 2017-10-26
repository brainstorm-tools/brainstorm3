function escaped_val = checkescape(val)
%adds '\' escape character if needed
ec = '\';
ind = find( (val == '"') | (val == '\' ) | (val == '/' ));
if(ind)
    if(ind(1) == 1)
        val = ['\' val];
        ind = ind + 1;
        ind(1) = [];
    end
    if (ind)
        val = [val ec(ones(1,length(ind)))]; %extend lengh of val to prep for char shifts.
        for i = 1:length(ind)
            val(ind(i):end) = [ec val(ind(i):end-1)];
            ind = ind+1;
        end
    end
end

escaped_val = val;