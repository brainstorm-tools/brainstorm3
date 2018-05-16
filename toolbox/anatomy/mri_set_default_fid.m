function sMri = mri_set_default_fid(sMri)
% MRI_SET_DEFAULT_FID:  Set default fiducials based on the MNI transformation

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017

% ===== NCS FIDUCIALS =====
% MNI coordinates for all the fiducials
AC  = [0,   3,  -4] ./ 1000;
PC  = [0, -25,  -2] ./ 1000;
IH  = [0, -10,  60] ./ 1000;
Orig= [0,   0,   0];
% Convert: MNI (meters) => MRI (millimeters)
sMri.NCS.AC     = cs_convert(sMri, 'mni', 'mri', AC) .* 1000;
sMri.NCS.PC     = cs_convert(sMri, 'mni', 'mri', PC) .* 1000;
sMri.NCS.IH     = cs_convert(sMri, 'mni', 'mri', IH) .* 1000;
sMri.NCS.Origin = cs_convert(sMri, 'mni', 'mri', Orig) .* 1000;

% ===== SCS FIDUCIALS =====
% Compute default positions for NAS/LPA/RPA if not available yet
if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') ...
        || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA) 
    NAS = [ 0,   84, -50] ./ 1000;
    LPA = [-83, -19, -48] ./ 1000;
    RPA = [ 83, -19, -48] ./ 1000;
    sMri.SCS.NAS = cs_convert(sMri, 'mni', 'mri', NAS) .* 1000;
    sMri.SCS.LPA = cs_convert(sMri, 'mni', 'mri', LPA) .* 1000;
    sMri.SCS.RPA = cs_convert(sMri, 'mni', 'mri', RPA) .* 1000;
    % Compute SCS transformation, if not available
    if ~isfield(sMri.SCS, 'R') || ~isfield(sMri.SCS, 'T') || isempty(sMri.SCS.R) || isempty(sMri.SCS.T)
        [Transf, sMri] = cs_compute(sMri, 'SCS');
    end
end


