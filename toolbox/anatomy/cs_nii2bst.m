function [vox2ras, sMri] = cs_nii2bst(sMri, vox2ras, isApply)
% CS_NII2BST: Converts a vox2ras transformation matrix from NIfTI format to Brainstorm format.
%
% USAGE:  [vox2ras, sMri] = cs_nii2bst(sMri, vox2ras, isApply=[ask])   % Transform the volume
%                 vox2ras = cs_nii2bst(sMri, vox2ras, isApply=[ask])   % Just fix the transformation

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
% Author: Francois Tadel, 2016-2021

% Parse inputs
if (nargin < 3) || isempty(isApply)
    isApply = [];
end


% Normalize rotation matrix
R = vox2ras(1:3,1:3);
R = bst_bsxfun(@rdivide, R, sqrt(sum(R.^2)));
TransPerm = zeros(4);
TransPerm(4,4) = 1;
% Define what is the best possible orientation for the volume
for i = 1:3
    [val, Pmat(i)] = max(abs(R(i,:)));
    isFlip(i) = (R(i,Pmat(i)) < 0);
    TransPerm(i,Pmat(i)) = 1;
end

% Ask user
if isempty(isApply)
    if ~isequal(Pmat, [1 2 3]) || ~isequal(isFlip, [0 0 0])
        isApply = java_dialog('confirm', ['A transformation is available in the MRI file.' 10 10 ...
                                          'Do you want to apply it to the volume now?' 10 10], 'MRI orientation');
    else
        isApply = 0;
    end
end

% Apply transformations
if isApply
    % Permute dimensions
    sMri.Cube = permute(sMri.Cube, [Pmat 4]);
    sMri.Voxsize = sMri.Voxsize(Pmat);
    % Flip matrix
    TransFlip = eye(4);
    for i = 1:3
        if isFlip(i)
            sMri.Cube = bst_flip(sMri.Cube,i);
            TransFlip(i,i) = -1;
            TransFlip(i,4) = size(sMri.Cube,i) - 1;
        end
    end
    % Apply all transformations
    vox2ras = vox2ras * inv(TransFlip * TransPerm);
    % Set the sform/qform transformations from the nifti header
    if isfield(sMri, 'Header') && isfield(sMri.Header, 'nifti') && all(isfield(sMri.Header.nifti, {'qform_code', 'sform_code', 'quatern_b', 'quatern_c', 'quatern_d', 'qoffset_x', 'qoffset_y', 'qoffset_z', 'srow_x', 'srow_y', 'srow_z'}))
        % Set sform to NIFTI_XFORM_ALIGNED_ANAT 
        sMri.Header.nifti.sform_code = 2;
        sMri.Header.nifti.srow_x     = vox2ras(1,:);
        sMri.Header.nifti.srow_y     = vox2ras(2,:);
        sMri.Header.nifti.srow_z     = vox2ras(3,:);
        sMri.Header.nifti.sform      = vox2ras;
        % Remove qform
        sMri.Header.nifti.qform_code = 0;
        sMri.Header.nifti.quatern_b  = 0;
        sMri.Header.nifti.quatern_c  = 0;
        sMri.Header.nifti.quatern_d  = 0;
        sMri.Header.nifti.qoffset_x  = 0;
        sMri.Header.nifti.qoffset_y  = 0;
        sMri.Header.nifti.qoffset_z  = 0;
        sMri.Header.nifti.qform      = [];
        % Save final version
        sMri.Header.nifti.vox2ras = vox2ras;
    end
end


