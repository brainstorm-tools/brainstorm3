function sMriReg = mri_reslice_mni(sMriMni, sMriRef, isAtlas)
% MRI_RESLICE_MNI: Relice a MNI parcellation or volume into subject space (using linear or non-linear MNI registration).
%
% USAGE:  sMriReg = mri_reslice_mni(sMriMni, sMriRef, isAtlas)
%
% INPUTS:
%    - sMriMni : MNI parcellation to reslice, as a Brainstorm MRI structure
%    - sMriRef : Reference subject MRI volume, as a Brainstorm MRI structure
%    - isAtlas : If 1, the input and output values must be only integer
%
% OUTPUTS:
%    - sMriReg : Brainstorm MRI structure with the resliced volume
%    - errMsg  : Error messages if any

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
% Authors: Francois Tadel, 2020

% If no MNI normalization: error
if ~isfield(sMriRef, 'NCS') || ...
        ((~isfield(sMriRef.NCS, 'R') || ~isfield(sMriRef.NCS, 'T') || isempty(sMriRef.NCS.R) || isempty(sMriRef.NCS.T)) && ... 
         (~isfield(sMriRef.NCS, 'iy') || isempty(sMriRef.NCS.iy)))
    error('The subject anatomy must be normalized to MNI space first.');
end
% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MNI parcellation', 'Reslicing MNI parcellation...');
end

% ===== INTERPOLATE MRI VOLUME =====
bst_progress('text', 'Computing MNI grid...');
% Original position vectors
XYZ1bounds = [0,0,0; size(sMriMni.Cube) - 1] + 0.5;
XYZ1boundsMni = cs_convert(sMriMni, 'voxel', 'world', XYZ1bounds);
X1 = linspace(XYZ1boundsMni(1,1), XYZ1boundsMni(2,1), size(sMriMni.Cube,1));
Y1 = linspace(XYZ1boundsMni(1,2), XYZ1boundsMni(2,2), size(sMriMni.Cube,2));
Z1 = linspace(XYZ1boundsMni(1,3), XYZ1boundsMni(2,3), size(sMriMni.Cube,3));

% Reference position vectors
X2 = ((0:size(sMriRef.Cube,1)-1) + 0.5);
Y2 = ((0:size(sMriRef.Cube,2)-1) + 0.5);
Z2 = ((0:size(sMriRef.Cube,3)-1) + 0.5);
% Mesh grids (WATCH OUT FOR THE X/Y PERMUTATION OF MESHGRID!)
[Xgrid2, Ygrid2, Zgrid2] = meshgrid(Y2, X2, Z2);
% Apply transformation: reference MRI => MNI
allGrid = [Ygrid2(:), Xgrid2(:), Zgrid2(:)];
allGridMni = cs_convert(sMriRef, 'voxel', 'mni', allGrid);
allGridMni(allGridMni == 0) = NaN;
% Reformat as grids
Xgrid2mni = reshape(allGridMni(:,2), size(Xgrid2));
Ygrid2mni = reshape(allGridMni(:,1), size(Ygrid2));
Zgrid2mni = reshape(allGridMni(:,3), size(Zgrid2));

bst_progress('text', 'Reslicing volume...');
% Nearest neighbor interpolation (parcellation labels = integers)
if isAtlas
    newCube = interp3(Y1, X1, Z1, sMriMni.Cube, Xgrid2mni, Ygrid2mni, Zgrid2mni, 'nearest', NaN);
% Cubic interpolation for floating point values
else
    newCube = single(interp3(Y1, X1, Z1, double(sMriSrc.Cube), Xgrid2mni, Ygrid2mni, Zgrid2mni, 'cubic', 0));
end
% Replace bad values with 0 (points that do not have MNI coordinates)
newCube(isnan(newCube)) = 0;
newCube(any(allGridMni == 0, 2)) = 0;


% ===== RETURNED STRUCTURE =====
% Return resliced volume
sMriReg         = sMriRef;
sMriReg.Cube    = newCube;
sMriReg.Comment = sMriMni.Comment;
if isfield(sMriMni, 'Labels') && ~isempty(sMriMni.Labels)
    sMriReg.Labels = sMriMni.Labels;
end

% Close progress bar
if ~isProgress
    bst_progress('stop');
end



