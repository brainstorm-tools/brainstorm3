function out_tess_off( TessMat, OutputFile )
% OUT_TESS_OFF: Exports a surface to a .OFF file.
% 
% USAGE:  out_tess_off( TessMat, OutputFile )
%
% INPUT: 
%    - TessMat    : surface structure
%    - OutputFile : full path to output file (with '.off' extension)

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

% ===== PREPARE VALUES ======
% Faces : remove 1 (convert to 0-based indices)
Faces = TessMat.Faces - 1;
Vertices = TessMat.Vertices;

% ===== SAVE FILE =====
% Open file
[fid, message] = fopen(OutputFile, 'wt');
if (fid < 0)
    error(['Could not create file : ' message]);
end
% Write header
fprintf(fid, 'OFF\n');
fprintf(fid, '%d\t%d\t%d\n', size(Vertices,1), size(Faces,1), 0);
% Write vertices
fprintf(fid, '%f\t%f\t%f\n', Vertices');
% Add the number of vertices to each face
Faces = [repmat(3,size(Faces,1),1), Faces];
% Write faces
fprintf(fid, '%d\t%d\t%d\t%d\n', Faces');
% Close file
fclose(fid);


