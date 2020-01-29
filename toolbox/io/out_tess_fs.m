function out_tess_fs( TessMat, OutputFile )
% OUT_TESS_FS: Exports a surface to a FreeSurfer file.
% 
% USAGE:  out_tess_fs( TessMat, OutputFile )
%
% INPUT: 
%    - TessMat    : Brainstorm tesselation matrix
%    - OutputFile : full path to output file

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
%          Inspired from MNE's mne_read_surface.m, Matti Hamalainen, 2009

% Prepare values
Vertices = TessMat.Vertices' .* 1000;
Faces    = TessMat.Faces' - 1;

% Open file for binary writing
[fid, message] = fopen(OutputFile, 'wb', 'ieee-be');
if (fid < 0)
    error(['Could not create file : ' message]);
end

% Write file magic number:   TRIANGLE_FILE_MAGIC_NUMBER
fwrite_uint24(fid, 16777214);
% Write comment
%fwrite(fid, ['created by brainstorm on ' datestr(now,'ddd mmm dd HH:MM:SS yyyy') 10 0], 'uint8');
fwrite(fid, ['created by ftadel on Tue Apr  9 18:39:38 2013' 10 10], 'uint8');
% Write number of faces of and vertices
fwrite(fid, size(TessMat.Vertices,1), 'int32');
fwrite(fid, size(TessMat.Faces,1), 'int32');
% Write vertices
fwrite(fid, Vertices(:), 'float32');
% Write faces
fwrite(fid, Faces(:), 'int32');

% Close file
fclose(fid);

end


%% ===== SUPPORT FUNCTIONS =====
function n = fwrite_uint24(fid, val)
    % Convert input values to uint32
    val = uint32(val);
    % Convert from little endian to big endian
    val = swapbytes(val);
    % Typecast to uchar
    val = typecast(val, 'uint8');
    % Keep only the 3 last bytes of each value
    val(1:4:end) = [];
    % Write the uint24 values
    n = fwrite(fid, val, 'uint8');
end

