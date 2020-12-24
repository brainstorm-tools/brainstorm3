function writeCompound(fid, fullpath, data)
%convert to a struct
if istable(data)
    data = table2struct(data);
elseif isa(data, 'containers.Map')
    names = keys(data);
    vals = values(data, names);
    
    s = struct();
    for i=1:length(names)
        s.(misc.str2validName(names{i})) = vals{i};
    end
    data = s;
end
    
%convert to scalar struct
names = fieldnames(data);
if isempty(names)
    numrows = 0;
elseif isscalar(data)
    if ischar(data.(names{1}))
        numrows = 1;
    else
        numrows = length(data.(names{1}));
    end
else
    numrows = length(data);
    s = struct();
    for i=1:length(names)
        s.(names{i}) = {data.(names{i})};
    end
    data = s;
end

%check for references and construct tid.
classes = cell(length(names), 1);
tids = cell(size(classes));
sizes = zeros(size(classes));
for i=1:length(names)
    val = data.(names{i});
    if iscell(val) && ~iscellstr(val)
        data.(names{i}) = [val{:}];
        val = val{1};
    end
    
    classes{i} = class(val);
    tids{i} = io.getBaseType(classes{i});
    sizes(i) = H5T.get_size(tids{i});
end

tid = H5T.create('H5T_COMPOUND', sum(sizes));
for i=1:length(names)
    %insert columns into compound type
    H5T.insert(tid, names{i}, sum(sizes(1:i-1)), tids{i});
end
%close custom type ids (errors if char base type)
isH5ml = tids(cellfun('isclass', tids, 'H5ML.id'));
for i=1:length(isH5ml)
    H5T.close(isH5ml{i});
end
%optimizes for type size
H5T.pack(tid);

ref_i = strcmp(classes, 'types.untyped.ObjectView') |...
    strcmp(classes, 'types.untyped.RegionView');

%transpose numeric column arrays to row arrays
% reference and str arrays are handled below
transposeNames = names(~ref_i);
for i=1:length(transposeNames)
    nm = transposeNames{i};
    if iscolumn(data.(nm))
        data.(nm) = data.(nm) .';
    end
end

%attempt to convert raw reference information
refNames = names(ref_i);
for i=1:length(refNames)
    data.(refNames{i}) = io.getRefData(fid, data.(refNames{i}));
end

sid = H5S.create_simple(1, numrows, []);
did = H5D.create(fid, fullpath, tid, sid, 'H5P_DEFAULT');
H5D.write(did, tid, sid, sid, 'H5P_DEFAULT', data);
H5D.close(did);
H5S.close(sid);
end