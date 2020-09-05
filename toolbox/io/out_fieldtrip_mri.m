function ftMri = out_fieldtrip_mri(MriFile, FieldName)
% OUT_FIELDTRIP_MRI: Converts a MRI file into a FieldTrip structure (ft_datatype_volume.m)
% 
% USAGE:  ftMri = out_fieldtrip_mri(MriFile, FieldName='anatomy')     % Filename in input
%         ftMri = out_fieldtrip_mri(sMri,    FieldName='anatomy')     % Loaded structure in input

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
% Authors: Francois Tadel, 2016-2020

% Parse inputs
if (nargin < 2) || isempty(FieldName)
    FieldName = 'anatomy';
end

% Load data file
if ischar(MriFile)
    bstMri = in_mri_bst(MriFile);
else
    bstMri = MriFile;
end
% Keep only the first volume, if multiple
bstMri.Cube = bstMri.Cube(:,:,:,1);

% Check that the SCS coordinates are available
if isempty(bstMri.SCS.R) || isempty(bstMri.SCS.T)
    error('You must define the NAS/LPA/RPA fiducials before exporting MRI volumes in FieldTrip format.');
end

% Convert to a FieldTrip MRI in CTF coordinates
ftMri.dim         = size(bstMri.Cube);
ftMri.(FieldName) = bstMri.Cube;
ftMri.unit        = 'm';
ftMri.coordsys    = 'ctf';
ftMri.transform   = cs_convert(bstMri, 'voxel', 'scs');

% % Convert to a FieldTrip MRI
% ftMri.dim         = size(bstMri.Cube);
% ftMri.(FieldName) = bstMri.Cube(:, end:-1:1, end:-1:1);
% ftMri.unit        = 'mm';
% ftMri.coordsys    = 'ctf';
% 
% % If a vox2ras transformation exists: use it
% if isfield(bstMri, 'InitTransf') && ~isempty(bstMri.InitTransf) && any(ismember(bstMri.InitTransf(:,1), 'vox2ras'))
%     iTransf = find(strcmpi(bstMri.InitTransf(:,1), 'vox2ras'));
%     vox2ras = bstMri.InitTransf{iTransf(1),2};
%     % Convert to 0-based (nifti header) to 1-based (what FieldTrip uses)
%     ftMri.transform = inv(inv(vox2ras) + [zeros(4,3), [1;1;1;0]]);
% % Otherwise: Rough estimation of the original fieldtrip transformation (voxel=>head)
% elseif ~isempty(bstMri.SCS.R) && ~isempty(bstMri.SCS.T)
%     ftMri.transform = [bstMri.SCS.R, bstMri.SCS.T; 0 0 0 1] * ...                        % Brainstorm transformation MRI(mm) => SCS(mm)
%                       [diag([1 -1 -1]), [0; ftMri.dim(2); ftMri.dim(3)]; 0 0 0 1] * ...  % Transformation orientation convention
%                       diag([bstMri.Voxsize, 1]);                                         % Scaling MRI(voxel)=>MRI(mm)
% end
