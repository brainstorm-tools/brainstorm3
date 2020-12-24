classdef Shuffle < types.untyped.datapipe.Property
    %SHUFFLE Shuffle Filter
    
    properties (Constant)
        FILTER_NAME = 'H5Z_FILTER_SHUFFLE';
    end
    
    %% Properties
    methods (Static)
        function tf = isInDcpl(dcpl)
            import types.untyped.datapipe.properties.Shuffle;
            
            tf = false;
            filterId = H5ML.get_constant_value(Shuffle.FILTER_NAME);
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
        function addTo(~, dcpl)
            H5P.set_shuffle(dcpl);
        end
    end
end

