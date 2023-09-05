function OutputFiles = bst_project_dipoles(DipoleFiles, iSubjectDest, isInteractive)
% BST_PROJECT_DIPOLES: Project a dipole files between subjects, using the MNI normalization.
%
% USAGE:  OutputFile = bst_project_dipoles(ChannelFile, iSubjectDest=[ask], isInteractive=1)
% 
% INPUT:
%    - DipoleFiles   : String or cell-array of relative paths to dipole files to project
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
% Authors: Francois Tadel, 2022

% ===== PARSE INPUTS ======
if (nargin < 3) || isempty(isInteractive)
    isInteractive = [];
end
if (nargin < 2) || isempty(iSubjectDest)
    iSubjectDest = [];
end
if ischar(DipoleFiles)
    DipoleFiles = {DipoleFiles};
end
OutputFiles = {};

% ===== GET DESTINATION SUBJECT =====
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
% Get destination subject
sSubjectDest = bst_get('Subject', iSubjectDest);
% Progress bar
isProgress = bst_progress('isVisible');
bst_progress('start', 'Project dipoles file', 'Loading MRI files...');
% Load destination MRI
sMriDest = in_mri_bst(sSubjectDest.Anatomy(sSubjectDest.iAnatomy).FileName);
if cs_convert(sMriDest, 'scs', 'mni', [0, 0, 0])
    errMsg = ['Compute MNI normalization for subject "' sSubjectDest.Name '" first.'];
end

% Create destination subject
if (iSubjectDest == 0)
    SubjectName = 'Group_channels';
    [sSubjectDest, iSubjectDest] = bst_get('Subject', SubjectName);
    if isempty(sSubjectDest)
        [sSubjectDest, iSubjectDest] = db_add_subject(SubjectName, [], 1, 0);
    end
    isDestGroup = 1;
else
    isDestGroup = 0;
end

% Function to convert positions
function P = proj(P)
    P = cs_convert(sMriSrc, 'scs', 'mni', P');
    P = cs_convert(sMriDest, 'mni', 'scs', P)';
end


% ===== LOOP ON DIPOLES =====
% Loop on all input files
for iFile = 1:length(DipoleFiles)
    bst_progress('text', 'Loading MRI files...');
    % Get source subject
    [sStudySrc, iStudySrc] = bst_get('DipolesFile', DipoleFiles{iFile});
    [sSubjectSrc, iSubjectSrc] = bst_get('Subject', sStudySrc.BrainStormSubject);
    % Check subjects
    if (iSubjectSrc == iSubjectDest)
        errMsg = 'Source and destination subjects are identical';
    elseif (sSubjectDest.UseDefaultChannel && (iSubjectDest ~= 0)) || (sSubjectSrc.UseDefaultChannel && (iSubjectSrc ~= 0))
        errMsg = 'Source or destination subject is using the default anatomy.';
    elseif isempty(sSubjectDest.Anatomy) || isempty(sSubjectSrc.Anatomy)
        errMsg = 'Source or destination subject do not have any anatomical MRI.';
    end
    
    % Load source MRI
    sMriSrc = in_mri_bst(sSubjectSrc.Anatomy(sSubjectSrc.iAnatomy).FileName);
    if cs_convert(sMriSrc, 'scs', 'mni', [0, 0, 0])
        errMsg = ['Compute MNI normalization for subject "' sSubjectSrc.Name '" first.'];
    end
    % Error handling
    if isempty(errMsg)
        if isInteractive
            bst_error(errMsg, 'Project dipole file', 0);
        else
            bst_report('Error', 'bst_project_dipole', [], errMsg);
        end
        return;
    end
    
    % ===== PROJECT DIPOLE FILE =====
    bst_progress('text', 'Projecting using MNI normalization...');
    DipoleMat = load(file_fullpath(DipoleFiles{iFile}));
    % Project dipole
    for iDip = 1:length(DipoleMat.Dipole)
        % Represent the orientation as point 1cm away from the dipole location
        normAmp = sqrt(sum(DipoleMat.Dipole(iDip).Amplitude .^ 2));
        locAmp = DipoleMat.Dipole(iDip).Loc + DipoleMat.Dipole(iDip).Amplitude ./ normAmp .* 0.01;
        % Project location
        DipoleMat.Dipole(iDip).Loc = proj(DipoleMat.Dipole(iDip).Loc);
        % Project orientation
        DipoleMat.Dipole(iDip).Amplitude = (proj(locAmp) - DipoleMat.Dipole(iDip).Loc) ./ 0.01 .* normAmp;
    end
    % Reset parent file
    DipoleMat.DataFile = [];
    
    % ===== DESTINATION FOLDER =====
    bst_progress('text', 'Saving results...');
    % Create group study subject (if not existing yet)
    if isDestGroup
        folderDest = [sSubjectSrc.Name, '_', sStudySrc.Name];
    else
        folderDest = sStudySrc.Name;
    end
    % Get new folder to save new new file
    [sStudyDest, iStudyDest] = bst_get('StudyWithCondition', [sSubjectDest.Name '/' folderDest]);
    % Create folder if it doesn't exist
    if isempty(iStudyDest)
        iStudyDest = db_add_condition(sSubjectDest.Name, folderDest);
        if isempty(iStudyDest)
            error(['Cannot create destination folder: ', sSubjectDest.Name, '/', folderDest]);
        end
        sStudyDest = bst_get('Study', iStudyDest);
    end

    % ===== SAVE NEW FILE =====
    % Create output filename
    [fPath, fBase, fExt] = bst_fileparts(DipoleFiles{iFile});
    OutputFiles{iFile} = file_unique(bst_fullfile(bst_fileparts(file_fullpath(sStudyDest.FileName)), [fBase, fExt]));
    % Save new file in Brainstorm format
    bst_save(OutputFiles{iFile}, DipoleMat);

    % ===== UPDATE DATABASE =====
    % Create structure
    BstDipolesMat = db_template('Dipoles');
    BstDipolesMat.FileName = file_short(OutputFiles{iFile});
    BstDipolesMat.Comment  = DipoleMat.Comment;
    BstDipolesMat.DataFile = DipoleMat.DataFile;
    % Add to study
    iDipFile = length(sStudyDest.Dipoles) + 1;
    sStudyDest.Dipoles(iDipFile) = BstDipolesMat;
    
    % Save study
    bst_set('Study', iStudyDest, sStudyDest);
    % Update tree
    panel_protocols('UpdateNode', 'Study', iStudyDest);
    % Select first output study
    panel_protocols('SelectStudyNode', iStudyDest);
    % Select first output file
    panel_protocols('SelectNode', [], OutputFiles{iFile});
end

% Save database
db_save();
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

end
