classdef Compression < types.untyped.datapipe.Property
    %COMPRESSION Deflate compression filter
    
    properties (Constant)
        FILTER_NAME = 'H5Z_FILTER_DEFLATE';
    end
    
    methods (Static)
        function compression = fromDcpl(dcpl)
            import types.untyped.datapipe.properties.Compression;
            
            filterId = H5ML.get_constant_value(Compression.FILTER_NAME);
            [~, level, ~, ~] = H5P.get_filter_by_id(dcpl, filterId);
            compression = Compression(level);
        end
    end
    
    properties
        level = 3;
    end
    
    methods
        function obj = Compression(level)
            obj.level = level;
        end
    end
    
    %% Property
    methods (Static)
        function tf = isInDcpl(dcpl)
            import types.untyped.datapipe.properties.Compression;
            tf = false;
            
            filterId = H5ML.get_constant_value(Compression.FILTER_NAME);
            for i = 0:(H5P.get_nfilters(dcpl) - 1)
                [id, ~, ~, ~, ~] = H5P.get_filter(dcpl, i);
                if id == filterId
                    tf = true;
                    return;
                end
            end
        end
    end
    
    methods
        function addTo(obj, dcpl)
            H5P.set_deflate(dcpl, obj.level);
        end
    end
end

