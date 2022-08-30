function out_spm_gii( GiiTessFile, GiiDataFile, Data )
% OUT_TESS_GII: Exports a source map to a set of SPM/GIfTI .gii/.dat file.
% 
% USAGE:  out_spm_gii( GiiTessFile, GiiDataFile, Data )
%
% INPUT: 
%    - GiiTessFile : Brainstorm tesselation matrix
%    - GiiDataFile : full path to output file

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2013
 
% Get file paths
[giiPath, giiBase, giiExt] = bst_fileparts(GiiTessFile);
[outPath, outBase, outExt] = bst_fileparts(GiiDataFile);
% If the two files are in the same folder: do not use the path for the .gii surface
if strcmp(giiPath, outPath)
    GiiTessFile = [giiBase, giiExt];
end
% .dat filename, to save the actual data
DatFileShort = [outBase, '.dat'];
DatFile = bst_fullfile(outPath, DatFileShort);

% ===== CREATE XML STRING =====    
% Create XML file from a template
strXml = [...
    '<?xml version="1.0" encoding="UTF-8"?>' 13 10 ...
    '<!DOCTYPE GIFTI SYSTEM "http://www.nitrc.org/frs/download.php/115/gifti.dtd">' 13 10 ...
    '<GIFTI Version="1.0"  NumberOfDataArrays="1">' 13 10 ...
    '   <MetaData>' 13 10 ...
    '      <MD>' 13 10 ...
    '         <Name><![CDATA[SurfaceID]]></Name>' 13 10 ...
    '         <Value><![CDATA[' GiiTessFile ']]></Value>' 13 10 ...
    '      </MD>' 13 10 ...
    '   </MetaData>' 13 10 ...
    '   <LabelTable/>' 13 10 ...
    '   <DataArray  ArrayIndexingOrder="ColumnMajorOrder"' 13 10 ...
    '               DataType="NIFTI_TYPE_FLOAT32"' 13 10 ...
    '               Dim0="' num2str(size(Data,1)) '"' 13 10 ...
    '               Dim1="1"' 13 10 ...
    '               Dimensionality="2"' 13 10 ...
    '               Encoding="ExternalFileBinary"' 13 10 ...
    '               Endian="LittleEndian"' 13 10 ...
    '               ExternalFileName="' DatFileShort '"' 13 10 ...
    '               ExternalFileOffset="0"' 13 10 ...
    '               Intent="NIFTI_INTENT_NONE">' 13 10 ...
    '      <MetaData>' 13 10 ...
    '      </MetaData>' 13 10 ...
    '      <Data></Data>' 13 10 ...
    '   </DataArray>' 13 10 ...
    '</GIFTI>' 13 10];

% ===== SAVE XML FILE =====
% Open file for binary writing
[fid, message] = fopen(GiiDataFile, 'wb');
if (fid < 0)
    error(['Could not create file : ' message]);
end
% Write XML contents
fwrite(fid, strXml, 'char');
% Close file
fclose(fid);

% ===== SAVE DAT FILE =====
% Open file for binary writing
fid = fopen(DatFile,'w');
if (fid < 0)
    error(['Could not create file : ' message]);
end
% Write data vector
fwrite(fid, Data, 'float32');
% Close file
fclose(fid);


end



