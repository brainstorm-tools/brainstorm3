function [NewTessFile, iSurface] = tess_force_envelope(TessFile, EnvFile)
% TESS_FORCE_ENVELOPE: Forces the vertices of a surface to fit entirely in an envelope.
%
% USAGE:  [NewTessFile, iSurface] = tess_force_envelope(TessFile, EnvFile)
% 
% INPUT: 
%    - TessFile : Full path to surface file to modify
%    - EnvFile  : Full path to the envelope surface
% OUTPUT:
%    - NewTessFile : Filename of the newly created file
%    - iSurface    : Index of the new surface file

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
% Authors: Francois Tadel, 2019

    
% ===== LOAD FILES =====
% Progress bar
bst_progress('start', 'Fix cortex surface', 'Loading surfaces...');
% Load surface file
TessMat = in_tess_bst(TessFile);
TessMat.Faces    = double(TessMat.Faces);
TessMat.Vertices = double(TessMat.Vertices);
% Load envelope file
EnvMat = in_tess_bst(EnvFile);
EnvMat.Faces    = double(EnvMat.Faces);
EnvMat.Vertices = double(EnvMat.Vertices);
% Compute best fitting sphere from envelope
bfs_center = bst_bfs(EnvMat.Vertices);


% ===== DEFORM SURFACE TO FIT IN ENVELOPE =====
% Center the two surfaces on the center of the sphere
vCortex = bst_bsxfun(@minus, TessMat.Vertices, bfs_center(:)');
vInner = bst_bsxfun(@minus, EnvMat.Vertices, bfs_center(:)');
% Convert to spherical coordinates
[thCortex, phiCortex, rCortex] = cart2sph(vCortex(:,1), vCortex(:,2), vCortex(:,3));
% Look for points of the cortex inside the innerskull
iVertOut = find(~inpolyhd(vCortex, vInner, EnvMat.Faces));
% If no points outside, nothing to do
if isempty(iVertOut)
    bst_progress('stop');
    java_dialog('msgbox', 'All cortex vertices are already inside the inner skull.', 'Fix cortex surface');
    return;
end
% Display where the outside points are
hFig = view_surface(TessFile, [], [], 'NewFigure');
panel_surface('SetSurfaceEdges', hFig, 1, 1);
line(TessMat.Vertices(iVertOut,1), TessMat.Vertices(iVertOut,2), TessMat.Vertices(iVertOut,3), 'LineStyle', 'none', 'Marker', 'o',  'MarkerFaceColor', [1 0 0], 'MarkerSize', 6);
view_surface(EnvFile, [], [], hFig);
figure_3d('SetStandardView', hFig, 'bottom');

% Fix point by point
for i = 1:length(iVertOut)
    bst_progress('start', 'Fix cortex surface', sprintf('Fixing vertex %d/%d...', i, length(iVertOut)));
    % While point is still outside: loop
    while ~inpolyhd(vCortex(iVertOut(i),:), vInner, EnvMat.Faces)
        % Find the other cortex points close to the outlier
        dist = sqrt(sum(bst_bsxfun(@minus, vCortex, vCortex(iVertOut(i),:)).^2, 2));
        maxDist = 0.01;
        iv = find(dist < maxDist);
        % Decrease the radius for the points in the neighborhood of the outliers
        correction = .00001 .* (maxDist-dist(iv)) ./ maxDist;
        rCortex(iv) = rCortex(iv) - correction;
        % Recompute cartesian coordinates of the vertices
        [vCortex(iv,1), vCortex(iv,2), vCortex(iv,3)] = sph2cart(thCortex(iv), phiCortex(iv), rCortex(iv));
    end
end
% Restore surface center
vCortex = bst_bsxfun(@plus, vCortex, bfs_center(:)');
% Output structure
NewTessMat = TessMat;
NewTessMat.Vertices = vCortex;


% ===== CREATE NEW SURFACE STRUCTURE =====
% Build new filename and Comment
[filepath, filebase, fileext] = bst_fileparts(file_fullpath(TessFile));
NewTessMat.Comment = [TessMat.Comment, '_fix'];
NewTessFile = file_unique(bst_fullfile(filepath, [filebase, '_fix', fileext]));
% Copy history field
if isfield(TessMat, 'History')
    NewTessMat.History = TessMat.History;
end
% History: Downsample surface
NewTessMat = bst_history('add', NewTessMat, 'fix', sprintf('%d vertices moved inside the inner skull.', length(iVertOut)));

% ===== UPDATE DATABASE =====
% Save downsized surface file
bst_save(NewTessFile, NewTessMat, 'v7');
% Make output filename relative
NewTessFile = file_short(NewTessFile);
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', TessFile);
% Register this file in Brainstorm database
iSurface = db_add_surface(iSubject, NewTessFile, NewTessMat.Comment);

% Display modified surface
hFig = view_surface(NewTessFile, [], [], 'NewFigure');
panel_surface('SetSurfaceEdges', hFig, 1, 1);
view_surface(EnvFile, [], [], hFig);
figure_3d('SetStandardView', hFig, 'bottom');

% Close progress bar
bst_progress('stop');


% % Display report
% java_dialog('msgbox', sprintf('%d vertices moved inside the inner skull.', length(iVertOut)), 'Fix cortex surface');


