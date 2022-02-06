function out_mri_gis( sMri, OutputFile )
% OUT_MRI_GIS: Exports a Brainstorm MRI in GIS/BrainVisa file format (little endian).
%
% USAGE:  out_mri_gis( sMri, OutputFile )
%
% INPUT: 
%    - sMri       : Brainstorm MRI structure
%    - OutputFile : full path to output file (with '.ima' extension)
%
% FORMAT: 
%    GIS MRI Format is divided in two files : mri.dim and mri.ima
%    - DIM file: ASCII file with volume information
%                "<sizeX> <sizeY> <sizeZ> <sizeT>"
%                "-type <data_format>"                 : Uses only "S16" (int16)
%                "-dx <dx> -dy <dy> -dz <dz> -dt <dt>"
%                "-bo <byte_order>"                    : Uses only "DCBA" (Little endian)
%                "-om <file_type>"                     : Uses only "binar"
%    - IMA file: Binary or ASCII file with volume values
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
% Authors: Francois Tadel, 2008-2015

% ===== PARSE INPUTS =====
OutputFile = strrep(OutputFile, '.ima', '');
OutputFile = strrep(OutputFile, '.dim', '');
OutputFile_ima = [OutputFile, '.ima'];
OutputFile_dim = [OutputFile, '.dim'];

% ===== SAVE GIS VOLUME (.IMA) =====
% Open .ima file in LITTLE ENDIAN FORMAT
fid = fopen(OutputFile_ima, 'wb', 'l');
if (fid < 0)
   error('Cannot open file'); 
end
% Prepare volume matrix
OutputVolume = int16(sMri.Cube(:,:,:,1));
OutputVolume = OutputVolume(end:-1:1, end:-1:1, end:-1:1);
% Save volume matrix
fwrite(fid, OutputVolume, 'int16');
% Close file
fclose(fid);


% ===== SAVE GIS HEADER (.DIM) =====
% Open .dim file in ASCII format
fid = fopen(OutputFile_dim, 'wt');
if (fid < 0)
   error('Cannot open file'); 
end
% Prepare header
header = sprintf(['%d %d %d 1\n' ...
                  '-type S16\n' ...
                  '-dx %f -dy %f -dz %f -dt 1\n' ...
                  '-bo DCBA\n' ...
                  '-om binar\n'], ...
                  size(OutputVolume, 1), size(OutputVolume, 2), size(OutputVolume, 3), ...
                  sMri.Voxsize(1), sMri.Voxsize(2), sMri.Voxsize(3));
% Save header
fwrite(fid, header, 'char');
% Close file
fclose(fid);




