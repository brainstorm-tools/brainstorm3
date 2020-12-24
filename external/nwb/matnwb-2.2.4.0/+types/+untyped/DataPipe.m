classdef DataPipe < handle
    %DATAPIPE Special form of Datastub that allows for appending.
    % Current limitations: DataPipe currently only supports the types represented
    % by dataType.  No strings, or references are allowed with DataPipes.
    
    properties
        axis; % axis index in MATLAB format indicating which axis to increment.
        offset; % axis offset of dataset to append.  May be used to overwrite data.
        chunkSize; % ideal size of chunks for incremental data appending.
        compressionLevel; % DEFLATE level for the dataset. -1 for disabled compression
        dataType; % one of float|double|uint8|int8|int16|uint16|int32|uint32|int64|uint64
        data; % Writable data 
    end
    
    properties (SetAccess = private)
        isBound; % is associated with a filename and path
        filename;
        path;
        maxSize; % maximum dimension size
    end
    
    properties (Access = private, Constant)
        SUPPORTED_DATATYPES = {...
            'float', 'double', 'uint8', 'int8', 'uint16', 'int16',...
            'uint32', 'int32', 'uint64', 'int64'
            };
    end
    
    methods % lifecycle
        function obj = DataPipe(maxSize, varargin)
            obj.maxSize = maxSize;
            
            p = inputParser;
            p.addParameter('filename', '');
            p.addParameter('path', '');
            p.addParameter('offset', 0);
            p.addParameter('axis', 1);
            p.addParameter('chunkSize', []);
            p.addParameter('dataType', 'uint8');
            p.addParameter('compressionLevel', -1);
            p.addParameter('data', []);
            p.parse(varargin{:});
            
            obj.filename = p.Results.filename;
            obj.path = p.Results.path;
            obj.axis = p.Results.axis;
            obj.offset = p.Results.offset;
            obj.chunkSize = p.Results.chunkSize;
            obj.dataType = p.Results.dataType;
            obj.compressionLevel = p.Results.compressionLevel;
            obj.data = cast(p.Results.data, obj.dataType);
        end
    end
    
    methods % get/set
        function tf = get.isBound(obj)
            try
                fid = H5F.open(obj.filename, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
                did = H5D.open(fid, obj.path, 'H5P_DEFAULT');
                
                tf = true;
            catch
                tf = false;
            end
            
            if 1 == exist('fid', 'var')
                H5F.close(fid);
            end
            
            if 1 == exist('did', 'var')
                H5D.close(did);
            end
        end
        
        function set.axis(obj, val)
            assert(isscalar(val) && isnumeric(val),...
                'NWB:Untyped:DataPipe:SetAxis:InvalidType',...
                'Axis should be an axis index within max_size bounds.');
            val = ceil(val);
            
            assert(val > 0 && length(obj.maxSize) >= val,...
                'NWB:Untyped:DataPipe:SetAxis:InvalidAxisRange',...
                '`axis` should be within `max_size`''s rank (got %d)', val);
            obj.axis = val;
        end
        
        function set.offset(obj, val)
            assert(isscalar(val) && isnumeric(val) && val >= 0,...
                'NWB:Untyped:DataPipe:SetOffset:InvalidType',...
                'Offset should be a nonzero scalar indicating axis offset.');
            val = ceil(val);
            
            assert(obj.maxSize(obj.axis) >= val,...
                'NWB:Untyped:DataPipe:SetOffset:InvalidOffsetRange',...
                'Offset should be within maxSize bound %d (got %d)',...
                obj.maxSize(obj.axis),...
                val);
            obj.offset = val;
        end
        
        function set.chunkSize(obj, val)
            assert(isnumeric(val),...
                'NWB:Untyped:DataPipe:SetChunkSize:InvalidType',...
                '`chunkSize` must be a numeric vector');
            val = ceil(val);
            
            assert(length(val) <= length(obj.maxSize),...
                'NWB:Untyped:DataPipe:SetChunkSize:InvalidChunkRank',...
                '`chunkSize` rank should match `maxSize` rank');
            newVal = ones(size(obj.maxSize));
            newVal(1:length(val)) = val;
            val = newVal;
            assert(all(val <= obj.maxSize),...
                'NWB:Untyped:DataPipe:SetChunkSize:InvalidChunkSize',...
                '`chunkSize` must be within `maxSize` bounds');
            
            assert(~obj.isBound,...
                'NWB:Untyped:DataPipe:SetChunkSize:SettingLocked',...
                ['`chunkSize` cannot be reset if this datapipe is bound to an '...
                'existing NWB file.']);
            
            obj.chunkSize = val;
        end
        
        function set.dataType(obj, val)
            import types.untyped.DataPipe;
            
            assert(ischar(val),...
                'NWB:Untyped:DataPipe:SetDataType:InvalidType',...
                '`dataType` must be a string');
            
            assert(any(strcmp(val, DataPipe.SUPPORTED_DATATYPES)),...
                'NWB:Untyped:DataPipe:SetDataType:InvalidType',...
                '`dataType` must be one of the supported datatypes `%s`',...
                strjoin(DataPipe.SUPPORTED_DATATYPES, '|'));
            
            assert(~obj.isBound,...
                'NWB:Untyped:DataPipe:SetDataType:SettingLocked',...
                ['`dataType` cannot be reset if this datapipe is bound to an '...
                'existing NWB file.']);
            
            obj.dataType = val;
        end
        
        function set.data(obj, val)
            assert(~obj.isBound,...
                'NWB:Untyped:DataPipe:SetData:SettingLocked',...
                ['`data` cannot be set if this DataPipe is bound to an existing NWB '...
                'file']);
            obj.dataType = class(val);
            obj.data = val;
        end
        
        function set.compressionLevel(obj, val)
            assert(~obj.isBound,...
                'NWB:Untyped:DataPipe:SetCompressionLevel:SettingLocked',...
                ['`compressionLevel` can only be set if DataPipe has not yet been '...
                'bound to a NWBFile.']);
            
            assert(isscalar(val) && isnumeric(val),...
                'NWB:Untyped:DataPipe:SetCompressionLevel:InvalidType',...
                '`compressionLevel` must be a scalar numeric value.');
            val = ceil(val);
            if val < -1 || val > 9
                warning('NWB:Untyped:DataPipe:SetCompressionLevel:OutOfRange',...
                    ['`compressionLevel` range is [0, 9] or -1 for off.  '...
                    'Found %d, Disabling.'], val);
                val = -1;
            end
            
            obj.compressionLevel = val;
        end
    end
    
    methods
        function size = get_size(obj)
            assert(obj.isBound,...
                'NWB:Untyped:DataPipe:GetSize:NoAvailableSize',...
                ['DataPipe must first be bound to a valid hdf5 filename and path to '...
                'query its current dimensions.']);
            
            fid = H5F.open(obj.filename, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
            did = H5D.open(fid, obj.path, 'H5P_DEFAULT');
            sid = H5D.get_space(did);
            [~, h5_dims, ~] = H5S.get_simple_extent_dims(sid);
            size = fliplr(h5_dims);
            H5S.close(sid);
            H5D.close(did);
            H5F.close(fid);
        end
        
        function append(obj, data)
            if isempty(data)
                return;
            end
            
            assert(isa(data, obj.dataType),...
                'NWB:Untyped:DataPipe:Append:InvalidType',...
                'Data must match dataType')
            assert(obj.isBound,...
                'NWB:Untyped:DataPipe:ExportRequired',...
                ['Appending to a dataset requires exporting and re-importing '...
                    'a valid NWB file.']);
                
            default_pid = 'H5P_DEFAULT';
            
            fid = H5F.open(obj.filename, 'H5F_ACC_RDWR', default_pid);
            did = H5D.open(fid, obj.path, default_pid);
            sid = H5D.get_space(did);
            [~, h5_dims, ~] = H5S.get_simple_extent_dims(sid);
            H5S.close(sid);
            
            rank = length(obj.maxSize);
            stride_coords = size(data);
            if length(stride_coords) > rank && ~all(stride_coords(rank+1:end) == 1)
                warning('NWB:Types:Untyped:DataPipe:InvalidRank',...
                    ['Expected rank %d not expected for data of size %s.  '...
                    'Data may be lost on write.'],...
                    rank, mat2str(size(stride_coords)));
            end
            if length(stride_coords) < rank
                new_coords = ones(1, rank);
                new_coords(1:length(stride_coords)) = stride_coords;
                stride_coords = new_coords;
            end
            stride_coords = stride_coords(1:rank);
            
            if any(0 == h5_dims)
                new_extents = stride_coords;
            else
                new_extents = fliplr(h5_dims);
                non_axis_map = true(1, rank);
                non_axis_map(obj.axis) = false;
                assert(all(stride_coords(non_axis_map) == new_extents(non_axis_map)),...
                'NWB:Types:Untyped:DataPipe:InvalidSize',...
                'Stride size must match non-axis dimensions.');
                new_extents(obj.axis) = obj.offset + stride_coords(obj.axis);
            end
            h5_extents = fliplr(new_extents);
            H5D.set_extent(did, h5_extents);     
            
            sid = H5D.get_space(did);
            H5S.select_none(sid);

            offset_coords = zeros(1, rank);
            offset_coords(obj.axis) = obj.offset;
            
            h5_start = fliplr(offset_coords);
            h5_stride = [];
            h5_count = fliplr(stride_coords);
            h5_block = [];
            H5S.select_hyperslab(sid,...
                'H5S_SELECT_OR',...
                h5_start,...
                h5_stride,...
                h5_count,...
                h5_block);
            
            [mem_tid, mem_sid, data] = io.mapData2H5(fid, data, 'forceArray');
            H5S.set_extent_simple(mem_sid, rank, h5_count, h5_count);

            H5D.write(did, mem_tid, mem_sid, sid, default_pid, data);
            H5S.close(mem_sid);
            if ~ischar(mem_tid)
                H5T.close(mem_tid);
            end
            H5S.close(sid);
            H5D.close(did);
            H5F.close(fid);
            
            obj.offset = obj.offset + size(data, obj.axis);
        end
        
        function refs = export(obj, fid, fullpath, refs)
            if obj.isBound
                return;
            end
            
            default_pid = 'H5P_DEFAULT';
            tid = io.getBaseType(obj.dataType);
            
            rank = length(obj.maxSize);
            h5_dims = zeros(1, rank);
            h5_maxdims = fliplr(obj.maxSize);
            h5_maxdims(h5_maxdims == Inf) = H5ML.get_constant_value('H5S_UNLIMITED');
            sid = H5S.create_simple(rank, h5_dims, h5_maxdims);
            
            lcpl = default_pid;

            dcpl = H5P.create('H5P_DATASET_CREATE');
            if isempty(obj.chunkSize)
                h5_chunk_dims = h5_maxdims;
            else
                h5_chunk_dims = fliplr(obj.chunkSize);
            end
            H5P.set_chunk(dcpl, h5_chunk_dims);
            
            if obj.compressionLevel ~= -1
                H5P.set_deflate(dcpl, obj.compressionLevel);
            end
            
            dapl = default_pid;
            
            did = H5D.create(fid, fullpath, tid, sid, lcpl, dcpl, dapl);

            H5P.close(dcpl);
            H5S.close(sid);
            if ~ischar(tid)
                H5T.close(tid);
            end            
            H5D.close(did);
            
            data = obj.data;
            obj.data = cast([], obj.dataType);
            
            % bind to this file.
            obj.filename = H5F.get_name(fid);
            obj.path = fullpath;
            
            obj.append(data);
        end
    end
end

