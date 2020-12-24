classdef ExternalLink < handle
    properties
        filename;
        path;
    end
    
    methods
        function obj = ExternalLink(filename, path)
            obj.filename = filename;
            obj.path = path;
        end
        
        function data = deref(obj)
            data = cell(size(obj));
            for i = 1:numel(obj)
                data{i} = scalar_deref(obj(i));
            end
            
            if isscalar(data)
                data = data{1};
            end
            
            function data = scalar_deref(Link)
                % if path is valid hdf5 path, then returns either a Nwb Object, DataStub, or Link Object
                % otherwise errors, probably.
                assert(ischar(Link.filename), 'expecting filename to be a char array.');
                assert(2 == exist(Link.filename, 'file'), '%s does not exist.', Link.filename);
                
                fid = H5F.open(Link.filename, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
                info = h5info(Link.filename, Link.path);
                loc = [Link.filename Link.path];
                attr_names = {info.Attributes.Name};
                
                is_typed = any(strcmp(attr_names, 'neurodata_type')...
                    | strcmp(attr_names, 'namespace'));
                
                oid = H5O.open(fid, Link.path, 'H5P_DEFAULT');
                oinfo = H5O.get_info(oid);
                
                H5O.close(oid);
                H5F.close(fid);
                switch oinfo.type
                    case H5ML.get_constant_value('H5G_DATASET')
                        if is_typed
                            data = io.parseDataset(Link.filename, info, Link.path);
                        else
                            data = types.untyped.DataStub(Link.filename, Link.path);
                        end
                    case H5ML.get_constant_value('H5G_GROUP')
                        assert(is_typed,...
                            ['Attempted to dereference an external link to '...
                            'a non-dataset object %s'], loc);
                        data = io.parseGroup(Link.filename, info);
                    case H5ML.get_constant_value('H5G_LINK')
                        data = deref_link(fid, Link);
                    otherwise
                        error('Externally linked %s contains an unsupported type.',...
                            loc);
                end
            end
            
            function data = deref_link(fid, Link)
                linfo = H5L.get_info(fid, Link.path, 'H5P_DEFAULT');
                is_external = linfo.type == H5ML.get_constant_value('H5L_TYPE_EXTERNAL');
                is_soft = linfo.type == H5ML.get_constant_value('H5L_TYPE_SOFT');
                assert(is_external || is_soft,...
                    ['Unsupported link type in %s, with name %s.  '...
                    'Links must be external or soft.'],...
                    Link.filename, Link.path);
                
                link_val = H5L.get_val(fid, Link.path, 'H5P_DEFAULT');
                if is_external
                    data = types.untyped.ExternalLink(link_val{:});
                else
                    data = types.untyped.SoftLink(link_val{:});
                end
            end
        end
        
        function refs = export(obj, fid, fullpath, refs)
            plist = 'H5P_DEFAULT';
            if H5L.exists(fid, fullpath, plist)
                H5L.delete(fid, fullpath, plist);
            end
            H5L.create_external(obj.filename, obj.path, fid, fullpath, plist, plist);
        end
    end
end