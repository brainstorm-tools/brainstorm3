function TessMat = in_tess_off(TessFile)
% IN_TESS_OFF: Read Geomview .off mesh files
%
% USAGE:  TessMat = in_tess_off(TessFile);
%
% INPUT: 
%     - TessFile : full path to a tesselation file
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure
% FORMAT:
%     ASCII file with four blocks:
%     - Header line 1: "OFF"
%     - Header line 2: "nVertices nFaces ?"
%     - Vertices     : nVertices lines ("x y z"), values in miliimeters
%     - Faces        : nFaces lines ("nvert vertex1 vertex2 vertex3")
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
% Authors: Francois Tadel, 2012

% Open tesselation file
fid = fopen(TessFile, 'r');
if fid < 0
    error(['Cannot open file ', TessFile])
end

% ===== READ HEADER =====
% Read format name
h1 = fgetl(fid);
if ~strcmpi(h1, 'OFF')
    error('Not a valid Geomview .off file.');
end
% Read number of vertices and faces
h2 = fgetl(fid);
dim = sscanf(h2, '%d', 2);
nVertices = dim(1);
nFaces    = dim(2);

% ===== READ MESH =====
% Read vertices
Vertices = double(fscanf(fid, '%f', [3 nVertices]));
% Go to next line
fgetl(fid);
% Read faces
Faces = double(fscanf(fid, '%f',[4 nFaces]) + 1);
Faces = Faces(2:4,:);
% Close file
fclose(fid);


%% ===== CONVERT IN BRAINSTORM FORMAT =====
TessMat.Vertices = Vertices';
TessMat.Faces    = Faces';


