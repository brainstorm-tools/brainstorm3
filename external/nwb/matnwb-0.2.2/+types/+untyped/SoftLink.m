classdef SoftLink < handle
    properties
        path;
    end
    
%     properties(Hidden, SetAccess=immutable)
%         type; %type constraint, used by file generation
%     end
    
    methods
        function obj = SoftLink(path)
            obj.path = path;
        end
        
        function set.path(obj, val)
            if ~ischar(val)
                error('Property `path` should be a char array');
            end
            obj.path = val;
        end
        
        function refobj = deref(obj, nwb)
            assert(isa(nwb, 'NwbFile'),...
                'MatNWB:Types:Untyped:SoftLink:Deref:InvalidArgument',...
                'Argument `nwb` must be a valid `NwbFile`');
            
            refobj = nwb.resolve({obj.path});
        end
        
        function refs = export(obj, fid, fullpath, refs)
            plist = 'H5P_DEFAULT';
            try
                H5L.create_soft(obj.path, fid, fullpath, plist, plist);
            catch ME
                if contains(ME.message, 'name already exists')
                    previousLink = H5L.get_val(fid, fullpath, plist);
                    if ~strcmp(previousLink{1}, obj.path)
                        H5L.delete(fid, fullpath, plist);
                        H5L.create_soft(obj.path, fid, fullpath, plist, plist);
                    end
                else
                    rethrow(ME);
                end
            end
        end
    end
end