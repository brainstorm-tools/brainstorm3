function db_group_conditions( ConditionsPaths, newConditionName )
% DB_GROUP_CONDITIONS: Combine many conditions in one (averaging the electrodes positions if necessary).
%
% USAGE:  db_group_conditions( ConditionsPaths, newConditionName )
%         db_group_conditions( ConditionsPaths )

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
% Authors: Francois Tadel, 2009-2013

% ===== GET NEW CONDITION NAME =====
% Get protocol directories
ProtocolInfo = bst_get('ProtocolInfo');
% Get condition name
oldConditionName = '';
% Get new condition name
if (nargin < 2) || isempty(newConditionName)
    % Ask user new Comment field
    newConditionName = java_dialog('input', 'New condition name', 'Group condition', [], oldConditionName);
    % If user did not answer or did not change the Comment field: ignore modification
    if isempty(newConditionName) || strcmpi(newConditionName, oldConditionName)
        return;
    end
end

% ===== GET STUDIES TO MODIFY =====
% Process all Conditions
sStudies = [];
iStudies = [];
for i = 1:length(ConditionsPaths)
    % Get all the studies concerned by the modification
    [sStudiesTmp, iStudiesTmp] = bst_get('StudyWithCondition', ConditionsPaths{i});
    sStudies = [sStudies, sStudiesTmp];
    iStudies = [iStudies, iStudiesTmp];
    % Check complexity of the study: do not accept any links
    if any(~cellfun(@isempty, {sStudiesTmp.Result.DataFile})) || any(~cellfun(@isempty, {sStudiesTmp.Timefreq.DataFile})) 
        bst_error('Cannot group conditions that contain links or nested files.', 'Group conditions', 0);
        return;
    end
end
% If no studies selected: nothing to do
if isempty(sStudies)
    return
end
% Get all the subjects involved
uniqueSubjectFiles = unique({sStudies.BrainStormSubject});

% ===== PROCESS EACH SUBJECT =====
sAllDestStudies     = [];
iStudiesNotToDelete = [];
iStudiesToDelete    = [];
bst_progress('start', 'Moving files...', 'Group conditions', 0, length(iStudies));
for iSubj = 1:length(uniqueSubjectFiles)
    % === CHECK SOURCE CONDITIONS ===
    % Get studies concerned for this subject/condition
    iCondStudies = find(file_compare({sStudies.BrainStormSubject}, uniqueSubjectFiles{iSubj}));
    if (length(iCondStudies) <= 1)
        warning('Only one condition for this subject... cannot group.');
        continue
    end   
    
    % === CREATE NEW CONDITION ===
    % Get subject
    sSubject = bst_get('Subject', uniqueSubjectFiles{iSubj}, 1);
    % Create condition
    iDestStudy = db_add_condition(sSubject.Name, newConditionName, 0);
    % If condition could not be created
    if isempty(iDestStudy)
        bst_progress('stop');
        return
    end
    % Get newly created condition
    sDestStudy = bst_get('Study', iDestStudy);
    sAllDestStudies     = [sAllDestStudies, sDestStudy]; 
    iStudiesNotToDelete = [iStudiesNotToDelete, iDestStudy];
    iStudiesToDelete    = [iStudiesToDelete, iStudies(iCondStudies)];
    
    % === STANDARDIZE CHANNEL FILES ===
    % Only if the channel is not already shared
    if (sSubject.UseDefaultChannel == 0)
        disp('BST> Group conditions: Applying process_megreg to the data before proceeding, this will most likely alter the recordings.');
        % Get all the data files
        allDataFiles = {};
        for iStud = 1:length(iCondStudies)
            allDataFiles = cat(2, allDataFiles, {sStudies(iCondStudies(iStud)).Data.FileName});
        end
        % Register MEG runs together
        bst_process('CallProcess', 'process_megreg', allDataFiles, [], 'targetchan', 1, 'sharechan', 2, 'progressbar', 0);
    end

    % === PROCESS ALL STUDIES ===
    isChanCopied = 0;
    oldCondPath = {};
    for iStud = 1:length(iCondStudies)
        % Increment progressbar 
        bst_progress('inc', 1);
        % Get current study
        sStudy = sStudies(iCondStudies(iStud));
        oldCondPath{iStud} = [sSubject.Name '/' sStudy.Condition{1}];
        % Check if there is already channel file in the destination study
        if ~isempty(sDestStudy.Channel) && ~isempty(sDestStudy.Channel.FileName)
            isChanCopied = 1;
        end
        % Rename condition without moving the files on the hard drive (update all files)
        db_rename_condition( oldCondPath{iStud}, [sSubject.Name '/' newConditionName], 0, 0 );
        % Get files in this study directory
        dirStudy = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sStudy.FileName));
        studyFiles = dir(dirStudy);
        iNonTrial = 1;
        % Copy all files in the target study
        for iFile = 1:length(studyFiles)
            % Ignore if directory
            if studyFiles(iFile).isdir
                continue;
            end
            % Get file type
            fileType = file_gettype(studyFiles(iFile).name);
            % Channel file: Copy only the first files
            if strcmpi(fileType, 'channel')
                if ~isChanCopied
                    isChanCopied = 1;
                else
                    continue;
                end
            end
            % Study files / links: ignore
            if any(strcmpi(fileType, {'brainstormstudy', 'link'}))
                continue;
            end
            % Create a new filename for file, in target file
            switch (fileType)
                case 'data'
                    destFilename = sprintf('data_%s_%03d.mat', sStudy.Condition{1}, iNonTrial);
                    iNonTrial = iNonTrial + 1;
                otherwise
                    destFilename = strrep(studyFiles(iFile).name, '_trial', '_');
            end
            % Make filename unique
            destFilename = file_unique(bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sDestStudy.FileName), destFilename));
            % Build full source filename
            srcFilename = bst_fullfile(dirStudy, studyFiles(iFile).name);
            % Move file physically
            file_move(srcFilename, destFilename);
        end
    end
end

% === DELETE GROUPED CONDITIONS ===
iStudiesToDelete = setdiff(iStudiesToDelete, iStudiesNotToDelete);
% Delete all studies
db_delete_studies(iStudiesToDelete);
% Hide progress bar
bst_progress('stop');

% === UPDATE DATABASE ===
% Update whole tree
panel_protocols('UpdateTree');
% Get list of target studies (indices changed because of suppressions)
iAllDestStudies = [];
for i = 1:length(sAllDestStudies)
    [tmp__, iStudy] = bst_get('Study', sAllDestStudies(i).FileName);
    iAllDestStudies = [iAllDestStudies, iStudy];
end
if isempty(iAllDestStudies)
    return
end
% Reload modified studies
db_reload_studies(iAllDestStudies);
% Repaint node
panel_protocols('UpdateNode', 'Study', iAllDestStudies);
% Save database
db_save();


