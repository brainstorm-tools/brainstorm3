function groupExists = writeGroup(fid, fullpath)
groupExists = false;
defaultProplist = 'H5P_DEFAULT';

% validate path
if startsWith(fullpath, '/')
    fullpath = fullpath(2:end);
end

if endsWith(fullpath, '/')
    fullpath = fullpath(1:end-1);
end

if isempty(fullpath)
    return;
end

partsIndices = strfind(fullpath, '/');
partsIndices(end+1) = length(fullpath);

for i=length(partsIndices):-1:1
    try
        pathIdx = partsIndices(i);
        path = fullpath(1:partsIndices(i));
        groupId = H5G.open(fid, path, defaultProplist);
        if strcmp(path, fullpath) % fullpath already exists
            H5G.close(groupId);
            groupExists = true;
            return; 
        end
        deepestGroup = groupId;
        partOffsetIdx = i + 1;
        offsetStart = pathIdx + 1;
        break;
    catch
        if i == 1 % no part of this path exists
            deepestGroup = fid;
            partOffsetIdx = 1;
            offsetStart = 1;
        end
    end
end % find deepest pre-existing Group

offsets = [offsetStart partsIndices(partOffsetIdx:end-1)+1];
partsIndices = partsIndices(partOffsetIdx:end);
closeBuf = repmat(H5ML.id, length(partsIndices),1);
gid = deepestGroup;
for i=1:length(partsIndices)
    groupPath = fullpath(offsets(i):partsIndices(i));
    gid = H5G.create(gid, groupPath, defaultProplist, defaultProplist, defaultProplist);
    closeBuf(i) = gid;
end

for i=length(closeBuf):-1:1
    H5G.close(closeBuf(i));
end

if deepestGroup ~= fid
    H5G.close(deepestGroup);
end
end