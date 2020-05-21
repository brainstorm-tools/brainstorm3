function params = parseVarArgs(params,varargin)
% Parse variable input arguments supplied in name/value format.
%
%    params = parseVarArgs(params,'property1',value1,'property2',value2) sets
%    the fields propertyX in p to valueX.
%
%    params = parseVarArgs(params,varargin{:},'strict') only sets the field
%    names already present in params. All others are ignored.
%
% AE 2007-06-01

if isempty(varargin)
    return
end

% check if correct number of inputs
if mod(length(varargin),2)
    if ~strcmp(varargin{end},'strict')
        err.message = 'Name and value input arguments must come in pairs.';
        err.identifier = 'parseVarArgs:wrongInputFormat';
        error(err)
    else
        % in 'strict' case, remove all fields that are not already in params
        fields = fieldnames(params);
        ndx = find(~ismember(varargin(1:2:end-1),fields));
        varargin([2*ndx-1 2*ndx end]) = [];
    end
end

% parse arguments
for i = 1:2:length(varargin)
    if ischar(varargin{i})
        params.(varargin{i}) = varargin{i+1};
    else
        err.message = 'Name and value input arguments must come in pairs.';
        err.identifier = 'parseVarArgs:wrongInputFormat';
        error(err)
    end
end
