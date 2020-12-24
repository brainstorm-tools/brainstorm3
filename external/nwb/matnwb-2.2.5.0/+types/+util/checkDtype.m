function val = checkDtype(name, type, val)
%ref
%any, double, int/uint, char
persistent WHITELIST;
if isempty(WHITELIST)
    WHITELIST = {...
        'types.untyped.ExternalLink'...
        'types.untyped.SoftLink'...
        };
end

if isstruct(type)
    names = fieldnames(type);
    assert(isstruct(val) || istable(val) || isa(val, 'containers.Map'), ...
        'types.untyped.checkDtype: Compound Type must be a struct, table, or a containers.Map');
    if (isstruct(val) && isscalar(val)) || isa(val, 'containers.Map')
        %check for correct array shape
        sizes = zeros(length(names),1);
        for i=1:length(names)
            if isstruct(val)
                subv = val.(names{i});
            else
                subv = val(names{i});
            end
            assert(isvector(subv),...
                ['types.util.checkDtype: struct of arrays as a compound type ',...
                'cannot have multidimensional data in their fields.  Field data ',...
                'shape must be scalar or vector to be valid.']);
            sizes(i) = length(subv);
        end
        sizes = unique(sizes);
        assert(isscalar(sizes),...
            ['struct of arrays as a compound type ',...
            'contains mismatched number of elements with unique sizes: [%s].  ',...
            'Number of elements for each struct field must match to be valid.'], ...
            num2str(sizes));
    end
    for i=1:length(names)
        pnm = names{i};
        subnm = [name '.' pnm];
        typenm = type.(pnm);
        
        if (isstruct(val) && isscalar(val)) || istable(val)
            val.(pnm) = types.util.checkDtype(subnm,typenm,val.(pnm));
        elseif isstruct(val)
            for j=1:length(val)
                elem = val(j).(pnm);
                assert(~iscell(elem) && ...
                    (isempty(elem) || ...
                    (isscalar(elem) || (ischar(elem) && isvector(elem)))),...
                    ['Fields for an array of structs for '...
                    'compound types should have non-cell scalar values or char arrays.']);
                val(j).(pnm) = types.util.checkDtype(subnm, typenm, elem);
            end
        else
            val(names{i}) = types.util.checkDtype(subnm,typenm,val(names{i}));
        end
    end
else
    errid = 'MATNWB:INVALIDTYPE';
    errmsg = ['Property `' name '` must be a ' type '.'];
    if isempty(val)
        return;
    end
    
    if isa(val, 'types.untyped.DataStub')
        %grab first element and check
        truval = val;
        if any(val.dims == 0)
            val = [];
        else
            val = val.load(1);
        end
    elseif isa(val, 'types.untyped.Anon')
        truval = val;
        val = val.value;
    elseif isa(val, 'types.untyped.ExternalLink') &&...
            ~strcmp(type, 'types.untyped.ExternalLink')
        truval = val;
        val = val.deref();
    elseif isa(val, 'types.untyped.DataPipe')
        truval = val;
        val = cast([], val.dataType);
    else
        truval = [];
    end
    
    if any(strcmpi(type, {'single' 'double' 'logical' 'numeric'})) ||...
            startsWith(type, {'int' 'uint' 'float'})
        if isa(val, 'types.untyped.SoftLink')
            % derefing through softlink would require writing and/or the root NwbFile object
            return;
        end
        
        if isa(truval, 'types.untyped.ExternalLink')
            assert(any(strcmp('data', properties(val))), errid, errmsg);
            val = val.data;
            if isa(val, 'types.untyped.DataStub')
                val = val.load(1);
            end
            
            if ~isa(val, type)
                warning(errid,...
                    'Externally Linked Numeric Property `%s` is not of type `%s` (actual type is `%s`).',...
                    name, type, class(val));
            end
        else
            %all numeric types
            try
                val = types.util.correctType(val, type);
            catch ME
                error('MATNWB:CASTERROR', 'Could not cast type `%s` to `%s` for property `%s`',...
                    class(val), type, name);
            end
        end
    elseif strcmp(type, 'isodatetime')
        assert(ischar(val)...
            || iscellstr(val)...
            || isdatetime(val) ...
            || (iscell(val) && all(cellfun('isclass', val, 'datetime'))),...
            errid, errmsg);
        if ischar(val) || iscellstr(val)
            if ischar(val)
                val = {val};
            end
            
            datevals = cell(size(val));
            for i = 1:length(val)
                datevals{i} = datetime8601(val{i});
            end
            val = datevals;
        end
        
        if isdatetime(val)
            val = {val};
        end
        
        for i = 1:length(val)
            if isempty(val{i}.TimeZone)
                val{i}.TimeZone = 'local';
            end
            val{i}.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSSSSSZZZZZ';
        end
        
        if isscalar(val)
            val = val{1};
        end
    elseif strcmp(type, 'char')
        assert(ischar(val) || iscellstr(val), errid, errmsg);
    else %class, ref, or link
        
        noncell = false;
        if ~iscell(val)
            val = {val};
            noncell = true;
        end
        for i=1:length(val)
            subval = val{i};
            if isempty(subval)
                continue;
            end
            
            if ~isa(subval, type) && ~any(strcmp(class(subval), WHITELIST))
                error(errid, errmsg);
            end
        end
        if noncell
            val = val{1};
        end
    end
    
    %reset to datastub/anon
    if ~isempty(truval)
        val = truval;
    end
end
end

function date_time = datetime8601(datestr)
addpath(fullfile(fileparts(which('NwbFile')), 'external_packages', 'datenum8601'));
[~, ~, format] = datenum8601(datestr);
format = format{1};
has_delimiters = format(1) == '*';
if has_delimiters
    format = format(2:end);
end

assert(strncmp(format, 'ymd', 3),...
    'MatNWB:Types:Util:CheckDType:DateTime:Unsupported8601',...
    'non-ymd formats not supported.');
separator = format(4);
if separator ~= ' '
    % non-space digits will error when specifying import format
    separator = ['''' separator ''''];
end

has_fractional_sec = isstrprop(format(8:end), 'digit');
if has_fractional_sec
   seconds_precision = str2double(format(8:end));
   if seconds_precision > 9
       warning('MatNWB:Types:Util:CheckDType:DateTime:LossySeconds',...
           ['Potential loss of time data detected.  MATLAB fractional seconds '...
           'precision is limited to 1 ns.  Extra precision will be truncated.']);
   end
end
day_segments = {'yyyy', 'MM', 'dd'};
time_segments = {'HH', 'mm', 'ss'};

if has_delimiters
    day_delimiter = '-';
    time_delimiter = ':';
else
    day_delimiter = '';
    time_delimiter = '';
end

day_format = strjoin(day_segments, day_delimiter);
time_format = strjoin(time_segments, time_delimiter);
format = [day_format separator time_format];
if has_fractional_sec
    format = sprintf('%s.%s', format, repmat('S', 1, seconds_precision));
end

[datestr, timezone] = derive_timezone(datestr);
date_time = datetime(datestr,...
    'InputFormat', format,...
    'TimeZone', timezone);
end

function [datestr, timezone] = derive_timezone(datestr)
% one of:
% +-hh:mm
% +-hhmm
% +-hh
% Z
tzre_pattern = '(?:[+-]\d{2}(?::?\d{2})?|Z)$';
tzre_match = regexp(datestr, tzre_pattern, 'once');
if isempty(tzre_match)
    timezone = 'local';
else
    timezone = datestr(tzre_match:end);
    if strcmp(timezone, 'Z')
        timezone = 'UTC';
    end
    datestr = datestr(1:(tzre_match - 1));
end
end