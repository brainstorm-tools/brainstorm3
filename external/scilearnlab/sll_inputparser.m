function paramval = fl_inputparser(parseobj,paramname,default,validator)
% if default == [], then parameter is required

%% if no input return default
if isempty(parseobj)
    paramval = default;
    return
end

%% find parameter value
if isstruct(parseobj{1}) %if input is given as a structure

    if isfield(parseobj{1},paramname)
        paramval = parseobj{1}.(paramname);
    end
        
elseif iscell(parseobj) %if input is given as name/value pairs
    
    %check whether input is in pairs
    if mod(length(parseobj),2)
        error('Optional input parameters should come in name/value pairs.');
    end
    
    %separate parameters and values
    paramnames = parseobj(1:2:end);
    paramvalues = parseobj(2:2:end);
    
    
    
    %check if parameter name is invalid
    if isempty(paramname)
        for i = 1:length(paramnames)
            if ischar(paramnames{i}) & ~nnz(ismember(validator,paramnames{i})) %if parameter name not valid
                error(['Input ''' paramnames{i} ''' not valid.']);
            end
        end
        paramval = [];
        return
    end
    
    ndx = find(strcmp(paramnames,paramname));
    
    if length(ndx)>1
        error('Optional input parameters should only be defined once; multiple definitions detected.');
    end
    if ndx
        paramval = paramvalues{ndx};
    end

end

%% check if paramval was not defined
if ~exist('paramval')
    if ~exist('default') | isempty('default') %check if parameter is required
        error(['Input parameter '''  paramname ''' is required.']);
    else
        paramval = default;
    end
end

%% validate input
if exist('validator') %validator is optional
    if isa(validator,'function_handle') %if validator is a function handle
        if ~validator(paramval) %if not valid
            error(['Optional input parameter '''  paramname ''' has invalid value.']);
        end
    elseif iscell(validator) %directly provide cell; makes it easy to check strings
        
        paramval = validatestring(paramval,validator);
        
    end
end
