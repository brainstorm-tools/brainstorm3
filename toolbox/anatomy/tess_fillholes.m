function [Vertices, Faces] = tess_fillholes(sMri, Vertices, Faces, fillFactor, erodeFinal)
% TESS_FILLHOLES: Fill the holes in a surface after a re-interpolation on a volume
%
% USAGE:  [Vertices, Faces, iRemoveVert] = tess_fillholes(sMri, Vertices, Faces, fillFactor=2, erodeFinal=2)

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
% Authors: Francois Tadel, 2012-2022

% ===== PARSE INPUTS =====
if (nargin < 5) || isempty(erodeFinal)
    erodeFinal = 2;
end
if (nargin < 4) || isempty(fillFactor)
    res = java_dialog('input', 'Fill holes factor [1,2,3]:', 'Fill holes', [], '2');
    % If user cancelled: return
    if isempty(res)
        return
    end
    % Get new values
    fillFactor = str2num(res);
    if isempty(fillFactor) || ~ismember(fillFactor, [1,2,3])
        bst_error('Invalid parameters.', 'Fill holes', 0);
        return
    end
end

% ===== COORDINATES: CONVERT TO MRI =====
% Remove small components
[Vertices, Faces] = tess_remove_small(Vertices, Faces);
% Vertices: SCS->Voxels
Vertices = cs_convert(sMri, 'scs', 'voxel', Vertices);
% Save number of vertices 
nVertices = length(Vertices);

% ===== MRI MASK =====
bst_progress('text', 'Fill: Computing interpolation...');
% Compute surface -> mri interpolation
mriSize = size(sMri.Cube(:,:,:,1));
tess2mri_interp = tess_tri_interp(Vertices, Faces, mriSize, 0);
% Compute mrimask
bst_progress('text', 'Fill: Computing MRI mask...');
mrimask = tess_mrimask(mriSize, tess2mri_interp);
% Fill holes in the MRI
bst_progress('text', 'Fill: Filling holes...');
if (fillFactor >= 1)
    nDimFill = 3 - fillFactor + 1;
    mrimask = (mri_fillholes(mrimask, 1) + mri_fillholes(mrimask, 2) + mri_fillholes(mrimask, 3) >= nDimFill);
end
% Closing all the faces of the cube
mrimask(1,:,:)   = 0*mrimask(1,:,:);
mrimask(end,:,:) = 0*mrimask(1,:,:);
mrimask(:,1,:)   = 0*mrimask(:,1,:);
mrimask(:,end,:) = 0*mrimask(:,1,:);
mrimask(:,:,1)   = 0*mrimask(:,:,1);
mrimask(:,:,end) = 0*mrimask(:,:,1);

% ===== CREATE SURFACE FROM MASK =====
% Erode one layer of the mask
if (erodeFinal >= 1)
    mrimask = mrimask & ~mri_dilate(~mrimask, erodeFinal);
end
% Compute isosurface
bst_progress('text', 'Fill: Creating isosurface...');
[Faces, Vertices] = mri_isosurface(mrimask, 0.5);
% Smooth isosurface
bst_progress('text', 'Fill: Smoothing surface...');
VertConn = tess_vertconn(Vertices, Faces);
Vertices = tess_smooth(Vertices, 1, 10, VertConn, 0);
% Downsampling isosurface
if (length(Vertices) > nVertices)
    bst_progress('text', 'Fill: Downsampling surface...');
    [Faces, Vertices] = reducepatch(Faces, Vertices, nVertices ./ length(Vertices));
end
% Remove small components
bst_progress('text', 'Fill: Removing small components...');
[Vertices, Faces] = tess_remove_small(Vertices, Faces);
% Clean final surface
bst_progress('text', 'Fill: Cleaning surface...');
[Vertices, Faces] = tess_clean(Vertices, Faces);
% One final round of smoothing
VertConn = tess_vertconn(Vertices, Faces);
Vertices = tess_smooth(Vertices, 0.2, 3, VertConn, 0);

% ===== COORDINATES: CONVERT TO SCS =====
% Swap face order and coordinates
Vertices = Vertices(:,[2,1,3]);
Faces    = Faces(:,[2,1,3]);
% Convert in millimeters
Vertices = bst_bsxfun(@times, Vertices, sMri.Voxsize);
% Convert in SCS coordinates
Vertices = cs_convert(sMri, 'mri', 'scs', Vertices ./ 1000);


