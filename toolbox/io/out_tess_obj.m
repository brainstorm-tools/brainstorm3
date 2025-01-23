function out_tess_obj( TessMat, OutputFile )
% OUT_TESS_OBJ: Exports a surface to a .OBJ file.
% 
% USAGE:  out_tess_obj( TessMat, OutputFile )
%
% INPUT: 
%    - TessMat    : surface structure
%    - OutputFile : full path to output file (with '.obj' extension)

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
% Authors: Étienne Léger, 2023

% ===== PREPARE VALUES ======
Faces = TessMat.Faces;
% Vertices: convert to millimeters
Vertices = TessMat.Vertices .* 1000;

% ===== SAVE FILE =====
% Open file
[fid, message] = fopen(OutputFile, 'wt');
if (fid < 0)
    error(['Could not create file : ' message]);
end
% Write vertices
fprintf(fid, 'v %f\t%f\t%f\n', Vertices');
% Write faces
fprintf(fid, 'f %d\t%d\t%d\n', Faces');
% Close file
fclose(fid);


