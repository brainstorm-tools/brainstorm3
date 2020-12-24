classdef Configuration < handle
    %CONFIGURATION Pipe properties, filters and the like
    
    methods (Static)
        function obj = fromData(data, axis)
            import types.untyped.datapipe.Configuration;
            
            errorId =...
                'NWB:Untyped:DataPipe:Configuration:CannotConfigureFromData';
            assert(isnumeric(axis) && isscalar(axis) && axis > 0,...
                errorId, 'Axis must be a numeric scalar index');
            assert(any(strcmp(class(data), Configuration.SUPPORTED_DATATYPES)),...
                errorId, 'Data must be numeric and one of %s',...
                strjoin(Configuration.SUPPORTED_DATATYPES, '|'));
            maxSize = size(data);
            offset = maxSize(axis);
            maxSize(axis) = Inf;
            obj = Configuration(maxSize);
            obj.axis = axis;
            obj.offset = offset;
            obj.dataType = class(data);
        end
    end
    
    properties
        % primary dimension index indicating which dimension will be appended
        % to.
        axis = 1;
        
        offset = 0; % offset in elements of where next to append.
        
        dataType = 'double'; % data type of the incoming data.
    end
    
    properties (SetAccess = immutable)
        maxSize; % max size on disk
    end
    
    properties (Constant)
        SUPPORTED_DATATYPES = {'single', 'double', 'uint8', 'int8',...
            'uint16', 'int16', 'uint32', 'int32', 'uint64', 'int64'
            };
    end
    
    methods
        function obj = Configuration(maxSize)
            assert(isnumeric(maxSize) && all(maxSize > 0),...
                'maxSize must be positive and numeric.');
            obj.maxSize = maxSize;
        end
    end
    
    methods
        function set.axis(obj, val)
            errorId = 'NWB:Untyped:DataPipe:Configuration:InvalidAxis';
            assert(isnumeric(val) && isscalar(val),...
                errorId,...
                'Axis must be a numeric scalar.');
            rank = length(obj.maxSize);
            assert(val > 0 && val <= rank, errorId,...
                'Axis must be within maxSize rank [1, %d]', rank);
            obj.axis = val;
        end
        
        function set.offset(obj, val)
            errorId = 'NWB:Untyped:DataPipe:Configuration:InvalidOffset';
            assert(isnumeric(val) && isscalar(val),...
                errorId,...
                'Offset must be a numeric scalar.');
            sizeBound = obj.maxSize(obj.axis);
            assert(val >= 0 && val <= obj.maxSize(obj.axis),...
                errorId,...
                'Offset must be within maxSize bounds [0, %d)', sizeBound);
            obj.offset = val;
        end
        
        function set.dataType(obj, val)
            import types.untyped.datapipe.Configuration;
            
            assert(any(strcmp(val, Configuration.SUPPORTED_DATATYPES)),...
                'Datatypes must be one of the following:\n%s',...
                strjoin(Configuration.SUPPORTED_DATATYPES, '|'));
            obj.dataType = val;
        end
    end
end
