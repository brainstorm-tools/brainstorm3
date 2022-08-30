function sMri = import_mnireg(sMri, RegFile, RegInvFile, Method)
% IMPORT_MNIREG: Add deformation fields for MNI normalization.
%
% USAGE:  sMri = import_mnireg(sMri, RegFile, RegInvFile, Method)
%
% INPUTS:
%    - sMri       : Brainstorm MRI structure
%    - RegFile    : SPM file y_*.nii, forward MNI deformation field
%                   Used for coverting from MNI to MRI coordinates in cs_convert
%                   The .nii must contain 3 volumes (X,Y,Z)
%    - RegInvFile : SPM file iy_*.nii, inverse MNI deformation field
%                   Used for coverting from MNI to MRI coordinates in cs_convert
%                   The .nii must contain 3 volumes (X,Y,Z)

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


%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(RegInvFile)
    RegInvFile = [];
end
if (nargin < 2) || isempty(RegFile)
    RegFile = [];
end

%% ===== READ FILES =====
% Read registration volumes
if ~isempty(RegInvFile)
    sReg = in_mri(RegInvFile, 'ALL', 0, 0);
    sMri.NCS.iy = sReg.Cube;
    sMri.NCS.iy(sMri.NCS.iy == 0) = NaN;
else
    sMri.NCS.iy = [];
end
if ~isempty(RegFile)
    [sReg, vox2ras] = in_mri(RegFile, 'ALL', 0, 0);
    sMri.NCS.y = sReg.Cube;
    sMri.NCS.y(sMri.NCS.y == 0) = NaN;
    sMri.NCS.y_vox2ras = vox2ras;
else
    sMri.NCS.y = [];
end
% Save method
sMri.NCS.y_method = Method;


%% ===== COMPUTE DEFAULT FIDUCIALS =====
if ~isempty(RegFile) && (~isfield(sMri.NCS, 'AC') || ~isfield(sMri.NCS, 'PC') || ~isfield(sMri.NCS, 'IH') || isempty(sMri.NCS.AC) || isempty(sMri.NCS.PC) || isempty(sMri.NCS.IH))
    sMri = mri_set_default_fid(sMri, Method);
end



