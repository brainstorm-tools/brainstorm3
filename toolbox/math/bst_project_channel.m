function OutputFile = bst_project_channel(ChannelFile, iSubjectDest, isInteractive)
% BST_PROJECT_CHANNEL: Project a channel file between subjects, using the MNI normalization.
%
% USAGE:  OutputFile = bst_project_channel(ChannelFile, iSubjectDest=[ask], isInteractive=1)
%        OutputFiles = bst_project_channel(ChannelFiles, ...)
% 
% INPUT:
%    - ChannelFile   : Relative path to channel file to project
%    - iSubjectDest  : Index of the destination subject
%    - isInteractive : If 1, display interactive messages

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
% Authors: Francois Tadel, 2022-2023

% ===== PARSE INPUTS ======
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 2) || isempty(iSubjectDest)
    iSubjectDest = [];
end
% Calling recursively on multiple channel files
if iscell(ChannelFile)
    OutputFile = cell(size(ChannelFile));
    for i = 1:length(ChannelFile)
        OutputFile{i} = bst_project_channel(ChannelFile{i}, iSubjectDest, isInteractive);
    end
    return;
end
OutputFile = [];

% ===== GET INPUT DATA =====
% Ask for destination subject
if isempty(iSubjectDest)
    % Get all the subjects in the protocol
    sProtocolSubjects = bst_get('ProtocolSubjects');
    % Find subjects non using the default anatomy
    iSubjects = [];
    for i = 1:length(sProtocolSubjects.Subject)
        if ~sProtocolSubjects.Subject(i).UseDefaultAnat
            iSubjects(end+1) = i;
        end
    end
    if isempty(iSubjects)
        return;
    end
    % Ask which subject to use
    SubjectName = java_dialog('combo', '<HTML>Select the destination subject:<BR><BR>', 'Project channel file', [], {sProtocolSubjects.Subject(iSubjects).Name});
    if isempty(SubjectName)
        return
    end
    iSubjectDest = find(strcmpi(SubjectName, {sProtocolSubjects.Subject.Name}));
end
% Progress bar
isProgress = bst_progress('isVisible');
bst_progress('start', 'Project channel file', 'Loading MRI files...');
% Get destination subject
sSubjectDest = bst_get('Subject', iSubjectDest);
% Get source subject
[sStudySrc, iStudySrc] = bst_get('ChannelFile', ChannelFile);
[sSubjectSrc, iSubjectSrc] = bst_get('Subject', sStudySrc.BrainStormSubject);
% Check subjects
errMsg = [];
if (iSubjectSrc == iSubjectDest)
    errMsg = 'Source and destination subjects are identical';
elseif (sSubjectDest.UseDefaultChannel && (iSubjectDest ~= 0)) || (sSubjectSrc.UseDefaultChannel && (iSubjectSrc ~= 0))
    errMsg = 'Source or destination subject is using the default anatomy.';
elseif isempty(sSubjectDest.Anatomy) || isempty(sSubjectSrc.Anatomy)
    errMsg = 'Source or destination subject do not have any anatomical MRI.';
end
% Error handling
if ~isempty(errMsg)
    if isInteractive
        bst_error(errMsg, 'Project channel file', 0);
    else
        bst_report('Error', 'bst_project_channel', [], errMsg);
    end
    return;
end

% Load source MRI
sMriSrc = in_mri_bst(sSubjectSrc.Anatomy(sSubjectSrc.iAnatomy).FileName);
if isempty(cs_convert(sMriSrc, 'scs', 'mni', [0, 0, 0]))
    errMsg = ['Compute MNI normalization for subject "' sSubjectSrc.Name '" first.'];
end
% Load destination MRI
sMriDest = in_mri_bst(sSubjectDest.Anatomy(sSubjectDest.iAnatomy).FileName);
if isempty(cs_convert(sMriDest, 'scs', 'mni', [0, 0, 0]))
    errMsg = ['Compute MNI normalization for subject "' sSubjectDest.Name '" first.'];
end
% Error handling
if ~isempty(errMsg)
    if isInteractive
        bst_error(errMsg, 'Project channel file', 0);
    else
        bst_report('Error', 'bst_project_channel', [], errMsg);
    end
    return;
end


% ===== PROJECT CHANNEL FILE =====
bst_progress('text', 'Projecting using MNI normalization...');
ChannelMatSrc = in_bst_channel(ChannelFile);
ChannelMatDest = db_template('channelmat');
ChannelMatDest.Comment = ChannelMatSrc.Comment;
% Function to convert positions
function P = proj(P)
    P = cs_convert(sMriSrc, 'scs', 'mni', P');
    P = cs_convert(sMriDest, 'mni', 'scs', P)';
end
% Project sensors
ChannelMatDest.Channel  = ChannelMatSrc.Channel;
for i = 1:length(ChannelMatSrc.Channel)
    if ~isempty(ChannelMatSrc.Channel(i).Loc)
        if size(ChannelMatSrc.Channel(i).Loc,2) == 2
            ChannelMatDest.Channel(i).Loc(:,1) = proj(ChannelMatSrc.Channel(i).Loc(:,1));
            ChannelMatDest.Channel(i).Loc(:,2) = proj(ChannelMatSrc.Channel(i).Loc(:,2));
        else
            ChannelMatDest.Channel(i).Loc = proj(ChannelMatSrc.Channel(i).Loc);
        end
    end
end
% Project head points
ChannelMatDest.HeadPoints = ChannelMatSrc.HeadPoints;
if ~isempty(ChannelMatSrc.HeadPoints.Loc)
    ChannelMatDest.HeadPoints.Loc = proj(ChannelMatSrc.HeadPoints.Loc);
end
% Project SEEG/ECOG
ChannelMatDest.IntraElectrodes = ChannelMatSrc.IntraElectrodes;
for i = 1:length(ChannelMatSrc.IntraElectrodes)
    if ~isempty(ChannelMatSrc.IntraElectrodes(i).Loc)
        ChannelMatDest.IntraElectrodes(i).Loc = proj(ChannelMatSrc.IntraElectrodes(i).Loc);
    end
end
% Copy clusters
ChannelMatDest.Clusters = ChannelMatSrc.Clusters;

% ===== SAVE NEW FILE =====
bst_progress('text', 'Saving results...');
% Create group study subject (if not existing yet)
if (iSubjectDest == 0)
    SubjectName = 'Group_channels';
    [sSubjectDest, iSubjectDest] = bst_get('Subject', SubjectName);
    if isempty(sSubjectDest)
        [sSubjectDest, iSubjectDest] = db_add_subject(SubjectName, [], 1, 0);
    end
    % SEEG/ECOG: typically one implementation per patient only
    if any(ismember({'SEEG', 'ECOG'}, {ChannelMatSrc.Channel.Type}))
        folderDest = strrep(sSubjectSrc.Name, 'sub-', '');
    else
        folderDest = [strrep(sSubjectSrc.Name, 'sub-', ''), '_', strrep(sStudySrc.Name, '@raw', '')];
    end
else
    folderDest = sStudySrc.Name;
end
% Create new folder to save projected file
iStudyDest = db_add_condition(iSubjectDest, folderDest);
if isempty(iStudyDest)
    errMsg = ['Cannot create destination folder: ', sSubjectDest.Name, '/', folderDest];
% Save new channel file
else
    OutputFile = db_set_channel(iStudyDest, ChannelMatDest, 1, 0);
    if isempty(OutputFile)
        errMsg = ['Cannot save channel file in destination folder: ', sSubjectDest.Name, '/', folderDest];
    end
end
% Error handling
if ~isempty(errMsg)
    if isInteractive
        bst_error(errMsg, 'Project channel file', 0);
    else
        bst_report('Error', 'bst_project_channel', [], errMsg);
    end
    bst_progress('stop');
    return;
end


% ===== UDPATE DISPLAY =====
% Select first output study
panel_protocols('SelectStudyNode', iStudyDest);
% Select first output file
panel_protocols('SelectNode', [], OutputFile);
% Save database
db_save();
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

end
