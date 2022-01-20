function varargout = process_duplicate( varargin )
% PROCESS_DUPLICATE: Duplicate files, subjecta, or conditions.
%
% USAGE:     sProcess = process_duplicate('GetDescription')
%         OutputFiles = process_duplicate('Run', sProcess, sInputs)
%            destName = process_duplicate('DuplicateSubject',   srcName, Tag)
% [sSubject,iSubject] = process_duplicate('CopySubjectAnat',    srcName, destName)
%            destPath = process_duplicate('DuplicateCondition', srcPath, Tag)
%            destName = process_duplicate('DuplicateData',      srcFile, Tag, isReload)

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
% Authors: Francois Tadel, 2012-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Duplicate files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1022;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === TARGET
    sProcess.options.target.Comment = {'Duplicate data files', 'Duplicate folders', 'Duplicate subjects'};
    sProcess.options.target.Type    = 'radio';
    sProcess.options.target.Value   = 1;
    % === TAG
    sProcess.options.tag.Comment = ' Tag to add to the copied files: ';
    sProcess.options.tag.Type    = 'text';
    sProcess.options.tag.Value   = '_copy';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = [sProcess.options.target.Comment{sProcess.options.target.Value}, ': Add tag "', sProcess.options.tag.Value, '"'];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned list
    OutputFiles = {};
    % Get options
    fileTag    = sProcess.options.tag.Value;
    CopyTarget = sProcess.options.target.Value;
    % Check file tag
    if isempty(fileTag)
        bst_report('Error', sProcess, [], 'File tag is not specified.');
        return;
    end
    fileTag = file_standardize(fileTag);
    % Cannot duplicate RAW data or condition
    if strcmpi(sInputs(1).FileType, 'raw') && ismember(CopyTarget, [1,2])
        bst_report('Error', sProcess, [], 'Cannot duplicate link to raw recordings.');
        return;
    end


    % Group files in different ways: by subject, by condition, or all together
    switch (CopyTarget)
        % === DATA FILES ===
        case 1
            % Duplicate each data file
            for iFile = 1:length(sInputs)
                [tmp, Messages] = DuplicateData(sInputs(iFile).FileName, fileTag, 0);
                if ~isempty(tmp)
                    OutputFiles{end+1} = tmp;
                else
                    bst_report('Error', sProcess, sInputs(iFile), Messages);
                    continue;
                end
            end
            
        % === CONDITIONS ===
        case 2
            % Build full condition path for each input file
            allCondPath = {};
            for i = 1:length(sInputs)
                % Cannot duplicate the default subject
                if strcmpi(sInputs(i).SubjectName, bst_get('DirDefaultSubject')) || ismember(sInputs(i).Condition, {bst_get('DirAnalysisIntra'), bst_get('DirAnalysisInter'), bst_get('DirDefaultStudy')})
                    bst_report('Error', sProcess, sInputs(i), 'Cannot duplicate default subject or default conditions.');
                    continue;
                end
                allCondPath{end+1} = [sInputs(i).SubjectName, '/', sInputs(i).Condition];
            end
            % Process each subject/condition separately
            uniqueCondPath = unique(allCondPath);
            for i = 1:length(uniqueCondPath)
                oldCondPath = uniqueCondPath{i};
                % Get all the files for condition #i
                iInputCond = find(strcmpi(oldCondPath, allCondPath));
                % Process the average of condition #i
                [newCondPath, Messages] = DuplicateCondition(oldCondPath, fileTag, 0);
                % Update the filenames
                if ~isempty(newCondPath)
                    OutputFiles = cat(2, OutputFiles, strrep({sInputs(iInputCond).FileName}, oldCondPath, newCondPath));
                else
                    bst_report('Error', sProcess, sInputs, Messages);
                    continue;
                end
            end
            
        % === SUBJECTS ===
        case 3
            % Process each subject independently
            uniqueSubj = unique({sInputs.SubjectName});
            for iSubj = 1:length(uniqueSubj)
                oldName = uniqueSubj{iSubj};
                % Cannot duplicate the default subject
                if strcmpi(oldName, bst_get('DirDefaultSubject'))
                    bst_report('Error', sProcess, sInputs, 'Cannot duplicate default subject.');
                    continue;
                end
                % Get all the files for condition #i
                iInputSubj = find(strcmpi(oldName, {sInputs.SubjectName}));
                % Process the average of condition #i
                [newName, Messages] = DuplicateSubject(oldName, fileTag, 0);
                % Update the filenames
                if ~isempty(newName)
                    for iFile = 1:length(iInputSubj)
                        fNameSplit = str_split(sInputs(iInputSubj(iFile)).FileName);
                        OutputFiles = cat(2, OutputFiles, bst_fullfile(newName, fNameSplit{2:end}));
                    end
                else
                    bst_report('Error', sProcess, sInputs, Messages);
                    continue;
                end
            end     
    end
    % Update tree
    panel_protocols('UpdateTree');
end


%% ===== DUPLICATE SUBJECT =====
function [destName, Messages] = DuplicateSubject(srcName, Tag, isRefresh)
    % Parse inputs
    if (nargin < 3) || isempty(isRefresh)
        isRefresh = 1;
    end
    Messages = [];
    % Progress bar
    isProgressBar = ~bst_progress('isVisible');
    if isProgressBar
        bst_progress('start', 'Duplicate subject', 'Copying files...');
    end
    % Copy name
    destName = [srcName, Tag];
    % Get protocol folders
    ProtocolInfo = bst_get('ProtocolInfo');
    srcAnatDir  = bst_fullfile(ProtocolInfo.SUBJECTS, srcName);
    destAnatDir = bst_fullfile(ProtocolInfo.SUBJECTS, destName);
    % Get a subject name that does not exist yet
    destAnatDir = file_unique(destAnatDir);
    [tmp, destName] = bst_fileparts(destAnatDir, 1);
    % Data folders
    srcDataDir  = bst_fullfile(ProtocolInfo.STUDIES, srcName);
    % Get temporary folders for anat and data
    tmpAnatDir = bst_fullfile(bst_fileparts(ProtocolInfo.STUDIES, 1), 'copy_anat_tmp');
    tmpDataDir = bst_fullfile(bst_fileparts(ProtocolInfo.STUDIES, 1), 'copy_data_tmp');
    % If folders aldready exist: delete them
    if file_exist(tmpAnatDir);
        file_delete(tmpAnatDir, 1, 1);
    end
    if file_exist(tmpDataDir);
        file_delete(tmpDataDir, 1, 1);
    end
    % Copy src folders to tmp folders
    isOk1 = file_copy(srcAnatDir, tmpAnatDir);
    isOk2 = file_copy(srcDataDir, tmpDataDir);
    if ~isOk1 || ~isOk2
        Messages = ['Could not copy files: ' 10 srcAnatDir 10 srcDataDir];
        disp(['DUPLICATE> Error: ' Messages]);
        destName = [];
        if isProgressBar
            bst_progress('stop');
        end
        return;
    end
    % Get source subject structures
    sSrcSubj = bst_get('Subject', srcName, 1);
    sSrcStudies = bst_get('StudyWithSubject', sSrcSubj.FileName, 'intra_subject', 'default_study');
    % Rename src subject to dest subject
    db_rename_subject(srcName, destName, 0);
    % Copy contents tmp folders into new subjects
    file_move(tmpAnatDir, srcAnatDir);
    file_move(tmpDataDir, srcDataDir);
    % Add new subject
    ProtocolSubjects = bst_get('ProtocolSubjects');
    ProtocolSubjects.Subject(end+1) = sSrcSubj;
    bst_set('ProtocolSubjects', ProtocolSubjects);
    % Add studies
    ProtocolStudies = bst_get('ProtocolStudies');
    for i = 1:length(sSrcStudies)
        ProtocolStudies.Study(end+1) = sSrcStudies(i);
    end
    bst_set('ProtocolStudies', ProtocolStudies);
    % Refresh tree display
    if isRefresh
        panel_protocols('UpdateTree');
    end
    if isProgressBar
        bst_progress('stop');
    end
end
    
%% ===== COPY SUBJECT ANAT =====
function [sSubjectDest, iSubjectDest, Messages] = CopySubjectAnat(srcName, destName) %#ok<DEFNU>
    sSubjectDest = [];
    iSubjectDest = [];
    Messages = [];
    % Progress bar
    isProgressBar = ~bst_progress('isVisible');
    if isProgressBar
        bst_progress('start', 'Duplicate subject', 'Copying files...');
    end
    % Get source subject
    sSubjectSrc = bst_get('Subject', srcName);
    if isempty(sSubjectSrc)
        Messages = ['Invalid source subject name "' srcName '".'];
        if isProgressBar
            bst_progress('stop');
        end
        return;
    end
    % Get destination subject
    sSubjectDest = bst_get('Subject', destName);
    if ~isempty(sSubjectDest)
        Messages = ['Destination subject name "' destName '" already exists.'];
        if isProgressBar
            bst_progress('stop');
        end
        return;
    end
    % Create destination subject
    [sSubjectDest, iSubjectDest] = db_add_subject(destName, [], sSubjectSrc.UseDefaultAnat, sSubjectSrc.UseDefaultChannel);
    % Copy all the anat files
    if ~sSubjectSrc.UseDefaultAnat
        % Get protocol folders
        ProtocolInfo = bst_get('ProtocolInfo');
        srcAnatDir  = bst_fullfile(ProtocolInfo.SUBJECTS, srcName);
        destAnatDir = bst_fullfile(ProtocolInfo.SUBJECTS, destName);
        % List files from source folder
        dirFiles = dir(srcAnatDir);
        % Copy files
        for i = 1:length(dirFiles)
            if (dirFiles(i).name(1) == '.') || ~isempty(strfind(dirFiles(i).name(1), 'brainstormsubject'))
                continue;
            end
            file_copy(fullfile(srcAnatDir, dirFiles(i).name), fullfile(destAnatDir, dirFiles(i).name));
        end
        % Reload subejct anatomy
        db_reload_subjects(iSubjectDest);
        % Get again the subject structure
        sSubjectDest = bst_get('Subject', destName);
    end
    % Refresh tree display
    if isProgressBar
        bst_progress('stop');
    end
end


%% ===== DUPLICATE CONDITION =====
function [destPath, Messages] = DuplicateCondition(srcPath, Tag, isRefresh)
    % Parse inputs
    if (nargin < 3) || isempty(isRefresh)
        isRefresh = 1;
    end
    Messages = [];
    % Progress bar
    isProgressBar = ~bst_progress('isVisible');
    if isProgressBar
        bst_progress('start', 'Duplicate subject', 'Copying files...');
    end
    % Copy name
    destPath = [srcPath, Tag];
    % Get protocol folders
    ProtocolInfo = bst_get('ProtocolInfo');
    srcDir  = bst_fullfile(ProtocolInfo.STUDIES, srcPath);
    destDir = bst_fullfile(ProtocolInfo.STUDIES, destPath);
    % Get a subject name that does not exist yet
    destDir = file_unique(destDir);
    [tmp, destCond] = bst_fileparts(destDir, 1);
    [tmp, destSubj] = bst_fileparts(tmp, 1);
    destPath = [destSubj, '/', destCond];

    % Get temporary folders for condition
    tmpDir = bst_fullfile(bst_fileparts(ProtocolInfo.STUDIES, 1), 'copy_cond_tmp');
    % If folder aldready exists: delete it
    if file_exist(tmpDir);
        file_delete(tmpDir, 1, 1);
    end
    % Copy src folders to tmp folders
    isOk = file_copy(srcDir, tmpDir);
    if ~isOk
        Messages = ['Could not copy file:' srcDir];
        disp(['DUPLICATE> Error: ' Messages]);
        destPath = [];
        if isProgressBar
            bst_progress('stop');
        end
        return;
    end
    % Get source study structure
    sSrcStudy = bst_get('StudyWithCondition', srcPath);
    % Rename src subject to dest subject
    db_rename_condition(srcPath, destPath);
    % Copy contents tmp folder into new condition
    file_move(tmpDir, srcDir);
    % Add new study
    ProtocolStudy = bst_get('ProtocolStudies');
    ProtocolStudy.Study(end+1) = sSrcStudy;
    bst_set('ProtocolStudies', ProtocolStudy);
    % Refresh tree display
    if isRefresh
        panel_protocols('UpdateTree');
    end
    if isProgressBar
        bst_progress('stop');
    end
end
    

%% ===== DUPLICATE FILES =====
function [destFile, Messages] = DuplicateData(srcFile, Tag, isRefresh)
    % Parse inputs
    if (nargin < 3) || isempty(isRefresh)
        isRefresh = 1;
    end
    Messages = [];
    % Progress bar
    isProgressBar = ~bst_progress('isVisible');
    if isProgressBar
        bst_progress('start', 'Duplicate subject', 'Copying files...');
    end
    % Get protocol folders
    ProtocolInfo = bst_get('ProtocolInfo');
    % Output filename
    destFile = strrep(srcFile, '.mat', [Tag, '.mat']);
    [destFileFull, outTag] = file_unique(bst_fullfile(ProtocolInfo.STUDIES, destFile));
    % If an extra tag was added to the filename
    if ~isempty(outTag)
        Tag = [Tag, outTag];
        destFile = strrep(srcFile, '.mat', [Tag, '.mat']);
    end
    % Find file in database
    [sStudy, iStudy, iFile, fileType] = bst_get('AnyFile', srcFile);
    if isempty(sStudy)
        Messages = ['Could not find file in database:' srcFile];
        disp(['DUPLICATE> Error: ' Messages]);
        destFile = [];
        if isProgressBar
            bst_progress('stop');
        end
        return
    end
    if ~strcmpi(fileType, {'data', 'results', 'timefreq', 'matrix'})
        Messages = ['Cannot copy "' fileType '" files.'];
        disp(['DUPLICATE> Error: ' Messages]);
        destFile = [];
        if isProgressBar
            bst_progress('stop');
        end
        return
    end
    % Copy file
    srcFileFull = bst_fullfile(ProtocolInfo.STUDIES, srcFile);
    fileMat = load(srcFileFull);
    fileMat.Comment = [fileMat.Comment, Tag];
    bst_save(destFileFull, fileMat, 'v6');
    % Add description to the database
    switch (fileType)
        case 'data'
            sStudy.Data = AddStruct(sStudy.Data, iFile, destFile, Tag);
        case 'results'
            sStudy.Result = AddStruct(sStudy.Result, iFile, destFile, Tag);
        case 'timefreq'
            sStudy.Timefreq = AddStruct(sStudy.Timefreq, iFile, destFile, Tag);
        case 'matrix'
            sStudy.Matrix = AddStruct(sStudy.Matrix, iFile, destFile, Tag);
    end
    % Update database
    bst_set('Study', iStudy, sStudy);
    % Update links
    if strcmpi(fileType, 'data')
        db_links('Study', iStudy);
    end
    % Refresh tree display
    if isRefresh
        panel_protocols('UpdateTree');
    end
    if isProgressBar
        bst_progress('stop');
    end
end


%% ===== COPY STRUCTURE ====
function sAll = AddStruct(sAll, iOrig, newFile, Tag)
    % Copy structure
    iNew = length(sAll) + 1;
    sAll(iNew) = sAll(iOrig);
    % Replace filename
    sAll(iNew).FileName = newFile;
    % Replace comment
    sAll(iNew).Comment = [sAll(iNew).Comment, Tag];
end


