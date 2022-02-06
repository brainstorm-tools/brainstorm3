function TessMat = in_tess_vtk(TessFile)
% IN_TESS_VTK: Read Visualization Toolkit .vtk mesh files
%
% USAGE:  TessMat = in_tess_vtk(TessFile);
%
% INPUT: 
%     - TessFile : full path to a tesselation file
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure
% FORMAT:
%     ASCII file with the following structure:
%     - Header line 1: "# vtk DataFile Version ???"
%     - Header line 2: "surface file"
%     - Header line 3: "ASCII"
%     - Header line 4: "DATASET POLYDATA"
%     - Header line 5: "POINTS <nVertices>  float"
%     - Vertices     : nVertices lines ("x y z"), values in miliimeters
%     - Header line 6: "POLYGONS <nFaces> <nValues>"
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
% Read 5 lines of header
h1 = fgetl(fid);
h2 = fgetl(fid);
h3 = fgetl(fid);
h4 = fgetl(fid);
h5 = fgetl(fid);
% Check file format
if isempty(strfind(h1, 'vtk'))
    error('Not a valid VTF ASCII mesh file.');
end
% Get number of vertices
nVertices = sscanf(h5, '%*s %d %*s', 1);

% ===== READ MESH =====
% Read vertices
Vertices = double(fscanf(fid, '%f', [3 nVertices])) / 1000;
% Go to next line
fgetl(fid);
% Read number of faces
h6 = fgetl(fid);
res = textscan(h6, '%s %d', 1);
if ~iscell(res{1}) || isempty(res{1}) || ~ischar(res{1}{1}) || ~isequal(res{1}{1}, 'POLYGONS')
    error(['Unsupported faces format. Only "POLYGONS" is supported.']);
end
nFaces = res{2};
% Read faces
Faces = double(fscanf(fid, '%f',[4 nFaces]) + 1);
Faces = Faces(2:4,:);
% Close file
fclose(fid);


%% ===== CONVERT IN BRAINSTORM FORMAT =====
TessMat.Vertices = Vertices';
TessMat.Faces    = Faces';





