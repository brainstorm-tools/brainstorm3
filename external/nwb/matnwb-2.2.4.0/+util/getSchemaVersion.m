function versionString = getSchemaVersion(filename)
fid = H5F.open(filename);
aid = H5A.open(fid, 'nwb_version');
versionString = H5A.read(aid);
H5A.close(aid);
H5F.close(fid);
end