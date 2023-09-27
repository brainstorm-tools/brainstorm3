function sMri = mri_add_world(MriFile, sMri)
% MRI_ADD_WORLD: Add a default "world" transformation to a MRI.

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
% Authors: Francois Tadel, 2023

% If MRI is not loaded yet
if (nargin < 2) || isempty(sMri)
    sMri = in_mri_bst(MriFile);
end

% A vox2ras matrix must be present in the MRI for running CAT12
if ~isfield(sMri, 'InitTransf') || isempty(sMri.InitTransf) || ~any(strcmpi(sMri.InitTransf(:,1), 'vox2ras'))
    disp('BST> Adding default world transformation to MRI...');
    % Add vox2ras
    sMri.InitTransf = {'vox2ras', ...
        [1, 0, 0, -size(sMri.Cube,1) / 2 .* sMri.Voxsize(1); ...
         0, 1, 0, -size(sMri.Cube,2) / 2 .* sMri.Voxsize(2); ...
         0, 0, 1, -size(sMri.Cube,3) / 2 .* sMri.Voxsize(3); ...
         0, 0, 0, 1]};
    % Remove existing NIFTI header because it would cause incompatibilities
    sMri.Header = [];
    % Save modification
    bst_save(file_fullpath(MriFile), sMri, 'v7');
end

