function [NewFiles, iStudyImport] = import_data(DataFiles, ChannelMat, FileFormat, iStudyInit, iSubjectInit, ImportOptions, DateOfStudy)
% IMPORT_DATA: Imports a list of datafiles in a Study of Brainstorm database
% 
% USAGE:  [NewFiles, iStudyImport] = import_data(DataFiles, [],         FileFormat, iStudyInit, iSubjectInit, ImportOptions, DateOfStudy=[])
%         [NewFiles, iStudyImport] = import_data(sFile,     ChannelMat, FileFormat, iStudyInit, iSubjectInit, ImportOptions, DateOfStudy=[])
%
% INPUT:
%    - DataFiles     : Cell array of full filenames of the data files to import (requires FileFormat to be set)
%                      If not specified or []: files to import are asked to the user
%    - sFile         : Structure representing a RAW file already open in Brainstorm
%    - ChannelMat    : Channel file structure (only when passing a sFile structure)
%    - FileFormat    : String that represent the file format of the files to import
%                      Possible values: {FIF, EEG-EGI-RAW, EEG-EEGLAB, EEG-CARTOOL, EEG-ERPCENTER, EEG-BRAINAMP, EEG_DELTAMED, EEG-NEUROSCOPE, EEG-BRAINAMP,
%                                        EEG-NEUROSCAN-CNT, EEG-NEUROSCAN-AVG, EEG-NEUROSCAN-DAT, EEG-NEUROSCAN-EEG, EEG-MAT, EEG-ASCII, EEG-EDF}
%                      Must be specified if and only if DataFiles is defined.
%    - iStudyInit    : Indice of the study where to import the files
%                      If not defined or []: a study is created automatically before importation (iSubjectInit must be specified)
%    - iSubjectInit  : Indice of the subject where to import the files.
%                      Must be specified if iStudyInit is not defined.
%                      In this case, default study is created for the target subject.
%    - ImportOptions : Structure that describes how to import the recordings.
%    - DateOfStudy   : String 'dd-MMM-yyyy', force Study entries created in the database to use this acquisition date
%
% NOTE : Some data filenames can be interpreted as subjects/conditions/run :
%    - cell<i>_<conditionName>_obs<j>.erp     : subject #j, condition #i, conditionName

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
% Authors: Francois Tadel, 2008-2023


%% ===== PARSE INPUTS =====
% Default values for all parameters
if (nargin < 7) || isempty(DateOfStudy)
    DateOfStudy = [];
end
if (nargin < 6) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end
if (nargin < 5) || isempty(iSubjectInit)
    iSubjectInit = 0;
end
if (nargin < 4) || isempty(iStudyInit) || (iStudyInit == 0)
    iStudyInit = 0;
else
    % If study indice is provided: override subject definition
    sStudTarg = bst_get('Study', iStudyInit);
    [tmp__, iSubjectInit] = bst_get('Subject', sStudTarg.BrainStormSubject);
end
if (nargin < 3)
    FileFormat = [];
end
sFile = [];
if (nargin < 1)
    DataFiles = [];
elseif isstruct(DataFiles)
    sFile = DataFiles;
    DataFiles = {sFile.filename};
    % Check channel file
    if isempty(ChannelMat)
        error('ChannelMat must be provided when calling in_data() with a sFile structure.');
    end
elseif ischar(DataFiles)
    DataFiles = {DataFiles};
end
% Some verifications
if ~isempty(DataFiles) && isempty(FileFormat)
    error('If you pass the filenames in input, you must define also the FileFormat argument.');
end
% Get Protocol information
ProtocolInfo = bst_get('ProtocolInfo');
% Initialize returned variable
NewFiles = {};
iStudyImport = [];


%% ===== SELECT DATA FILE =====
% If file to load was not defined : open a dialog box to select it
if isempty(DataFiles) 
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get MRI file
    [DataFiles, FileFormat, FileFilter] = java_getfile( 'open', ...
        'Import EEG/MEG recordings...', ...    % Window title
        LastUsedDirs.ImportData, ...           % Last used directory
        'multiple', 'files_and_dirs', ...      % Selection mode
        bst_get('FileFilters', 'data'), ...    % Get all the available file formats
        DefaultFormats.DataIn);                % Default file format
    % If no file was selected: exit
    if isempty(DataFiles)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportData = bst_fileparts(DataFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.DataIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    % Process the selected directories :
    %    1) If they are .ds/ directory with .meg4 and .res4 files : keep them as "files to open"
    %    2) Else : add all the data files they contains (subdirectories included)
    DataFiles = file_expand_selection(FileFilter, DataFiles);
    if isempty(DataFiles)
        error(['No data ' FileFormat ' file in the selected directories.']);
    end
    
    % ===== SUB-CATEGORIES IN FILE FORMAT =====
    if strcmpi(FileFormat, 'EEG-NEUROSCAN')
        [tmp, tmp, fileExt] = bst_fileparts(DataFiles{1});
        % Switch between different Neuroscan formats
        switch (lower(fileExt))
            case '.cnt',  FileFormat = 'EEG-NEUROSCAN-CNT';
            case '.eeg',  FileFormat = 'EEG-NEUROSCAN-EEG';
            case '.avg',  FileFormat = 'EEG-NEUROSCAN-AVG';
            case '.dat',  FileFormat = 'EEG-NEUROSCAN-DAT';
        end
    end
end


%% ===== IMPORT SELECTED DATA =====
% Reset data selection in study
nbCall = 0;
iNewAutoSubject = [];
isReinitStudy = 0;
iAllStudies = [];
iAllSubjects = [];

% Process all the selected data files
for iFile = 1:length(DataFiles)  
    nbCall = nbCall + 1;
    DataFile = DataFiles{iFile};
    [DataFile_path, DataFile_base] = bst_fileparts(DataFile);
    % Check file location (a file cannot be directly inside the brainstorm directories)
    itmp = strfind(DataFile_path, ProtocolInfo.STUDIES);
    if isempty(sFile) && ~isempty(itmp) && (itmp(1) == 1) 
         error(['You are not supposed to put your original files in the Brainstorm data directory.' 10 ...
                'This directory is part of the Brainstorm database and its content can be altered only' 10 ...
                'by the Brainstorm GUI.' 10 10 ...
                'Please create a new folder somewhere else, move all you original recordings files in it, ' 10 ...
                'and then try again to import them.']);
    end
    
    % List or directories where to copy the channel file
    iStudyCopyChannel = [];
    % If needed: reinitialize target study
    if isReinitStudy
        iStudyInit = 0;
    end
    
    % ===== CONVERT DATA FILE =====
    bst_progress('start', 'Import MEG/EEG recordings', ['Loading file "' DataFile '"...']);
    % Load file
    if ~isempty(sFile)
        [ImportedDataMat, ChannelMat, nChannels, nTime, ImportOptions] = in_data(sFile, ChannelMat, FileFormat, ImportOptions, nbCall);
        % Importing data from a RAW file already in the DB: the re-alignment is already done
        ImportOptions.ChannelReplace = 0;
        ImportOptions.ChannelAlign = 0;
        % Creation date: use input value, or try to get it from the sFile structure
        if ~isempty(DateOfStudy)
            studyDate = DateOfStudy;
        elseif isfield(sFile, 'acq_date') && ~isempty(sFile.acq_date)
            studyDate = sFile.acq_date;
        else
            studyDate = [];
        end
    else
        % If importing files in an existing folder: adapt to the existing channel file
        if ~isempty(iStudyInit) && ~isnan(iStudyInit) && (iStudyInit > 0)
            sStudyInit = bst_get('Study', iStudyInit);
            if ~isempty(sStudyInit) && ~isempty(sStudyInit.Channel) && ~isempty(sStudyInit.Channel(1).FileName)
                ChannelMatInit = in_bst_channel(sStudyInit.Channel(1).FileName);
            else
                ChannelMatInit = [];
            end
        else
            ChannelMatInit = [];
        end
        [ImportedDataMat, ChannelMat, nChannels, nTime, ImportOptions, studyDate] = in_data(DataFile, ChannelMatInit, FileFormat, ImportOptions, nbCall);
        % Creation date: use input value
        if ~isempty(DateOfStudy)
            studyDate = DateOfStudy;
        end
    end
    if isempty(ImportedDataMat)
        break;
    end
    % Detect differences in epoch sizes
    if (length(DataFiles) == 1) && ~isempty(nTime) && any(nTime ~= nTime(1)) && (ImportOptions.IgnoreShortEpochs >= 1)
        % Get the epochs that are too short
        iTooShort = find(nTime < max(nTime));
        % Ask user if the epochs that are too short should be removed
        if (ImportOptions.IgnoreShortEpochs == 1)
            res = java_dialog('confirm', sprintf('Some epochs (%d) are shorter than the others, ignore them?', length(iTooShort)), 'Import MEG/EEG recordings');
            if res
                ImportOptions.IgnoreShortEpochs = 2;
            else
                ImportOptions.IgnoreShortEpochs = 0;
            end
        end
        % Remove epochs that are too short
        if (ImportOptions.IgnoreShortEpochs >= 1)
            ImportedDataMat(iTooShort) = [];
            bst_report('Warning', 'process_import_data_event', DataFile, sprintf('%d epochs were ignored because they are shorter than the others.', length(iTooShort)));
        end
    end

    % ===== CREATE STUDY (IIF SUBJECT IS DEFINED) =====
    bst_progress('start', 'Import MEG/EEG recordings', 'Preparing output studies...');
    % Check if subject/condition is in filenames
    [SubjectName, ConditionName] = ParseDataFilename(ImportedDataMat(1).FileName);
    % If subj/cond are defined in filenames => default (ignore node that was clicked)
    if ~isempty(SubjectName)
        iSubjectInit = NaN;
    end
    if ~isempty(ConditionName)
        iStudyInit = NaN;
    end
        
    % If study is already known
    if (iStudyInit ~= 0) 
        iStudies = iStudyInit;
    % If a study needs to be created AND subject is already defined
    elseif (iStudyInit == 0) && (iSubjectInit ~= 0) && ~isnan(iSubjectInit)
        % Get the target subject
        sSubject = bst_get('Subject', iSubjectInit, 1);
        % When importing from files that are already in the database: Import by default in the same folder
        if strcmpi(FileFormat, 'BST-DATA') && ~isempty(bst_get('DataFile', DataFile))
            [sStudies, iStudies] = bst_get('DataFile', DataFile);
        % Else: Create a new condition based on the filename
        else
            % If importing from a raw link in the database: get the import condition from it
            if ~isempty(sFile) && isfield(sFile, 'condition') && ~isempty(sFile.condition)
                Condition = sFile.condition;
            % Else, use the file name
            else
                Condition = DataFile_base;
            end
            % Try to get default study
            [sStudies, iStudies] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, Condition));
            % If does not exist yet: Create the default study
            if isempty(iStudies)
                iStudies = db_add_condition(sSubject.Name, Condition, [], studyDate);
                if isempty(iStudies)
                    error('Default study could not be created : "%s".', Condition);
                end
                isReinitStudy = 1;
            end
        end
        iStudyInit = iStudies;
    % If need to create Subject + Condition + Study : do it file per file
    else
        iSubjectInit = NaN;
        iStudyInit   = NaN;
        iStudies     = [];
    end
    
    % ===== STORE IMPORTED FILES IN DB =====
    bst_progress('start', 'Import MEG/EEG recordings', 'Saving imported files in database...', 0, length(ImportedDataMat));
    strTag = '';
    importedPath = [];
    % Store imported data files in Brainstorm database
    for iImported = 1:length(ImportedDataMat)
        bst_progress('inc', 1);
        % ===== CREATE STUDY (IF SUBJECT NOT DEFINED) =====
        % Need to get a study for each imported file
        if isnan(iSubjectInit) || isnan(iStudyInit)
            % === PARSE FILENAME ===
            % Try to get subject name and condition name out of the filename
            [SubjectName, ConditionName] = ParseDataFilename(ImportedDataMat(iImported).FileName);
            sSubject = [];
            % === SUBJECT NAME ===
            if isempty(SubjectName)
                % If subject is defined by the input node: use this subject's name
                if (iSubjectInit ~= 0) && ~isnan(iSubjectInit)
                    [sSubject, iSubject] = bst_get('Subject', iSubjectInit);
                end
            else
                % Find the subject in DataBase
                [sSubject, iSubject] = bst_get('Subject', SubjectName, 1);
                % If subject is not found in DB: create it
                if isempty(sSubject)
                    [sSubject, iSubject] = db_add_subject(SubjectName);
                    % If subject cannot be created: error: stop everything
                    if isempty(sSubject)
                        error(['Could not create subject "' SubjectName '"']);
                    end
                end
            end
            % If a subject creation is needed
            if isempty(sSubject)
                SubjectName = 'NewSubject';
                % If auto subject was not created yet 
                if isempty(iNewAutoSubject)
                    % Try to get a subject with this name in database
                    [sSubject, iSubject] = bst_get('Subject', SubjectName);
                    % If no subject with automatic name exist in database, create it
                    if isempty(sSubject)
                        [sSubject, iSubject] = db_add_subject(SubjectName);
                        iNewAutoSubject = iSubject;
                    end
                % If auto subject was created for the previous imported file 
                else
                    [sSubject, iSubject] = bst_get('Subject', iNewAutoSubject);
                end
            end
            % === CONDITION NAME ===
            if isempty(ConditionName)
                % If a condition is defined by the input node
                if (iStudyInit ~= 0) && ~isnan(iStudyInit)
                    sStudyInit = bst_get('Study', iStudyInit);
                    ConditionName = sStudyInit.Condition{1};
                else
                    ConditionName = 'Default';
                end
            end
            % Get real subject directory (not the default subject directory, which is the default)
            sSubjectRaw = bst_get('Subject', iSubject, 1);
            % Find study (subject/condition) in database
            [sNewStudy, iNewStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubjectRaw.Name, ConditionName));
            % If study does not exist : create it
            if isempty(iNewStudy)
                iNewStudy = db_add_condition(sSubjectRaw.Name, ConditionName, 0, studyDate);
                if isempty(iNewStudy)
                    warning(['Cannot create condition : "' bst_fullfile(sSubjectRaw.Name, ConditionName) '"']);
                    continue;
                end
            end
            iStudies = [iStudies, iNewStudy];   
        else
            iSubject = iSubjectInit;
            sSubject = bst_get('Subject', iSubject);
            iStudies = iStudyInit;
        end
        % ===== CHANNEL FILE TARGET =====
        % If subject uses default channel
        if (sSubject.UseDefaultChannel)
            % Add the DEFAULT study directory to the list
            [sDefaultStudy, iDefaultStudy] = bst_get('DefaultStudy', iSubject);
            if ~isempty(iDefaultStudy)
                iStudyCopyChannel(iImported) = iDefaultStudy;
            else
                iStudyCopyChannel(iImported) = NaN;
            end
        else
            % Else add study directory in the list
            iStudyCopyChannel(iImported) = iStudies(end);
        end
        
        % ===== MOVE IMPORTED FILES IN STUDY DIRECTORY =====
        % Current study
        sStudy = bst_get('Study', iStudies(end));
        % Get study subdirectory
        studySubDir = bst_fileparts(sStudy.FileName);
        % Get the directory in which the file was stored by the in_data() function
        [importedPath, importedBase, importedExt] = bst_fileparts(ImportedDataMat(iImported).FileName);
        % Remove ___COND and ___SUBJ tags
        importedBase = removeStudyTags(importedBase);
        % Build final filename
        finalImportedFile = bst_fullfile(ProtocolInfo.STUDIES, studySubDir, [importedBase, strTag, importedExt]);
        [finalImportedFile, newTag] = file_unique(finalImportedFile);
        % Save new added tag
        if ~isempty(newTag)
            strTag = newTag;
        end
        % If data file is not in study subdirectory : need to move it
        if ~file_compare(importedPath, bst_fileparts(finalImportedFile))
            file_move(ImportedDataMat(iImported).FileName, finalImportedFile);
            ImportedDataMat(iImported).FileName = file_short(finalImportedFile);
        end
    
        % ===== STORE DATA FILE IN DATABASE ======
        % New data indice in study
        nbData = length(sStudy.Data) + 1;
        % Add data to subject
        sStudy.Data(nbData) = ImportedDataMat(iImported);
        % Store current study
        bst_set('Study', iStudies(end), sStudy);
        % Record all subjects
        iAllSubjects = [iAllSubjects, iSubject];
        % Only return the GOOD trials
        if ImportedDataMat(iImported).BadTrial
            % Save list of bad trials
            process_detectbad('SetTrialStatus', ImportedDataMat(iImported).FileName, 1);
        else
            % Add filename to list of newly created files
            NewFiles{end+1} = finalImportedFile;
            iStudyImport(end+1) = iStudies(end);
        end
    end
    clear sStudy studySubDir

    % Delete temporary import folder
    if ~isempty(importedPath)
        file_delete(importedPath, 1, 1);
    end

    % Remove NaN and duplicated values in studies list
    iStudies = unique(iStudies(~isnan(iStudies)));
    iStudyCopyChannel = unique(iStudyCopyChannel(~isnan(iStudyCopyChannel)));
    iAllStudies = [iAllStudies, iStudies, iStudyCopyChannel];
    
    
    %% ===== SAVE CHANNEL FILES =====
    % Create default channel file
    if isempty(ChannelMat)
        ChannelMat = db_template('channelmat');
        ChannelMat.Comment = 'Channel file';
        ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
        % For each channel
        for i = 1:length(ChannelMat.Channel)
            if (length(ChannelMat.Channel) > 99)
                ChannelMat.Channel(i).Name = sprintf('E%03d', i);
            else
                ChannelMat.Channel(i).Name = sprintf('E%02d', i);
            end
            ChannelMat.Channel(i).Type    = 'EEG';
            ChannelMat.Channel(i).Loc     = [0; 0; 0];
            ChannelMat.Channel(i).Orient  = [];
            ChannelMat.Channel(i).Weight  = 1;
            ChannelMat.Channel(i).Comment = [];
        end
        % Save channel file in all the target studies
        for i = 1:length(iStudyCopyChannel)
            db_set_channel(iStudyCopyChannel(i), ChannelMat, 0, 0);
        end
    else
        % Check for empty channels
        iEmpty = find(cellfun(@isempty, {ChannelMat.Channel.Name}));
        for i = 1:length(iEmpty)
            ChannelMat.Channel(iEmpty(i)).Name = sprintf('%04d', iEmpty(i));
        end
        % Check for duplicate channels
        for i = 1:length(ChannelMat.Channel)
            iOther = setdiff(1:length(ChannelMat.Channel), i);
            ChannelMat.Channel(i).Name = file_unique(ChannelMat.Channel(i).Name, {ChannelMat.Channel(iOther).Name});
        end
        % Remove fiducials only from polhemus and ascii files
        isRemoveFid = ismember(FileFormat, {'MEGDRAW', 'POLHEMUS', 'ASCII_XYZ', 'ASCII_NXYZ', 'ASCII_XYZN', 'ASCII_XYZ_MNI', 'ASCII_NXYZ_MNI', 'ASCII_XYZN_MNI', 'ASCII_NXY', 'ASCII_XY', 'ASCII_NTP', 'ASCII_TP'});
        % Perform the NAS/LPA/RPA registration for some specific file formats
        isAlign = ismember(FileFormat, {'NIRS-BRS','NIRS-SNIRF'});
        % Detect auxiliary EEG channels
        ChannelMat = channel_detect_type(ChannelMat, isAlign, isRemoveFid);
        % Do not align data coming from Brainstorm exported files (already aligned)
        if strcmpi(FileFormat, 'BST-BIN')
            ImportOptions.ChannelAlign = 0;
        % Do not allow automatic registration with head points when using the default anatomy
        elseif (sSubject.UseDefaultAnat) || isempty(sSubject.Anatomy) || any(~cellfun(@(c)isempty(strfind(lower(sSubject.Anatomy(sSubject.iAnatomy).Comment), c)), {'icbm152', 'colin27', 'bci-dni', 'uscbrain', 'fsaverage', 'oreilly', 'kabdebon'}))
            ImportOptions.ChannelAlign = 0;
        end
        % Save channel file in all the target studies (need user confirmation for overwrite)
        for i = 1:length(iStudyCopyChannel)
            [ChannelFile, tmp, ImportOptions.ChannelReplace, ImportOptions.ChannelAlign] = db_set_channel(iStudyCopyChannel(i), ChannelMat, ImportOptions.ChannelReplace, ImportOptions.ChannelAlign);
        end
    end
end
bst_progress('stop');


%% ===== UPDATE DISPLAY =====
% Update links
if ~isempty(iAllSubjects)
    iAllSubjects = unique(iAllSubjects);
    for i = 1:length(iAllSubjects)
        db_links('Subject', iAllSubjects(i));
    end
end
% Update tree
if ~isempty(iAllStudies)
    iAllStudies = unique(iAllStudies);
    panel_protocols('UpdateNode', 'Study', iAllStudies);
    if (length(NewFiles) == 1)
        panel_protocols('SelectNode', [], NewFiles{1});
    elseif (length(iAllStudies) == 1)
        panel_protocols('SelectStudyNode', iAllStudies(1));
    end
end
% Edit new subject (if a new subject was created automatically)
if ~isempty(iNewAutoSubject)
    db_edit_subject(iNewAutoSubject);
end
% Save database
db_save();


return
end




%% ================================================================================
%  ===== HELPER FUNCTIONS =========================================================
%  ================================================================================
% Parse filename to detect subject/condition/run
function [SubjectName, ConditionName] = ParseDataFilename(filename)
    SubjectName   = '';
    ConditionName = '';
    % Get only short filename without extension
    [fPath, fName, fExt] = bst_fileparts(filename);
    
    % IMPORTED FILENAMES : '....___SUBJsubjectname___CONDcondname___...'
    % Get subject tag
    iTag_subj = strfind(fName, '___SUBJ');
    if ~isempty(iTag_subj)
        iStartSubj = iTag_subj + 7;
        % Find closing tag
        iCloseSubj = strfind(fName(iStartSubj:end), '___');
        % Find closing tag
        if ~isempty(iCloseSubj)
            SubjectName = fName(iStartSubj:iStartSubj + iCloseSubj - 2);
        end
    end
    
    % Get condition tag
    iTag_cond = strfind(fName, '___COND');
    if ~isempty(iTag_cond)
        iStartCond = iTag_cond + 7;
        % Find closing tag
        iCloseCond = strfind(fName(iStartCond:end), '___');
        % Find closing tag
        if ~isempty(iCloseCond)
            ConditionName = fName(iStartCond:iStartCond + iCloseCond - 2);
        end
    end
end

% Remove study tags (___COND and ___SUBJ)
function fname = removeStudyTags(fname)
    iTags = strfind(fname, '___');
    if iTags >= 2
        iStart = iTags(1);
        if (iTags(end) + 2 == length(fname))
            iStop  = iTags(end) + 2;
        else
            % Leave at least one '_' as a separator
            iStop  = iTags(end) + 1;
        end
        fname(iStart:iStop) = [];
    end
end
