function [Transform, isCancel] = channel_align_scs(ChannelFile, Transform, isWarning, isConfirm)
% CHANNEL_ALIGN_SCS: Saves new MRI anatomical points after manual or auto registration adjustment.
%
% USAGE:  Transform = channel_align_scs(ChannelFile, isWarning=1, isConfirm=1)
%
% DESCRIPTION: 
%       After modifying registration between digitized head points and MRI (with "refine with head
%       points" or manually), this function allows saving the change in the MRI fiducials so that
%       they exactly match the digitized anatomical points (nasion and ears). This would replace
%       having to save a registration adjustment transformation for each functional dataset sharing
%       this set of digitized points. This affects all files registered to the MRI and should
%       therefore be done as one of the first steps after importing, and with only one set of
%       digitized points (one session). Surfaces are adjusted to maintain alignment with the MRI.
%       Additional sessions for the same subject, with separate digitized points, will still need
%       the usual "per dataset" registration adjustment to align with the same MRI.
%
%       This function will not modify an MRI that it changed previously without user confirmation
%       (if both isWarning and isConfirm are false). In that case, the Transform is returned unaltered.
%
% INPUTS:
%     - ChannelFile : Channel file to align with its anatomy
%     - Transform   : Transformation matrix from digitized SCS coordinates to MRI SCS coordinates, 
%                     after some alignment is made (auto or manual) and the two no longer match.
%                     This transform should not already be saved in the ChannelFile, though the
%                     file may already contain similar adjustments, in which case Transform would be
%                     an additional adjustment to add.
%     - isWarning   : If 1, display warning in case of errors, or if this was already done 
%                     previously for this MRI. 
%     - isConfirm   : If 1, ask the user for confirmation before proceeding.
%
% OUTPUTS:
%     - Transform   : If the MRI fiducial points and coordinate system are updated, and the channel 
%                     file is reset, the transform becomes the identity. If the channel file is not
%                     reset, Transform will be the inverse of all previous manual or automatic
%                     adjustments. If the MRI was not updated, the input Transform is returned. The
%                     idea is that the returned Transform applied to the channels would maintain the
%                     registration.

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
% Authors: Marc Lalancette 2022-2023

% TODO if Transform is missing, get equivalent from ChannelMat, from all auto/manual adjustments.

isCancel = false;
% Get study
sStudy = bst_get('ChannelFile', ChannelFile);
% Get subject
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
% Get Channels
ChannelMat = in_bst_channel(ChannelFile);

% Check if digitized anat points present, saved in ChannelMat.SCS.
% Note that these coordinates are NOT currently updated when doing refine with head points (below).
% They are in "initial SCS" coordinates, updated in channel_detect_type.
if ~all(isfield(ChannelMat.SCS, {'NAS','LPA','RPA'})) || ~(length(ChannelMat.SCS.NAS) == 3) || ~(length(ChannelMat.SCS.LPA) == 3) || ~(length(ChannelMat.SCS.RPA) == 3)
    if isWarning
        bst_error('Digitized nasion and ear points not found.', 'Apply digitized anatomical fiducials to MRI', 0);
    else
        disp('BST> Digitized nasion and ear points not found.');
    end
    isCancel = true;
    return;
end

% Check if already adjusted
sMriOld = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
% This Check function also updates ChannelMat.SCS with the saved (possibly previously adjusted) head
% points. (We don't consider isMriMatch here because we still have to apply the provided
% Transformation.)
[~, isMriUpdated, ~, ChannelMat] = process_adjust_coordinates('CheckPrevAdjustments', ChannelMat, sMriOld);
% Get user confirmation
if isMriUpdated
    % Already done previously.
    if isWarning || isConfirm
        % Request confirmation.
        [Proceed, isCancel] = java_dialog('confirm', ['The MRI fiducial points NAS/LPA/RPA were previously updated from a set of' 10 ...
            'aligned digitized points. Updating them again will break any previous alignment' 10 ...
            'with other sets of digitized points and associated functional datasets.' 10 10 ...
            'Proceed and overwrite previous alignment?' 10], 'Head points/anatomy registration');
        if ~Proceed || isCancel
            isCancel = true;
            return;
        end
    else
        % Do not proceed.
        disp('BST> Digitized nasion and ear points previously applied to this MRI. Not applying again.');
        return;
    end
elseif isConfirm
    % Request confirmation.
    [Proceed, isCancel] = java_dialog('confirm', ['Updating the MRI fiducial points NAS/LPA/RPA to match a set of' 10 ...
        'aligned digitized points is mainly used for exporting registration to a BIDS dataset.' 10 ...
        'It will break any previous alignment of this subject with all other functional datasets!' 10 10 ...
        'Proceed and update MRI now?' 10], 'Head points/anatomy registration');
    if ~Proceed || isCancel
        isCancel = true;
        return;
    end
end

% Convert digitized fids to MRI SCS coordinates.
% Here, ChannelMat.SCS already may contain some auto/manual adjustment, and we're adding a new one.
% To do this we need to apply the transformation provided.
sMri = sMriOld;
sMri.SCS.NAS = (Transform(1:3,:) * [ChannelMat.SCS.NAS'; 1])';
sMri.SCS.LPA = (Transform(1:3,:) * [ChannelMat.SCS.LPA'; 1])';
sMri.SCS.RPA = (Transform(1:3,:) * [ChannelMat.SCS.RPA'; 1])';
% Then convert to MRI coordinates (mm), this is how sMri.SCS is saved.
% cs_convert mri is in meters
sMri.SCS.NAS = cs_convert(sMriOld, 'scs', 'mri', sMri.SCS.NAS) .* 1000;
sMri.SCS.LPA = cs_convert(sMriOld, 'scs', 'mri', sMri.SCS.LPA) .* 1000;
sMri.SCS.RPA = cs_convert(sMriOld, 'scs', 'mri', sMri.SCS.RPA) .* 1000;
% Re-compute transformation in this struct
[~, sMri] = cs_compute(sMri, 'scs');

% Compare with existing MRI fids, replace if changed (> 1um), and update surfaces.
sMri.FileName = sSubject.Anatomy(sSubject.iAnatomy).FileName;
figure_mri('SaveMri', sMri);

% MRI SCS now matches digitized SCS (defined from same points), but registration is now broken with
% all channel files! Reset channel file, and optionally all others for this anatomy.
isError = ResetChannelFiles(ChannelMat, sSubject);
if isError
    % Get the equivalent overall registration adjustment transformation previously saved.
    [~, ~, TransfAfter] = process_adjust_coordinates('GetTransforms', ChannelMat);
    % Return its inverse as it's now part of the MRI and should be removed from the channel file.
    Transform = inverse(TransfAfter);
else
    Transform = eye(4);
end

end % main function


% Modified version of channel_align_manual CopyToOtherFolders, with fewer checks (all channel files,
% not just "matching" ones) and resetting instead of applying a transform.
function isError = ResetChannelFiles(ChannelMatSrc, sSubject)
    % First, always reset the "source" channel file.
    NewChannelFiles = cell(0,2);
    [ChannelMatSrc, NewChannelFiles, isError] = ResetChannelFile(ChannelMatSrc, NewChannelFiles);
    if isError
        java_dialog('msgbox', sprintf(['Unable to reset channel file for subject: %s\n' ...
            'Registration for all their datasets should be verified!'], sSubject.Name));
        return;
    end

    % Confirmation: ask the first time 
    isConfirm = [];
    % If the subject is configured to share its channel files, nothing to do
    if (sSubject.UseDefaultChannel >= 1)
        return;
    end
    % Get all the dependent studies
    [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
    % List of channel files to update
    ChannelFiles = {};
    strMsg = '';
    % Loop on the other folders
    for i = 1:length(sStudies)
        % Skip original study
        if (iStudies(i) == iStudySrc)
            continue;
        end
        % Skip studies without channel files
        if isempty(sStudies(i).Channel) || isempty(sStudies(i).Channel(1).FileName)
            continue;
        end
        % Load channel file
        ChannelMatDest = in_bst_channel(sStudies(i).Channel(1).FileName);
        % Ask confirmation to the user
        if isempty(isConfirm)
            isConfirm = java_dialog('confirm', 'Reset all the channel files for this subject?', 'Align sensors');
            if ~isConfirm
                return;
            end
        end
        % Add channel file to list of files to process
        ChannelFiles{end+1} = sStudies(i).Channel(1).FileName;
        strMsg = [strMsg, sStudies(i).Channel(1).FileName, 10];
    end
    % Apply transformation
    if ~isempty(ChannelFiles)
        % Progress bar
        bst_progress('start', 'Align sensors', 'Updating other datasets...');
        % Update files
        channel_apply_transf(ChannelFiles, Transf);
        % Give report to the user
        bst_progress('stop');
        java_dialog('msgbox', sprintf('Updated %d additional file(s):\n%s', length(ChannelFiles), strMsg));
    end
end

