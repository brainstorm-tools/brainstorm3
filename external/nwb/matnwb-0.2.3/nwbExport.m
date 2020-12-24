function nwbExport(nwb, filenames)
%NWBEXPORT Writes an NWB file.
%  nwbRead(nwb,filename) Writes the nwb object to a file at filename.
%
%  Example:
%    % Generate Matlab code for the NWB objects from the core schema.
%    % This only needs to be done once.
%    generateCore('schema\core\nwb.namespace.yaml');
%    % Create some fake fata and write
%    nwb = NwbFile;
%    nwb.session_start_time = datetime('now');
%    nwb.identifier = 'EMPTY';
%    nwb.session_description = 'empty test file';
%    nwbExport(nwb, 'empty.nwb');
%
%  See also GENERATECORE, GENERATEEXTENSION, NWBFILE, NWBREAD
validateattributes(nwb, {'NwbFile'}, {'nonempty'});
validateattributes(filenames, {'cell', 'string', 'char'}, {'nonempty'});
if iscell(filenames)
    assert(iscellstr(filenames), 'filename cell array must consist of strings');
end
if ~isscalar(nwb)
    assert(~ischar(filenames) && length(filenames) == length(nwb), ...
        'NwbFile and filename array dimensions must match.');
end

for i=1:length(nwb)
    if iscellstr(filenames)
        filename = filenames{i};
    elseif isstring(filenames)
        filename = filenames(i);
    else
        filename = filenames;
    end
    export(nwb(i), filename);
end
end
