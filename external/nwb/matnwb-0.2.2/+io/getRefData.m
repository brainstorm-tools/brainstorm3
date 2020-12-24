function ref_data = getRefData(fid, ref)
% defaults to -1 (H5ML.id) which works for H5R.create when using
% Object References
refspace = repmat(H5ML.id, size(ref));
refpaths = {ref.path};
validPaths = find(~cellfun('isempty', refpaths));
if isa(ref, 'types.untyped.RegionView')
    for i=validPaths
        did = H5D.open(fid, refpaths{i});
        %by default, we use block mode.
        refspace(i) = ref(i).get_selection(H5D.get_space(did));
        H5D.close(did);
    end
end
typesize = H5T.get_size(ref(1).type);
ref_data = zeros([typesize size(ref)], 'uint8');
for i=validPaths
    ref_data(:, i) = H5R.create(fid, ref(i).path, ref(i).reftype, ...
        refspace(i));
end
end