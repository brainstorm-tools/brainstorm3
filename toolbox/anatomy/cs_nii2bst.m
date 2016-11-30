function [vox2ras, sMri] = cs_nii2bst(sMri, vox2ras, isApply)
% CS_NII2BST: Converts a vox2ras transformation matrix from NIfTI format to Brainstorm format.
%
% USAGE:  [vox2ras, sMri] = cs_nii2bst(sMri, vox2ras, isApply=[ask])   % Transform the volume
%                 vox2ras = cs_nii2bst(sMri, vox2ras, isApply=[ask])   % Just fix the transformation

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Author: Francois Tadel, 2016

% Parse inputs
if (nargin < 3) || isempty(isApply)
    isApply = [];
end
isVolume = (nargin >= 2);

% Normalize rotation matrix
R = vox2ras(1:3,1:3);
R = bst_bsxfun(@rdivide, R, sqrt(sum(R.^2)));
% Binarize rotation matrix
for i = 1:3
    [val, Pmat(i)] = max(abs(R(i,:)));
    isFlip(i) = (R(i,Pmat(i)) < 0);
end
% Ask user
if isempty(isApply)
    if ~isequal(Pmat, [1 2 3]) || ~isequal(isFlip, [0 0 0])
        isApply = java_dialog('confirm', ['A transformation is available in the MRI file.' 10 10 ...
                                          'Do you want to apply it to the volume now?' 10 10], 'NIfTI MRI');
        if ~isApply
            vox2ras = [];
        end
    else
        isApply = 0;
    end
end
% Apply transformations
if isApply
    % Permute dimensions
    if isVolume
        sMri.Cube = permute(sMri.Cube, [Pmat 4]);
    end
    sMri.Voxsize = sMri.Voxsize(Pmat);
    % Flip matrix
    for i = 1:3
        if isFlip(i)
            if isVolume
                sMri.Cube = bst_flip(sMri.Cube,i);
            end
            vox2ras(i,:) = -vox2ras(i,:);
            R(i,:) = -R(i,:);
        end
    end
    % Rotation to apply to obtain a correctly oriented MRI
    vox2ras(1:3,1:3) = inv(R) * vox2ras(1:3,1:3);
    % Permute translation
    vox2ras(1:3,4) = permute(vox2ras(1:3,4), Pmat);
end
% Scale transformation matrix
if ~isempty(vox2ras)
    vox2ras(1:3,1:3) = bst_bsxfun(@rdivide, vox2ras(1:3,1:3), sMri.Voxsize(:));
end




