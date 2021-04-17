function [nVertices, nFaces, BstMat] = out_tess_tri( BstFile, OutputFile, isOpenMEEG )
% OUT_TESS_TRI: Exports a surface to a BrainVISA ASCII .tri file.
% 
% USAGE:  [nVertices, nFaces] = out_tess_tri( BstFile, OutputFile )
%         [nVertices, nFaces] = out_tess_tri( BstFile/TessMat, OutputFile, isOpenMEEG=0 )
%
% INPUT: 
%    - BstFile    : full path to Brainstorm file to export
%    - OutputFile : full path to output file (with '.tri' extension)
%    - isOpenMEEG : if flag set to 1, write the positions in meters instead of millimeters

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
% Authors: Francois Tadel, 2011-2019

if (nargin < 3) || isempty(isOpenMEEG)
    isOpenMEEG = 0;
end

% ===== LOAD BRAINSTORM SURFACE =====
if ischar(BstFile)
    BstMat = in_tess_bst(BstFile);
else
    BstMat = BstFile;
end

% ===== PREPARE VALUES ======
% Vertices (=> in millimeters)
if ~isOpenMEEG
    BstMat.Vertices = BstMat.Vertices * 1000;
end
% Faces : remove 1 (convert to 0-based indices)
Faces = BstMat.Faces - 1;
% Normals
VertNormals = BstMat.VertNormals;
% Return surface sizes
nVertices = length(BstMat.Vertices);
nFaces = length(BstMat.Faces);

% ===== SAVE FILE =====
% Open file
[fid, message] = fopen(OutputFile, 'w');
if (fid < 0)
    error(['Could not create file : ' message]);
end
% Write vertices and normals
fprintf(fid, '- %g\n', size(BstMat.Vertices,1));
fprintf(fid, '%g %g %g %g %g %g\n', [BstMat.Vertices, VertNormals]');
% Write faces
nfaces = size(Faces,1);
fprintf(fid, '- %g %g %g\n', [nfaces nfaces nfaces]);
fprintf(fid, '%g %g %g\n', Faces');
% Close file
fclose(fid);


