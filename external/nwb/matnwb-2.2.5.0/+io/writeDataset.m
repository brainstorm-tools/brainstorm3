function writeDataset(fid, fullpath, data, varargin)
assert(isempty(varargin) || iscellstr(varargin),...
    'options should be character arrays.');
[tid, sid, data] = io.mapData2H5(fid, data, varargin{:});
[~, dims, ~] = H5S.get_simple_extent_dims(sid);
try
    dcpl = H5P.create('H5P_DATASET_CREATE');
    if any(strcmp('forceChunking', varargin))
        H5P.set_chunk(dcpl, dims)
    end
    did = H5D.create(fid, fullpath, tid, sid, dcpl);
    H5P.close(dcpl);
catch ME
    if contains(ME.message, 'name already exists')
        did = H5D.open(fid, fullpath);
        create_plist = H5D.get_create_plist(did);
        edit_sid = H5D.get_space(did);
        [~, edit_dims, ~] = H5S.get_simple_extent_dims(edit_sid);
        layout = H5P.get_layout(create_plist);
        is_chunked = layout == H5ML.get_constant_value('H5D_CHUNKED');
        is_same_dims = all(edit_dims == dims);
        if ~is_same_dims && is_chunked
            H5D.set_extent(did, dims);
        elseif ~is_same_dims
            warning('Attempted to change size of continuous dataset `%s`.  Skipping.',...
                fullpath);
        end
        H5P.close(create_plist);
        H5S.close(edit_sid);
    else
        rethrow(ME);
    end
end
H5D.write(did, tid, sid, sid, 'H5P_DEFAULT', data);
H5D.close(did);
if isa(tid, 'H5ML.id')
    H5T.close(tid);
end
H5S.close(sid);
end