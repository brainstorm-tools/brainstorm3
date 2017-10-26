function check = isExceptionStrip(grstruct, fieldname)

% initialize output
check = false;

% exception list {fieldname, val_types}
exceptions = {'color', @iscell, 'width', @(x)(length(x)>1), 'size', @(x)(length(x)>1)};

for e = 1:2:length(exceptions)
    
    %comparison function 
    compfun = exceptions{e+1};
    
    % look for fieldnames of type exceptions{e} and compare the underyling data using exceptions{e+1}
    if strcmp(fieldname, exceptions{e}) && compfun(grstruct.(fieldname))
        check = true;
    end
    
end
end