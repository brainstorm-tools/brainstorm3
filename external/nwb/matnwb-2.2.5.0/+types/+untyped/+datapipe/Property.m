classdef Property < handle
    %PROPERTY used in datapipe creation
    
    methods (Static, Abstract)
        tf = isInDcpl(dcpl);
    end
    
    methods (Abstract)
        addTo(obj, dcpl);
    end
end
