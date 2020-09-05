function [sph_vert, sph_faces] = tess_remesh(vert, nvert, isCenter)
% TESS_REMESH: Remesh a closed and non-overlapping tesselation with regularly spaced points.
%
% USAGE:  [sph_vert, sph_faces] = tess_remesh(SurfaceFile, nvert=[ask], isCenter=1)
%         [sph_vert, sph_faces] = tess_remesh(vert,        nvert=[ask], isCenter=0)
%
% INPUTS: 
%    - SurfaceFile : Absolute or relative path to the surface file to remesh
%    - vert        : [nVertices x 3] matrix of xyz vertices
%    - nvert       : Number of vertices in the output mesh, possible values
%                    [12 32 42 92 122 162 273 362 482 642 812 1082 1442 1922 2432 2562 3242 4322 5762 7682 7292 9722 10242 12962]
%    - isCenter    : If 1, center the surface points on the center of mass first (average of all the points)

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
% Authors: Francois Tadel, 2011-2016

%% ===== PARSE INPUTS =====
% Center?
if (nargin < 3) || isempty(isCenter)
    isCenter = [];
end
% Number of vertices
if (nargin < 2) || isempty(nvert)
    % Ask user the new number of vertices
    nvert = java_dialog('input', ['Deform a sphere to map a simple closed surface.' 10 10 ...
                                  'Warning: The surface has to be parametrizable in spherical coordinates.' 10 ...
                                  'If the surface is not a simple envelope, the output will be wrong.' 10 ...
                                  'Do not apply to cortex surfaces: use the "Less vertices" menu instead.' 10 10 ...
                                  'Number of vertices:'], ...
                                 'Remesh surface', [], '1922');
    if isempty(nvert) || isnan(str2double(nvert))
        return
    end
    % Read user input
    nvert = str2double(nvert);
end
% Progress bar
isProgress = bst_progress('IsVisible');
if ~isProgress
    bst_progress('start', 'Remesh surface', 'Remesh: Initializations...');
end
% Surface input
if ischar(vert)
    % Load surface file
    SurfaceFile = vert;
    [SurfaceMat, SurfaceFile] = in_tess_bst(SurfaceFile);
    vert = SurfaceMat.Vertices;
    % By default: center on the average of the points
    if isempty(isCenter)
        isCenter = 1;
    end
else
    SurfaceFile = [];
    % By default: Consider the files is already centered
    if isempty(isCenter)
        isCenter = 0;
    end
end


%% ===== CREATE SPHERE =====
if ~isProgress
    bst_progress('text', 'Remesh: Growing sphere...');
end
% Center surface on its center of mass
if isCenter
    center = mean(vert);
    vert = bst_bsxfun(@minus, vert, center);
end
% Compute an apolar sphere
[sph_vert, sph_faces] = tess_sphere(nvert);
% Get surface bounding box
bounds = abs([min(vert); max(vert)]);
% Scale with the surface
for dim = 1:3
    i = find(sph_vert(:,dim) < 0);
    sph_vert(i,dim) = sph_vert(i,dim) .* bounds(1,dim);
    i = find(sph_vert(:,dim) >= 0);
    sph_vert(i,dim) = sph_vert(i,dim) .* bounds(2,dim);
end


%% ===== PROJECT SPHERE VERTICES ON CORTEX (1) =====
% Convert both surfaces in spherical coordinates
[sph_th, sph_phi, sph_r] = cart2sph(sph_vert(:,1), sph_vert(:,2), sph_vert(:,3));
[env_th, env_phi, env_r] = cart2sph(vert(:,1), vert(:,2), vert(:,3));
% Add circular values on both sides for theta and phi, to have a more uniform interpolation function
env_th  = [env_th;  env_th+2*pi;  env_th-2*pi];
env_phi = [env_phi; env_phi;      env_phi    ];
env_r   = [env_r;   env_r;        env_r      ];
% Reinterpolate values of radius for the sphere, based on the values of the cortex envelope
sph_r_tmp = griddata(env_th, env_phi, env_r, sph_th, sph_phi, 'linear');
sph_r(~isnan(sph_r_tmp)) = sph_r_tmp(~isnan(sph_r_tmp));
% Convert back the sphere in xyz coordinates
[sph_vert(:,1), sph_vert(:,2), sph_vert(:,3)] = sph2cart(sph_th, sph_phi, sph_r);
% Find vertices that are too close to phi=pi/2 or phi=-pi/2
iPhiLimit = find((sph_phi > .8*pi/2) | (sph_phi < -.8*pi/2))';

%% ===== PROJECT SPHERE VERTICES ON CORTEX (2) =====
% Do it again, switching X and Z dimensions, to avoid problem around phi=pi/2 and phi=-pi/2
[sph_th, sph_phi, sph_r] = cart2sph(sph_vert(iPhiLimit,3), sph_vert(iPhiLimit,2), sph_vert(iPhiLimit,1));
[env_th, env_phi, env_r] = cart2sph(vert(:,3), vert(:,2), vert(:,1));
% Add circular values on both sides for theta and phi, to have a more uniform interpolation function
env_th  = [env_th;  env_th+2*pi;  env_th-2*pi];
env_phi = [env_phi; env_phi;      env_phi    ];
env_r   = [env_r;   env_r;        env_r      ];
% Reinterpolate values of radius for the sphere, based on the values of the cortex envelope
sph_r_tmp = griddata(env_th, env_phi, env_r, sph_th, sph_phi, 'linear');
sph_r(~isnan(sph_r_tmp)) = sph_r_tmp(~isnan(sph_r_tmp));
% Convert back the sphere in xyz coordinates
[sph_vert(iPhiLimit,3), sph_vert(iPhiLimit,2), sph_vert(iPhiLimit,1)] = sph2cart(sph_th, sph_phi, sph_r);

% Restore center
if isCenter
    sph_vert = bst_bsxfun(@plus, sph_vert, center);
end


%% ===== SAVE RESULTS IN FILE =====
if ~isempty(SurfaceFile)
    if ~isProgress
        bst_progress('text', 'Remesh: Saving new file...');
    end
    % Output structure
    tag = sprintf('_remesh%dV', length(sph_vert));
    OutputMat.Comment = [SurfaceMat.Comment, tag];
    OutputMat.Vertices = sph_vert;
    OutputMat.Faces    = sph_faces;
    % Output filename
    OutputFile = strrep(SurfaceFile, '.mat', [tag, '.mat']);
    OutputFile = file_unique(OutputFile);
    % Save file
    bst_save(OutputFile, OutputMat, 'v7');

    % Get subject
    [sSubject, iSubject, iTess] = bst_get('SurfaceFile', SurfaceFile);
    % If input file is registered in the database, register output file too
    if ~isempty(sSubject)
        db_add_surface(iSubject, OutputFile, OutputMat.Comment, sSubject.Surface(iTess).SurfaceType);
    end
    % Output variables
    sph_vert = OutputFile;
    sph_faces = [];
end
if ~isProgress
    bst_progress('stop');
end
