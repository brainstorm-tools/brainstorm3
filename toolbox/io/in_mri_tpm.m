function sMriTissue = in_mri_tpm(TpmFiles)
% IN_MRI_TPM: Load TPM for 6 tissues as a "Tissues" Brainstorm structure
%
% USAGE:  MriMat = in_mri_bst(TpmFiles);
%
% INPUT: 
%     - TpmFiles : Cell array of full paths to 6 TPM files. 
%                  Typically for SPM12: {'c1.nii', 'c2.nii', 'c3.nii', 'c4.nii', 'c5.nii', 'c6.nii'}
% OUTPUT:
%     - MriMat:  Brainstorm MRI structure

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

% Returned structure
sMriTissue = [];
% Find for each voxel in which tissue there is the highest probability
for iTissue = 1:length(TpmFiles)
    % Skip missing tissue
    if isempty(TpmFiles{iTissue})
        continue;
    end
    % Load probability map
    sMriProb = in_mri(TpmFiles{iTissue}, 'Nifti1', 0, 0);
    % First volume: Copy structure
    if isempty(sMriTissue)
        sMriTissue = sMriProb;
        sMriTissue.Cube = 0 .* sMriTissue.Cube;
        pCube = sMriTissue.Cube;
    end
    % Set label for the voxels that have a probability higher than the previous volumes
    maskLabel = ((sMriProb.Cube > pCube) & (sMriProb.Cube > 0));
    sMriTissue.Cube(maskLabel) = iTissue;
    pCube(maskLabel) = sMriProb.Cube(maskLabel);
end
% Return tissues atlas
if ~isempty(sMriTissue)
    % Replace background with zeros
    sMriTissue.Cube(sMriTissue.Cube == 6) = 0;
    % Add basic labels
    sMriTissue.Labels = mri_getlabels('tissues5');
    % Set comment
    sMriTissue.Comment = 'tissues';
end


