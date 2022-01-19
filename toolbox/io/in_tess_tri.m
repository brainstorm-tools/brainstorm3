function Tess = in_tess_tri(TessFile)
% IN_TESS_TRI: Read BrainVISA ASCII .tri file into Brainstorm format.
%
% USAGE:  TessMat = in_tess_tri(TessFile);
%
% INPUT: 
%     - TessFile : full path to a tesselation file
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure
% FORMAT:
%     ASCII file with four blocks:
%     - VHeader  : one line ("- nbVertices")
%     - Vertices : nbVertices lines ("x y z x2 y2 z2")
%     - FHeader  : one line ("- nbFaces nbFaces nbFaces")
%     - Faces    : nbFaces lines ("vertex1 vertex2 vertex3")
%
% SEE ALSO: in_tess

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
% Authors: Francois Tadel, 2008-2010

% Open tesselation file
fid = fopen(TessFile, 'r');
if fid < 0
    error(['Cannot open file ', TessFile])
end

% 1. Number of Vertices
nbVertices = abs(str2num(fgetl(fid))); 
% 2. Vertices
Vertices = double(fscanf(fid, '%f', [6 nbVertices]));   % FT 11-Jan-10: Remove "single"
Vertices = Vertices(1:3,:) / 1000;
% Don't know why I need to skip this line -> not empty in text file
fgetl(fid);
% 3. Number of faces
nbFaces = str2num(fgetl(fid));
nbFaces = abs(nbFaces(1));
% 4. Faces
Faces = double(fscanf(fid, '%f',[3 nbFaces]) + 1);   % FT 11-Jan-10: Remove "single"
fclose(fid);


%% ===== CONVERT IN BRAINSTORM FORMAT =====
Tess.Vertices = Vertices';
Tess.Faces    = Faces';





