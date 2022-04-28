function TessMat = in_tess_mniobj( TessFile )
% IN_TESS_MNIOBJ: Load a MNI OBJ surface file.

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


% ===== READ SURFACE FILE =====
% Open file
fid = fopen(TessFile, 'rt');
if (fid < 0)
   error('Cannot open obj file.'); 
end
% Read first line: file header
objClass = fscanf(fid,'%c',1);
if ~strcmpi(objClass, 'P')
    error('This function can only read polygons .obj files.');
end
surfprop = fscanf(fid,'%f',5);
nVertices  = fscanf(fid,'%d',1);
% Read vertex coordinates
Vertices = fscanf(fid, '%f', [3,nVertices]);
% Read normals
VertNormals = fscanf(fid, '%f', [3,nVertices])';

% Read number of faces
nFaces = fscanf(fid, '%d', 1);
% Read other face info
colorinfo = fscanf(fid, '%d', 5);
end_indices = fscanf(fid, '%d', nFaces);
% Read faces
Faces = fscanf(fid, '%f', [3,nFaces]);
% Close file
fclose(fid);


% ===== READ XFM FILE =====
% Try to get the .xfm fil in ../transforms/linear/
dirXfm = bst_fullfile(fileparts(fileparts(TessFile)), 'transforms', 'linear');
listXfm = dir(bst_fullfile(dirXfm, '*_t1_tal.xfm'));
% Try to get the .xfm fil in ./
if isempty(listXfm)
    dirXfm = fileparts(TessFile);
    listXfm = dir(bst_fullfile(dirXfm, '*_t1_tal.xfm'));
end
% Cannot find transformation: Cannot align back on the MRI
if isempty(listXfm)
    disp('BST> Error: T1 transformation not found in the CIVET folder structure. Cannot register the surface on the MRI.');
end
% Get the Xfm filename
XfmFile = bst_fullfile(dirXfm, listXfm(1).name);

% Load the file
fid = fopen(XfmFile, 'rt');
if (fid < 0)
   error('Cannot xfm open file.'); 
end
strXfm = fread(fid, Inf, '*char')';
fclose(fid);
% Find the "Linear_Transform =" string
tag = 'Linear_Transform =';
iTag = strfind(strXfm, tag);
if isempty(iTag)
   error('Invalid xfm file.'); 
end
% Read transform
xfm = sscanf(strXfm(iTag+length(tag):end), '%f', [4, 3])';

% ===== CONVERT SURFACE TO MRI COORDINATES =====
% Initialize returned variable
TessMat.Vertices = Vertices';
TessMat.Faces    = Faces';
% Convert to 1-based indices
TessMat.Faces = Faces' + 1;
% Swap faces
TessMat.Faces = TessMat.Faces(:,[2 1 3]);

% Invert (T1 => TAL) transform
% R = inv(xfm(:,1:3));
% T = -xfm(:,4)' ./ 100;
xfm(4,1:4) = [0 0 0 1];
invxfm = inv(xfm);
R = invxfm(1:3,1:3);
T = invxfm(1:3,4)';

% % Apply on the vertices of the surface
TessMat.Vertices = TessMat.Vertices * R';
TessMat.Vertices = bst_bsxfun(@plus, TessMat.Vertices, T);

% Convert to meters
TessMat.Vertices = TessMat.Vertices ./ 1000;
