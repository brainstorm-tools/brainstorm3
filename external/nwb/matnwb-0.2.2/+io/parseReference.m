function refobj = parseReference(did, tid, data)
szref = size(data);
%first dimension is always the raw buffer size
szref = szref(2:end);
if isscalar(szref)
    szref = [szref 1];
end
numref = prod(szref);
if H5T.equal(tid, 'H5T_STD_REF_OBJ')
    reftype = H5ML.get_constant_value('H5R_OBJECT');
else
    reftype = H5ML.get_constant_value('H5R_DATASET_REGION');
end
for i=1:numref
    refobj(i) = parseSingleRef(did, reftype, data(:,i));
end
refobj = reshape(refobj, szref);
end

function refobj = parseSingleRef(did, reftype, data)
target = H5R.get_name(did, reftype, data);

%% H5R_OBJECT
if reftype == H5ML.get_constant_value('H5R_OBJECT')
    refobj = types.untyped.ObjectView(target);
    return;
end

%% H5R_DATASET_REGION
if isempty(target)
    refobj = types.untyped.RegionView(target,{});
    return;
end
region = {};
sid = H5R.get_region(did, reftype, data);
sel_type = H5S.get_select_type(sid);
if sel_type == H5ML.get_constant_value('H5S_SEL_HYPERSLABS')
    nblocks = H5S.get_select_hyper_nblocks(sid);
    blocklist = H5S.get_select_hyper_blocklist(sid, 0, nblocks);
    
    region = rot90(blocklist, -1); %transpose + fliplr
    region = mat2cell(region, ones(size(region,1)/2,1)+1);
end
H5S.close(sid);
refobj = types.untyped.RegionView(target, region);
end