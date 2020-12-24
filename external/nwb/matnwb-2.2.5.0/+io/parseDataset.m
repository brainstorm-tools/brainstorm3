function parsed = parseDataset(filename, info, fullpath, Blacklist)
%typed and untyped being container maps containing type and untyped datasets
% the maps store information regarding information and stored data
% NOTE, dataset name is in path format so we need to parse that out.
name = info.Name;

%check if typed and parse attributes
[attrargs, Type] = io.parseAttributes(filename, info.Attributes, fullpath, Blacklist);

fid = H5F.open(filename, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
did = H5D.open(fid, fullpath);
props = attrargs;
datatype = info.Datatype;
dataspace = info.Dataspace;

parsed = containers.Map;
afields = keys(attrargs);
if ~isempty(afields)
    anames = strcat(name, '_', afields);
    parsed = [parsed; containers.Map(anames, attrargs.values(afields))];
end

% loading h5t references are required
% unfortunately also a bottleneck
if strcmp(datatype.Class, 'H5T_REFERENCE')
    tid = H5D.get_type(did);
    data = io.parseReference(did, tid, H5D.read(did));
    H5T.close(tid);
elseif ~strcmp(dataspace.Type, 'simple')
    data = H5D.read(did);
    if iscellstr(data) && 1 == length(data)
        data = data{1};
    elseif ischar(data)
        if datetime(version('-date')) < datetime('25-Feb-2020')
            % MATLAB 2020a fixed string support for HDF5, making reading strings
            % "consistent"
            data = data .';
        end
        datadim = size(data);
        if datadim(1) > 1
            %multidimensional strings should become cellstr
            data = strtrim(mat2cell(data, ones(datadim(1), 1), datadim(2)));
        end
    end
else
    sid = H5D.get_space(did);
    pid = H5D.get_create_plist(did);
    isChunked = H5P.get_layout(pid) == H5ML.get_constant_value('H5D_CHUNKED');
    
    tid = H5D.get_type(did);
    class_id = H5T.get_class(tid);
    isNumeric = class_id == H5ML.get_constant_value('H5T_INTEGER')...
        || class_id == H5ML.get_constant_value('H5T_FLOAT');
    if isChunked && isNumeric
        data = types.untyped.DataPipe('filename', filename, 'path', fullpath);
    elseif any(dataspace.Size == 0)
        data = [];
    else
        data = types.untyped.DataStub(filename, fullpath);
    end
    H5T.close(tid);
    H5P.close(pid);
    H5S.close(sid);
end

if isempty(Type.typename)
    %untyped group
    parsed(name) = data;
else
    props('data') = data;
    kwargs = io.map2kwargs(props);
    parsed = eval([Type.typename '(kwargs{:})']);
end
H5D.close(did);
H5F.close(fid);
end