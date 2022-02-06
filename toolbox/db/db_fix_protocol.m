function [isError, isFixed] = db_fix_protocol()
% DB_FIX_PROTOCOL: Fixes all the errors that can be found in current protocol
%
% USAGE:  [isError, isFixed] = db_fix_protocol()

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
% Authors: Francois Tadel, 2011-2014


%% ===== PROTOCOL FOLDERS =====
% Progress bar
isProgressBar = ~bst_progress('isVisible');
if isProgressBar
    bst_progress('start', 'db_fix_database', 'Fixing database errors...');
else
    bst_progress('text', 'Fixing database errors...');
end
% Get protocol info
isError = 0;
isFixed = 1;
ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
ProtocolStudies  = bst_get('ProtocolStudies');
% Subjects folder
if ~file_exist(ProtocolInfo.SUBJECTS)
%     disp('DB_FIX> Missing folder SUBJECTS. Fixing...');
%     if ~mkdir(ProtocolInfo.SUBJECTS)
%         error(['Anatomy directory does not exist and can''t be created: "', ProtocolInfo.SUBJECTS '".']);
%     end
    error(['Anatomy directory does not exist and can''t be created: "', ProtocolInfo.SUBJECTS '".']);
    isError = 1;
end
% Studies folder
if ~file_exist(ProtocolInfo.STUDIES)
%     disp('DB_FIX> Missing folder STUDIES. Fixing...');
%     if ~mkdir(ProtocolInfo.STUDIES)
%         error(['Data directory does not exist and cannot be created: "', ProtocolInfo.STUDIES '".']);
%     end
    error(['Data directory does not exist and cannot be created: "', ProtocolInfo.STUDIES '".']);
    isError = 1;
end


%% ===== LIST MISSING SUBJECTS =====
missingSubj = {};
allSubj = {};
% Default subject
defSubjDir = bst_fullfile(ProtocolInfo.SUBJECTS, bst_get('DirDefaultSubject'));
if ~file_exist(defSubjDir) || ~file_exist(bst_fullfile(defSubjDir, 'brainstormsubject.mat'))
    missingSubj{end+1} = bst_get('DirDefaultSubject');
end
% List of subjects
for iSubj = 1:length(ProtocolSubjects.Subject)
    allSubj{end+1} = bst_fileparts(ProtocolSubjects.Subject(iSubj).FileName);
    if ~file_exist(bst_fullfile(ProtocolInfo.SUBJECTS, ProtocolSubjects.Subject(iSubj).FileName))
        missingSubj{end+1} = allSubj{end};
    end
end
% List of subjects referenced in the studies
listSubjFile = unique({ProtocolStudies.Study.BrainStormSubject});
for iSubj = 1:length(listSubjFile)
    SubjName = bst_fileparts(listSubjFile{iSubj});
    % Skip default subject
    if strcmpi(SubjName, bst_get('DirDefaultSubject'))
        continue;
    end
    allSubj{end+1} = SubjName;
    if ~file_exist(bst_fullfile(ProtocolInfo.SUBJECTS, listSubjFile{iSubj}))
        missingSubj{end+1} = SubjName;
    end
end
% List all the folders referenced in the studies
listStudyFile = unique({ProtocolStudies.Study.FileName});
for iStudy = 1:length(listStudyFile)
    SubjName = bst_fileparts(bst_fileparts(listStudyFile{iStudy}), 1);
    % Skip default subject
    if strcmpi(SubjName, bst_get('DirDefaultSubject'))
        continue;
    end
    allSubj{end+1} = SubjName;
    if ~file_exist(bst_fullfile(ProtocolInfo.SUBJECTS, allSubj{end}))
        missingSubj{end+1} = SubjName;
    end
end
% List all the folders in the STUDIES folder
listFolders = dir(ProtocolInfo.STUDIES);
for iDir = 1:length(listFolders)
    % Skip non-folders, '.' folders, and default folders
    if ~listFolders(iDir).isdir || (listFolders(iDir).name(1) == '.') || ismember(listFolders(iDir).name, {bst_get('DirDefaultSubject'), bst_get('DirDefaultStudy'), bst_get('DirAnalysisInter')})
        continue;
    end
    allSubj{end+1} = listFolders(iDir).name;
    % Subject folders: add if they do not exist in the subjects list
    if ~file_exist(bst_fullfile(ProtocolInfo.SUBJECTS, listFolders(iDir).name))
        missingSubj{end+1} = allSubj{end};
    end
end
% Clean subject names
strrep(allSubj, '/', '');
strrep(allSubj, '\', '');
allSubj = unique(allSubj);
% Errors detected
if ~isempty(missingSubj)
    strrep(missingSubj, '/', '');
    strrep(missingSubj, '\', '');
    missingSubj = unique(missingSubj);
    isError = 1;
end

%% ===== PROCESS MISSING SUBJECTS =====
for iSubj = 1:length(missingSubj)
    disp(['DB_FIX> Missing subject: "' missingSubj{iSubj} '"...']);
    
    % Default subject: Create a new one
    if strcmpi(missingSubj{iSubj}, bst_get('DirDefaultSubject'))
        % Ask for confirmation
        res = java_dialog('question', ['Subject "' missingSubj{iSubj} '" is missing in the database.' 10 'Create the missing files and folders in the anatomy folder?'], ...
                          'Database error', [], {'Yes', 'No', 'Cancel'}, 'Cancel');
        switch (res)
            case 'Yes',    % Nothing to do
            case 'No',     isFixed = 0;  continue;
            case 'Cancel', return;
        end
        % Folder
        subjDir = bst_fullfile(ProtocolInfo.SUBJECTS, missingSubj{iSubj});
        if ~file_exist(subjDir)
            try
                isCreated = mkdir(subjDir);
            catch
                isCreated = 0;
            end
            if ~isCreated
                disp(['DB_FIX> Error: cannot create folder "' missingSubj{iSubj} '".']);
                isFixed = 0;
                continue
            end
        end
        % File brainstormsubject.mat
        subjFile = bst_fullfile(subjDir, 'brainstormsubject.mat');
        if ~file_exist(subjFile)
            % Create an empty default subject
            SubjectMat = db_template('subjectmat');
            % Default subject
            if strcmpi(missingSubj{iSubj}, bst_get('DirDefaultSubject')) || isempty(ProtocolInfo.UseDefaultAnat)
                SubjectMat.UseDefaultAnat    = 1;
                SubjectMat.UseDefaultChannel = 1;
            % Regular subject
            else
                SubjectMat.UseDefaultAnat    = ProtocolInfo.UseDefaultAnat;
                SubjectMat.UseDefaultChannel = ProtocolInfo.UseDefaultChannel;
            end
            % Save subject file
            try
                bst_save(subjFile, SubjectMat, 'v7');
            catch
                disp(['DB_FIX> Error: Could not create subject file "' subjFile '". Ignoring subject...']);
                isFixed = 0;
            end
        end
    % Else: Delete all references from database
    else
        % Get subject index
        [sSubjectRm, iSubjectRm] = bst_get('Subject', missingSubj{iSubj});
        % Delete from subjects list
        if ~isempty(iSubjectRm)
            SubjectFile = ProtocolSubjects.Subject(iSubjectRm).FileName;
            ProtocolSubjects.Subject(iSubjectRm) = [];
            bst_set('ProtocolSubjects', ProtocolSubjects);
        % Subject is not found, try to rebuild the subject file from the subject name
        else
            SubjectFile = bst_fullfile(missingSubj{iSubj}, 'brainstormsubject.mat');
        end
        % Delete all the related studies
        iStudiesRm = find(file_compare(SubjectFile, {ProtocolStudies.Study.BrainStormSubject}));
        if ~isempty(iStudiesRm)
            ProtocolStudies.Study(iStudiesRm) = [];
            bst_set('ProtocolStudies', ProtocolStudies);
        end 
        % Remove from the list of subjects to process for the missing studies
        allSubj = setdiff(allSubj, missingSubj{iSubj});
    end
end


%% ===== LIST MISSING STUDIES =====
missingStudy = {};
% Default study
defStudyFile = bst_fullfile(bst_get('DirDefaultStudy'), 'brainstormstudy.mat');
if ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, defStudyFile))
    missingStudy{end+1} = defStudyFile;
end
% Inter-subject
interStudyFile = bst_fullfile(bst_get('DirAnalysisInter'), 'brainstormstudy.mat');
if ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, interStudyFile))
    missingStudy{end+1} = interStudyFile;
end
% All subjects
for iSubj = 1:length(allSubj)
    % Default study
    defStudyFile = bst_fullfile(allSubj{iSubj}, bst_get('DirDefaultStudy'), 'brainstormstudy.mat');
    if ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, defStudyFile))
        missingStudy{end+1} = defStudyFile;
    end
    % Intra-subject
    intraStudyFile = bst_fullfile(allSubj{iSubj}, bst_get('DirAnalysisIntra'), 'brainstormstudy.mat');
    if ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, intraStudyFile))
        missingStudy{end+1} = intraStudyFile;
    end
end
% Errors detected
if ~isempty(missingStudy)
    isError = 1;
end

%% ===== ADD MISSING STUDIES =====
for iStudy = 1:length(missingStudy)
    disp(['DB_FIX> Missing folder "' bst_fileparts(missingStudy{iStudy}) '". Fixing...']);
    % Ask for confirmation
    res = java_dialog('question', ['Folder "' bst_fileparts(missingStudy{iStudy}) '" is missing in the database.' 10 'Create the missing files and folders in the data folder?'], ...
                      'Database error', [], {'Yes', 'No', 'Cancel'}, 'Cancel');
    switch (res)
        case 'Yes',    % Nothing to do
        case 'No',     isFixed = 0; continue;
        case 'Cancel', return;
    end
    % Folder
    studyDir = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(missingStudy{iStudy}));
    if ~file_exist(studyDir)
        try
            isCreated = mkdir(studyDir);
        catch
            isCreated = 0;
        end
        if ~isCreated
            disp(['DB_FIX> Error: cannot create folder "' studyDir '".']);
            isFixed = 0;
            continue
        end
    end
    % File brainstormsubject.mat
    studyFile = bst_fullfile(studyDir, 'brainstormstudy.mat');
    if ~file_exist(studyFile)
        % Get condition name
        [SubjectName, ConditionName] = bst_fileparts(bst_fileparts(missingStudy{iStudy}, 1), 1);
        % Create structure
        StudyMat = db_template('studymat');
        StudyMat.Name = ConditionName;
        % Save brainstormstudy.mat file
        try
            bst_save(studyFile, StudyMat, 'v7');
        catch
            disp(['DB_FIX> Error: Could not create study file "' studyFile '". Ignoring subject...']);
            isFixed = 0;
        end
    end
end


%% ===== RELOAD PROTOCOL COMPLETELY =====
if isProgressBar
    bst_progress('stop');
end
if isError
    % Removing subjects from the protocol definition
    if isFixed
        disp(['DB_FIX> There were errors in protocol "' ProtocolInfo.Comment '". You should reload the database...']);
        %db_reload_database(bst_get('iProtocol'), 0);
    else
        disp(['DB_FIX> Error: There were errors in protocol "' ProtocolInfo.Comment '" that could not be fixed.']);
        %disp('DB_FIX> Detaching protocol from database...');
    end
end


