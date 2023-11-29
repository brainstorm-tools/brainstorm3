function MRI = out_mri_bst( MRI, MriFile, Version)
% OUT_MRI_BST: Save a Brainstorm MRI structure.
% 
% USAGE:  MRI = out_mri_bst( MRI, MriFile )
%
% INPUT: 
%     - MRI     : Brainstorm MRI structure
%     - MriFile : full path to file where to save the MRI in brainstorm format
%     - Version : 'v6', fastest option, bigger files, no files >2Gb
%                 'v7', slower option, compressed, no files >2Gb (default)
%                 'v7.3', much slower, compressed, allows files >2Gb
% OUTPUT:
%     - MRI : Modified MRI structure
%
% NOTES:
%     - MRI structure:
%         |- Voxsize:   [x y z], size of each MRI voxel, in millimeters
%         |- Cube:      MRI volume 
%         |- SCS:       Subject Coordinate System definition
%         |    |- NAS:    [x y z] coordinates of the nasion, in voxels
%         |    |- LPA:    [x y z] coordinates of the left pre-auricular point, in voxels
%         |    |- RPA:    [x y z] coordinates of the right pre-auricular point, in voxels
%         |    |- R:      Rotation to convert MRI coordinates -> SCS coordinatesd
%         |    |- T:      Translation to convert MRI coordinates -> SCS coordinatesd
%         |- Landmarks[]: Additional user-defined landmarks
%         |- NCS:         Normalized Coordinates System (Talairach, MNI, ...)     
%         |    |- AC:             [x y z] coordinates of the Anterior Commissure, in voxels
%         |    |- PC:             [x y z] coordinates of the Posterior Commissure, in voxels
%         |    |- IH:             [x y z] coordinates of any Inter-Hemispheric point, in voxels
%         |- Comment:     MRI description

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
% Authors: Francois Tadel, 2008-2012

if nargin < 3
    Version = 'v7';
end

% ===== Clean-up MRI structure =====
% Remove (useless or old fieldnames)
Fields2BDeleted     = {'Origin','sag','ax','cor','hFiducials','header','filename'};
SCSFields2BDeleted  = {'Origin','Comment'};

for k = 1:length(Fields2BDeleted)
    if isfield(MRI,Fields2BDeleted{k})
        MRI = rmfield(MRI,Fields2BDeleted{k});
    end
end

if isfield(MRI,'SCS')
    for k = 1:length(SCSFields2BDeleted)
        if isfield(MRI.SCS,SCSFields2BDeleted{k})
            MRI.SCS = rmfield(MRI.SCS,SCSFields2BDeleted{k});
        end
    end
end

if isfield(MRI,'Landmarks') && ~isempty(MRI.Landmarks)
    tmpLandmarks = MRI.Landmarks;
    nLandmarks2Remove = 0;
    if isfield(MRI,'SCS')
        nLandmarks2Remove = 4; %Remove SCS fiducials from Landmark list
    end
    if isfield(MRI,'talCS')
        nLandmarks2Remove = nLandmarks2Remove + 3; % Remove TAL/MNI fiducials
    end
    if isfield(MRI.Landmarks, 'Names') && ~isempty(MRI.Landmarks.Names)
        MRI.Landmarks.Names    = MRI.Landmarks.Names(nLandmarks2Remove+1:end);
    end
    if isfield(MRI.Landmarks, 'MRImmXYZ') && ~isempty(MRI.Landmarks.MRImmXYZ)
        MRI.Landmarks.MRImmXYZ = MRI.Landmarks.MRImmXYZ(:,nLandmarks2Remove+1:end);
    end
    if isfield(MRI.Landmarks, 'Handles')
        MRI.Landmarks = rmfield(MRI.Landmarks,'Handles');
    end
end

if isfield(MRI,'SCS2Landmarks') % don't need to be stored in file
    tmpSCS2Landmarks = MRI.SCS2Landmarks;
    MRI = rmfield(MRI,'SCS2Landmarks');
end

% Remove FileName field
if isfield(MRI,'FileName')
    MRI = rmfield(MRI, 'FileName');
end


% SAVE .mat file
try
    bst_save(MriFile, MRI, Version);
catch

end
end


