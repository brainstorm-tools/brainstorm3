classdef Set < handle & matlab.mixin.CustomDisplay
    properties(SetAccess=protected)
        map; %containers.Map
        fcn; %validation function
    end
    
    methods
        function obj = Set(varargin)
            % obj = SET returns an empty set
            % obj = SET(field1,value1,...,fieldN,valueN) returns a set from key value pairs
            % obj = SET(src) can be a struct or map
            % obj = SET(__,fcn) adds a validation function from a handle
            obj.map = containers.Map;
            
            if nargin == 0
                return;
            end
            
            switch class(varargin{1})
                case 'function_handle'
                    obj.fcn = varargin{1};
                case {'struct', 'containers.Map'}
                    src = varargin{1};
                    if isstruct(src)
                        srcFields = fieldnames(src);
                        for i=1:length(srcFields)
                            obj.map(srcFields{i}) = src.(srcFields{i});
                        end
                    else
                        srcKeys = keys(src);
                        obj.set(srcKeys, values(src, srcKeys));
                    end
                    
                    if nargin > 1
                        assert(isa(varargin{2}, 'function_handle'),...
                            '`fcn` Expected a function_handle type');
                        obj.fcn = varargin{2};
                    end
                case 'char'
                    if mod(length(varargin), 2) == 1
                        assert(isa(varargin{end}, 'function_handle'),...
                            '`fcn` Expected a function_handle type');
                        obj.fcn = varargin{end};
                        varargin(end) = [];
                    end
                    assert(mod(length(varargin), 2) == 0,...
                        ['KeyWord Argument Count Mismatch.  '...
                        'Number of Keys do not match number of values']);
                    assert(iscellstr(varargin(1:2:end)),...
                        'KeyWord Argument Error: Keys must be char');
                    obj.map = containers.Map(varargin(1:2:end), varargin(2:2:end));
            end
        end
        
        %return object's keys
        function k = keys(obj)
            k = keys(obj.map);
        end
        
        %return values of backed map
        function v = values(obj)
            v = values(obj.map);
        end
        
        %return number of entries
        function cnt = Count(obj)
            cnt = obj.map.Count;
        end
        
        %overloads size(obj)
        function varargout = size(obj, dim)
            if nargin > 1
                if dim > 1
                    varargout{1} = 1;
                else
                    varargout{1} = obj.Count;
                end
            else
                if nargout == 1
                    varargout{1} = [obj.Count, 1];
                else
                    [varargout{:}] = ones(nargout,1);
                    varargout{1} = obj.Count;
                end
            end
        end
        
        %overloads horzcat(A1,A2,...,An)
        function C = horzcat(varargin)
            error('MATNWB:SET:UNSUPPORTED',...
                'types.untyped.Set does not support concatenation');
        end
        
        %overloads vertcat(A1, A2,...,An)
        function C = vertcat(varargin)
            error('MATNWB:SET:UNSUPPORTED',...
                'types.untyped.Set does not support concatenation.');
        end
         
        function setValidationFcn(obj, fcn)
            if (~isnumeric(fcn) || ~isempty(fcn)) && ~isa(fcn, 'function_handle')
                error('Validation must be a function handle of form @(name, val) or empty array.');
            end
            obj.fcn = fcn;
        end
        
        function validateAll(obj)
            mapkeys = keys(obj.map);
            for i=1:length(mapkeys)
                mk = mapkeys{i};
                obj.fcn(mk, obj.map(mk));
            end
        end
        
        function obj = set(obj, name, val)
            if ischar(name)
                name = {name};
            end
            
            if ischar(val)
                val = {val};
            end
            cellExtract = iscell(val);
            
            assert(length(name) == length(val),...
                'number of property names should match number of vals on set.');
            if ~isempty(obj.fcn)
                for i=1:length(name)
                    if cellExtract
                        elem = val{i};
                    else
                        elem = val(i);
                    end
                    obj.fcn(name{i}, elem);
                end
            end
            for i=1:length(name)
                if cellExtract
                    elem = val{i};
                else
                    elem = val(i);
                end
                obj.map(name{i}) = elem;
            end
        end
        
        function obj = remove(obj, name)
            remove(obj.map, name);
        end
        
        function obj = clear(obj)
            obj.map = containers.Map;
        end
        
        function o = get(obj, name)
            if ischar(name)
                name = {name};
            end
            o = cell(length(name),1);
            for i=1:length(name)
                o{i} = obj.map(name{i});
            end
            if isscalar(o)
                o = o{1};
            end
        end
        
        function refs = export(obj, fid, fullpath, refs)
            io.writeGroup(fid, fullpath);
            k = keys(obj.map);
            val = values(obj.map, k);
            for i=1:length(k)
                v = val{i};
                nm = k{i};
                propfp = [fullpath '/' nm];
                if startsWith(class(v), 'types.')
                    refs = v.export(fid, propfp, refs);
                else
                    refs = io.writeDataset(fid, propfp, v, refs);
                end
            end
        end
    end
    
    methods(Access=protected)
        function displayEmptyObject(obj)
            hdr = ['  Empty '...
                '<a href="matlab:helpPopup types.untyped.Set" style="font-weight:bold">'...
                'Set</a>'];
            footer = getFooter(obj);
            disp([hdr newline footer]);
        end
        
        function displayScalarObject(obj)
            displayNonScalarObject(obj)
        end
        
        function displayNonScalarObject(obj)
            hdr = getHeader(obj);
            footer = getFooter(obj);
            mkeys = keys(obj);
            mklen = cellfun('length', mkeys);
            max_mklen = max(mklen);
            body = cell(size(mkeys));
            for i=1:length(mkeys)
                mk = mkeys{i};
                mkspace = repmat(' ', 1, max_mklen - mklen(i));
                body{i} = [mkspace mk ': [' class(obj.map(mk)) ']'];
            end
            body = file.addSpaces(strjoin(body, newline), 4);
            disp([hdr newline body newline footer]);
        end
    end
    
    methods(Access=private)
        %converts to cell string.  Does not do type checking.
        function cellval = merge_stringtypes(obj, val)
            if isstring(val)
                val = convertStringsToChars(val);
            end
            
            if ischar(val)
                cellval = {val};
            else
                cellval = val;
            end
        end
    end
end