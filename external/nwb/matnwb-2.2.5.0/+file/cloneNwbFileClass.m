function cloneNwbFileClass(typeFileName, fullTypeName)
%CLONENWBFILE Certain extensions can override the base NWBFile.  This cannot
% be dynamically adjusted as inheritance is generally static in MATLAB.
% So we go through path of least resistance and clone NwbFile.m

nwbFilePath = which('NwbFile');
installPath = fileparts(nwbFilePath);
fileId = fopen(nwbFilePath);
text = strrep(char(fread(fileId) .'),...
    'NwbFile < types.core.NWBFile',...
    sprintf('NwbFile < %s', fullTypeName));
fclose(fileId);

fileId = fopen(fullfile(installPath, [typeFileName '.m']), 'W');
fwrite(fileId, text);
fclose(fileId);
end

