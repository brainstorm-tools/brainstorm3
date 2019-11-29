function OutputFiles = import_raw(RawFiles, FileFormat, iSubject, ImportOptions, DateOfStudy)
% IMPORT_RAW: Create a link to a raw file in the Brainstorm database.
%
% USAGE:  OutputFiles = import_raw(RawFiles=[ask], FileFormat=[ask], iSubject=[], ImportOptions=[], DateOfStudy=[])
%
% INPUTS:
%     - RawFiles      : Full path to the file to import in database
%     - FileFormat    : String representing the file format (CTF, FIF, 4D, ...)
%     - iSubject      : Subject indice in which to import the raw file
%     - ImportOptions : Structure that describes how to import the recordings
%       => Fields used: ChannelAlign, ChannelReplace, DisplayMessages, EventsMode, EventsTrackMode
%     - DateOfStudy   : String 'dd-MMM-yyyy', force Study entries created in the database to use this acquisition date

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2019

%% ===== PARSE INPUT =====
if (nargin < 5) || isempty(DateOfStudy)
    DateOfStudy = [];
end
if (nargin < 4) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end
if (nargin < 3)
    iSubject = [];
end
if (nargin < 2)
    RawFiles = [];
    FileFormat = [];
end
% Force list of files to be a cell array
if ~isempty(RawFiles) && ischar(RawFiles)
    RawFiles = {RawFiles};
end
% Some verifications
if ~isempty(RawFiles) && isempty(FileFormat)
    error('If you pass the filenames in input, you must define also the FileFormat argument.');
end
% Get Protocol information
ProtocolInfo = bst_get('ProtocolInfo');
OutputFiles = {};


%% ===== SELECT DATA FILE =====
% If file to load was not defined : open a dialog box to select it
if isempty(RawFiles) 
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get MRI file
    [RawFiles, FileFormat, FileFilter] = java_getfile( 'open', ...
        'Open raw EEG/MEG recordings...', ...  % Window title
        LastUsedDirs.ImportData, ...           % Last used directory
        'multiple', 'files_and_dirs', ...      % Selection mode
        bst_get('FileFilters', 'raw'), ...     % List of available file formats
        DefaultFormats.DataIn);
    % If no file was selected: exit
    if isempty(RawFiles)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportData = bst_fileparts(RawFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.DataIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    % Process the selected directories :
    %    1) If they are .ds/ directory with .meg4 and .res4 files : keep them as "files to open"
    %    2) Else : add all the data files they contains (subdirectories included)
    RawFiles = file_expand_selection(FileFilter, RawFiles);
    if isempty(RawFiles)
        error(['No data ' FileFormat ' file in the selected directories.']);
    end

    % ===== SUB-CATEGORIES IN FILE FORMAT =====
    if strcmpi(FileFormat, 'EEG-NEUROSCAN')
        [tmp, tmp, fileExt] = bst_fileparts(RawFiles{1});
        % Switch between different Neuroscan formats
        switch (lower(fileExt))
            case '.cnt',  FileFormat = 'EEG-NEUROSCAN-CNT';
            case '.eeg',  FileFormat = 'EEG-NEUROSCAN-EEG';
            case '.avg',  FileFormat = 'EEG-NEUROSCAN-AVG';
            case '.dat',  FileFormat = 'EEG-NEUROSCAN-DAT';
        end
    end
end


%% ===== ASCII IMPORT OPTIONS =====
% Display ASCII import options
if ImportOptions.DisplayMessages && (ismember(FileFormat, {'EEG-ASCII', 'EEG-BRAINVISION', 'EEG-MAT'}) || (strcmp(FileFormat, 'EEG-CARTOOL') && strcmpi(RawFiles{1}(end-2:end), '.ep')))
    gui_show_dialog('Import EEG data', @panel_import_ascii, [], [], FileFormat);
    % Check that import was not aborted
    ImportEegRawOptions = bst_get('ImportEegRawOptions');
    if ImportEegRawOptions.isCanceled
        return;
    end
end


%% ===== IMPORT =====
iOutputStudy = [];
isSSP = 0;
% Loop on the files to import
for iFile = 1:length(RawFiles)
    % ===== OPENING FILE =====
    bst_progress('start', 'Open raw EEG/MEG recordings', 'Reading file header...');
    % Open file
    [sFile, ChannelMat, errMsg, DataMat, ImportOptions] = in_fopen(RawFiles{iFile}, FileFormat, ImportOptions);
    if isempty(sFile)
        bst_progress('stop');
        return;
    end
    % Review imported files works only for single files (not for multiple trials)
    if (length(DataMat) > 1)
        error(['Cannot open multiple trials as continuous files.' 10 'Use the menu "Import MEG/EEG" instead.']);
    end
    % Yokogawa non-registered warning
    if ~isempty(errMsg) && ImportOptions.DisplayMessages
        java_dialog('warning', errMsg, 'Open raw EEG/MEG recordings');
    end

    % ===== OUTPUT STUDY =====
    % Get short filename
    [fPath, fBase] = bst_fileparts(RawFiles{iFile});
    % Remove "data_" tag when importing Brainstorm files as raw continuous files
    if strcmpi(FileFormat, 'BST-DATA') && (length(fBase) > 5) && strcmp(fBase(1:5), 'data_')
        fBase = fBase(6:end);
    end
    % Build output condition name
    if isfield(sFile, 'condition') && ~isempty(sFile.condition)
        ConditionName = ['@raw' sFile.condition];
    else
        ConditionName = ['@raw' fBase];
    end
    % Output subject
    if isempty(iSubject)
        % Get default subject
        SubjectName = 'NewSubject';
        [sSubject, iSubject] = bst_get('Subject', SubjectName, 1);
        % If subject does not exist yet: create it
        if isempty(sSubject)
            [sSubject, iSubject] = db_add_subject(SubjectName);
        end
        % If subject cannot be created
        if isempty(sSubject)
            error(['Could not create subject "' SubjectName '"']);
        end
    else
        % Get specified subject
        sSubject = bst_get('Subject', iSubject, 1);
    end
    % Do not allow automatic registration with head points when using the default anatomy
    if (sSubject.UseDefaultAnat)
        ImportOptions.ChannelAlign = 0;
    end

    % If condition already exists
    [sExistStudy, iExistStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, file_standardize(ConditionName, 1)));
    if ~isempty(sExistStudy) && ~isempty(sExistStudy.Data)
        % Need to check if the raw file is the same or they are two files with the same name in different folders
        % Get the raw data files
        iRaw = find(strcmpi({sExistStudy.Data.DataType}, 'raw'));
        if ~isempty(iRaw)
            % Load data description
            DataFile = sExistStudy.Data(iRaw).FileName;
            DataMat = in_bst_data(DataFile);
            % If same filenames or file linking imported data files: cannot link it again in the database
            LinkFile = DataMat.F.filename;
            minLength = min(length(LinkFile), length(RawFiles{iFile}));
            if file_compare(LinkFile(1:minLength), RawFiles{iFile}(1:minLength)) || strcmpi(FileFormat, 'BST-DATA')
                panel_protocols('SelectNode', [], 'rawdata', iExistStudy, iRaw );
                OutputFiles{end+1} = DataFile;
                continue;
            % Else: Create a condition with a different name
            else
                % Add a numeric tag at the end of the condition name
                curPath = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sExistStudy.FileName));
                curPath = file_unique(curPath);
                [tmp__, ConditionName] = bst_fileparts(curPath, 1);
                % Save it in the updated name in the "condition" field
                sFile.condition = strrep(ConditionName, '@raw', '');
            end
        end
    end
    % Creation date: use input value, or try to get it from the sFile structure
    if ~isempty(DateOfStudy)
        studyDate = DateOfStudy;
    elseif isfield(sFile, 'acq_date') && ~isempty(sFile.acq_date)
        studyDate = sFile.acq_date;
    else
        studyDate = [];
    end
    % Create output condition
    iOutputStudy = db_add_condition(sSubject.Name, ConditionName, [], studyDate);
    if isempty(iOutputStudy)
        error('Folder could not be created : "%s/%s".', bst_fileparts(sSubject.FileName), ConditionName);
    end
    % Get output study
    sOutputStudy = bst_get('Study', iOutputStudy);
    % Get the study in which the channel file has to be saved
    [sChannel, iChannelStudy] = bst_get('ChannelForStudy', iOutputStudy);
    
    % ===== CREATE DEFAULT CHANNEL FILE =====
    if isempty(ChannelMat)
        ChannelMat = db_template('channelmat');
        ChannelMat.Comment = [sFile.device ' channels'];
        ChannelMat.Channel = repmat(db_template('channeldesc'), [1, length(sFile.channelflag)]);
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
        % Add channel file to database
        db_set_channel(iChannelStudy, ChannelMat, 0, 0);

    % ===== SAVE LOADED CHANNEL FILE =====
    else
        % Add history field to channel structure
        ChannelMat = bst_history('add', ChannelMat, 'import', ['Link to file: ' RawFiles{iFile} ' (Format: ' FileFormat ')']);
        % Remove fiducials only from polhemus and ascii files
        isRemoveFid = ismember(FileFormat, {'MEGDRAW', 'POLHEMUS', 'ASCII_XYZ', 'ASCII_NXYZ', 'ASCII_XYZN', 'ASCII_XYZ_MNI', 'ASCII_NXYZ_MNI', 'ASCII_XYZN_MNI', 'ASCII_NXY', 'ASCII_XY', 'ASCII_NTP', 'ASCII_TP'});
        % Perform the NAS/LPA/RPA registration for some specific file formats
        isAlign = ismember(FileFormat, {'NIRS-BRS'});
        % Detect auxiliary EEG channels
        ChannelMat = channel_detect_type(ChannelMat, isAlign, isRemoveFid);
        % Do not align data coming from Brainstorm exported files (already aligned)
        if ismember(FileFormat, {'BST-BIN', 'BST-DATA'}) 
            ImportOptions.ChannelAlign = 0;
        end
        % Add channel file to database
        [ChannelFile, ChannelMat, ImportOptions.ChannelReplace, ImportOptions.ChannelAlign, Modality] = db_set_channel(iChannelStudy, ChannelMat, ImportOptions.ChannelReplace, ImportOptions.ChannelAlign);
        % If loading SEEG or ECOG data: change the sensor type
        if ismember(FileFormat, {'SEEG-ALL', 'ECOG-ALL'})
            Mod = strrep(FileFormat, '-ALL', '');
            process_channel_setseeg('Compute', ChannelFile, Mod);
        end
        % Display the registration if this was skipped in db_set_channel
        if (ImportOptions.ChannelAlign == 0) && (ImportOptions.DisplayMessages) && ~isempty(Modality)
            bst_memory('UnloadAll', 'Forced');
            channel_align_manual(ChannelFile, Modality, 0);
        end
        % If there are existing SSP in this file: notice the user
        if isfield(ChannelMat, 'Projector') && ~isempty(ChannelMat.Projector)
            isSSP = 1;
        end
    end
    
    % ===== EXPORT BST-BIN FILE =====
    % If the files that are read cannot be read as binary: save them as binary
    if isfield(sFile.header, 'F') && ~isempty(sFile.header.F) && ~isempty(DataMat)
        bst_progress('text', 'Converting file to binary .bst format...');
        % Prepare sFile structure
        ExportFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sOutputStudy.FileName), [fBase '.bst']);
        % Export binary file
        [ExportFile, sFile] = export_data(DataMat, ChannelMat, ExportFile, 'BST-BIN');
        % Display message in console
        disp(['BST> File converted to binary .bst format: ' ExportFile]);
    end
    
    % ===== SAVE LINK FILE =====
    % Build output filename
    NewBstFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sOutputStudy.FileName), ['data_0raw_' fBase '.mat']);
    % Build output structure
    DataMat = db_template('DataMat');
    DataMat.F           = sFile;
    DataMat.Comment     = 'Link to raw file';
    DataMat.ChannelFlag = sFile.channelflag;
    DataMat.Time        = sFile.prop.times;
    DataMat.DataType    = 'raw';
    DataMat.Device      = sFile.device;
    % Compumedics: add start time to the file comment
    if strcmpi(sFile.format, 'EEG-COMPUMEDICS-PFS') && isfield(sFile.header, 'rda_startstr') && ~isempty(sFile.header.rda_startstr)
        DataMat.Comment = [DataMat.Comment ' [' sFile.header.rda_startstr ']'];
    end
    % Add history field
    DataMat = bst_history('add', DataMat, 'import', ['Link to raw file: ' RawFiles{iFile}]);
    % Save file on hard drive
    bst_save(NewBstFile, DataMat, 'v6');
    % Add file to database
    sOutputStudy = db_add_data(iOutputStudy, NewBstFile, DataMat);
    % Return new file
    OutputFiles{end+1} = NewBstFile;

    % ===== UPDATE DATABASE =====
    % Update links
    db_links('Study', iOutputStudy);
    % Refresh both data node and channel node
    iUpdateStudies = unique([iOutputStudy, iChannelStudy]);
    panel_protocols('UpdateNode', 'Study', iUpdateStudies);
    
    % ===== ADD SYNCHRONIZED VIDEOS =====
    % Look for video files with the same name, add them to the raw folder if found
    for fExt = {'.avi','.AVI','.mpg','.MPG','.mpeg','.MPEG','.mp4','.MP4','.mp2','.MP2','.mkv','.MKV','.wmv','.WMV','.divx','.DIVX','.mov','.MOV'}
        VideoFile = bst_fullfile(fPath, [fBase, fExt{1}]);
        if file_exist(VideoFile)
            import_video(iOutputStudy, VideoFile);
            break;
        end
    end
end

% If something was imported
if ~isempty(iOutputStudy)
    % Select the data study node
    panel_protocols('SelectStudyNode', iOutputStudy);
    % Save database
    db_save();
end

% If some SSP files where present in the imported files, give the user a notice
if isSSP
    strWarning = ['The files you imported include SSP/ICA projectors.' 10 10 ...
                  'Review them before processing the files:' 10 ...
                  'tab Record > menu Artifacts > Select active projectors.'];
    % Non-interactive: Display message in command window
    if ~ImportOptions.DisplayMessages 
        disp(['BST> ' strrep(strWarning, char(10), [10, 'BST> '])]);
    % Interactive, one file: Open the SSP selection window
    elseif (length(OutputFiles) == 1)
        java_dialog('msgbox', strWarning);
        bst_memory('LoadDataFile', OutputFiles{1});
        panel_ssp_selection('OpenRaw');
    % Interactive, multiple file: Message box
    else
        java_dialog('msgbox', strWarning);
    end
end

bst_progress('stop');



