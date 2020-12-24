function type = getMatType(tid)
%GETMATTYPE Given HDF5 type ID, returns string indicating MATLAB type.
% only works for numeric values.
if H5T.equal(tid, 'H5T_IEEE_F64LE')
    type = 'double';
elseif H5T.equal(tid, 'H5T_IEEE_F32LE')
    type = 'single';
elseif H5T.equal(tid, 'H5T_STD_U8LE')
    type = 'uint8';
elseif H5T.equal(tid, 'H5T_STD_I8LE')
    type = 'int8';
elseif H5T.equal(tid, 'H5T_STD_U16LE')
    type = 'uint16';
elseif H5T.equal(tid, 'H5T_STD_I16LE')
    type = 'int16';
elseif H5T.equal(tid, 'H5T_STD_U32LE')
    type = 'uint32';
elseif H5T.equal(tid, 'H5T_STD_I32LE')
    type = 'int32';
elseif H5T.equal(tid, 'H5T_STD_U64LE')
    type = 'uint64';
elseif H5T.equal(tid, 'H5T_STD_I64LE')
    type = 'int64';
else
    error('NWB:IO:GetMatlabType:UnknownTypeID',...
        'This type id cannot be analyzed.  Perhaps it''s not numeric?');
end
end

