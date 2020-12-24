classdef Pipe < handle
    %PIPE Generic data pipe.  Only here for validation's sake.
    
    methods (Abstract)
        pipe = write(obj, fid, fullpath);
        append(obj, data);
        tf = hasPipeProperty(obj, type);
        property = getPipeProperty(obj, type);
        setPipeProperty(obj, property);
        removePipeProperty(obj, type);
    end
end

