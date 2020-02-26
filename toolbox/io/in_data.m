function [ImportedData, ChannelMat, nChannels, nTime, ImportOptions, DateOfStudy] = in_data( DataFile, ChannelMat, FileFormat, ImportOptions, nbCall)
% IN_DATA: Import any type of EEG/MEG recordings files.
%
% USAGE:  [ImportedData, ChannelMat, nChannels, nTime, ImportOptions, DateOfStudy] = in_data( DataFile, [], FileFormat, ImportOptions, nbCall ) 
%         [ImportedData, ChannelMat, nChannels, nTime, ImportOptions, DateOfStudy] = in_data( DataFile, [], FileFormat, ImportOptions )    % Considered as first call
%         [ImportedData, ChannelMat, nChannels, nTime, ImportOptions, DateOfStudy] = in_data( DataFile, [], FileFormat )                   % Display the import GUI
%         [ImportedData, ChannelMat, nChannels, nTime, ImportOptions, DateOfStudy] = in_data( sFile, ChannelMat, FileFormat, ...)            % Same calls, but specify the sFile/ChannelMat structures
%
% INPUT:
%    - DataFile      : Full path to a recordings file (called 'data' files in Brainstorm)
%    - ChannelMat    : Channel file structure
%    - sFile         : Structure representing a RAW file already open in Brainstorm
%    - FileFormat    : File format name
%    - ImportOptions : Structure that describes how to import the recordings
%    - nbCall        : For internal use only (indice of this call when consecutive calls from import_data.m
% 
% OUTPUT: 
%    - ImportedData : Brainstorm standard recordings ('data') structure
%    - ChannelMat   : Brainstorm standard channels structure
%    - nTime        : Number of time points that were read
%    - ImportOptions: Return the modifications made to ImportOptions, so that the next calls use the same options

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
% Authors: Francois Tadel, 2008-2018

%% ===== PARSE INPUTS ===== 
if (nargin < 5) || isempty(nbCall)
    nbCall = 1;
end
if (nargin < 4) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end
% Define structure sFile 
sFile = [];
nChannels = 0;
if (nargin < 3)
    error('Invalid call.');
elseif isstruct(DataFile)
    sFile = DataFile;
    DataFile = sFile.filename;
    % Check channel file
    if isempty(ChannelMat)
        error('ChannelMat must be provided when calling in_data() with a sFile structure.');
    end
elseif ~isempty(strfind(DataFile, '_0raw'))
    FileMat = in_bst_data(DataFile, 'F');
    sFile   = FileMat.F;
    % Read channel file
    if isempty(ChannelMat)
        ChannelFile = bst_get('ChannelFileForStudy', DataFile);
        ChannelMat = in_bst_channel(ChannelFile);
    end
    DataFile = sFile.filename;
elseif ~file_exist(DataFile)
    error('File does not exist: "%s"', DataFile);
end


%% ===== READ FILE =====
% Initialize returned variables
ImportedData = [];
nTime = [];
DateOfStudy = [];
% Get temporary directory
tmpDir = bst_get('BrainstormTmpDir');
[filePath, fileBase, fileExt] = bst_fileparts(DataFile);
% Reading as raw continuous?
isRaw = ismember(FileFormat, {'FIF', 'CTF', 'CTF-CONTINUOUS', '4D', 'KIT', 'RICOH', 'KDF', 'ITAB', 'MEGSCAN-HDF5', 'EEG-ANT-CNT', 'EEG-ANT-MSR', 'EEG-BRAINAMP', 'EEG-DELTAMED', 'EEG-COMPUMEDICS-PFS', 'EEG-EGI-RAW', 'EEG-NEUROSCAN-CNT', 'EEG-NEUROSCAN-EEG', 'EEG-NEUROSCAN-AVG', 'EEG-EDF', 'EEG-BDF', 'EEG-EEGLAB', 'EEG-GTEC', 'EEG-MANSCAN', 'EEG-MICROMED', 'EEG-NEURALYNX', 'EEG-BLACKROCK', 'EEG-RIPPLE', 'EEG-NEURONE', 'EEG-NEUROSCOPE', 'EEG-NICOLET', 'EEG-NK', 'EEG-SMR', 'SPM-DAT', 'NIRS-BRS', 'BST-DATA', 'BST-BIN', 'EYELINK', 'EEG-EDF', 'EEG-EGI-MFF', 'EEG-INTAN', 'EEG-PLEXON', 'EEG-TDT', 'NWB', 'NWB-CONTINUOUS', 'EEG-CURRY'});

%% ===== READ RAW FILE =====
if isRaw
    % Initialize list of file blocks to read
    BlocksToRead = repmat(struct('iEpoch',      [], ...
                                 'iTimes',      '', ...
                                 'FileTag',     '', ...
                                 'Comment',     '', ...
                                 'TimeOffset',  0, ...
                                 'isBad',       [], ...
                                 'ChannelFlag', [], ...
                                 'ImportTime',  ''), 0);
    % If file not open yet: Open file
    if isempty(sFile)
        [sFile, ChannelMat, errMsg] = in_fopen(DataFile, FileFormat, ImportOptions);
        if isempty(sFile)
            return
        end
        % Yokogawa non-registered warning
        if ~isempty(errMsg) && ImportOptions.DisplayMessages
            java_dialog('warning', errMsg, 'Open raw EEG/MEG recordings');
        end
    end
    % Get acquisition date
    if isfield(sFile, 'acq_date') && ~isempty(sFile.acq_date)
        DateOfStudy = sFile.acq_date;
    end

    % Display import GUI
    if (nbCall == 1) && ImportOptions.DisplayMessages
        comment = ['Import ' sFile.format ' file'];
        ImportOptions = gui_show_dialog(comment, @panel_import_data, 1, [], sFile, ChannelMat);
        % If user canceled the process
        if isempty(ImportOptions)
            bst_progress('stop');
            return
        end
    % Check number of epochs
    elseif strcmpi(ImportOptions.ImportMode, 'Epoch')
        if isempty(sFile.epochs)
            error('This file does not contain any epoch. Try importing it as continuous, or based on events.');
        elseif ImportOptions.GetAllEpochs
            ImportOptions.iEpochs = 1:length(sFile.epochs);
        elseif any(ImportOptions.iEpochs > length(sFile.epochs)) || any(ImportOptions.iEpochs < 1)
            error(['You selected an invalid epoch index.' 10 ...
                   'To import all the epochs at once, please check the "Use all epochs" option.' 10]);
        end
    end

    % Switch between file types
    switch lower(ImportOptions.ImportMode)
        % ===== EPOCHS =====
        case 'epoch'
            % If all data sets have the same comment: consider them as trials
            isTrials = (length(sFile.epochs) > 1) && all(strcmpi({sFile.epochs.label}, sFile.epochs(1).label));
            % Loop on all epochs
            for ieph = 1:length(ImportOptions.iEpochs)
                % Get epoch number
                iEpoch = ImportOptions.iEpochs(ieph);
                % Import structure
                BlocksToRead(end+1).iEpoch   = iEpoch;
                BlocksToRead(end).Comment    = sFile.epochs(iEpoch).label;
                BlocksToRead(end).TimeOffset = 0;
                BlocksToRead(end).ImportTime = sFile.epochs(iEpoch).times;
                % Copy optional fields
                if isfield(sFile.epochs(iEpoch), 'bad') && (sFile.epochs(iEpoch).bad == 1)
                    BlocksToRead(end).isBad = 1;
                end
                if isfield(sFile.epochs(iEpoch), 'channelflag') && ~isempty(sFile.epochs(iEpoch).channelflag)
                    BlocksToRead(end).ChannelFlag = sFile.epochs(iEpoch).channelflag;
                end
                % Build file tag
                FileTag = BlocksToRead(end).Comment;
                % Add trial number, if considering sets as a list of trials for the same condition
                if isTrials
                    FileTag = [FileTag, sprintf('_trial%03d', iEpoch)];
                end
                % Add condition TAG, if required in input options structure
                if ImportOptions.CreateConditions 
                    CondName = strrep(BlocksToRead(end).Comment, '#', '');
                    CondName = str_remove_parenth(CondName);
                    FileTag = [FileTag, '___COND', CondName, '___'];
                end
                BlocksToRead(end).FileTag = FileTag;
                % Number of averaged trials
                BlocksToRead(end).nAvg = sFile.epochs(iEpoch).nAvg;
            end

        % ===== RAW DATA: READING TIME RANGE =====
        case 'time'
            % Check time window
            if isempty(ImportOptions.TimeRange)
                ImportOptions.TimeRange = sFile.prop.times;
            end
            % If SplitLength not defined: use the whole time range
            if ~ImportOptions.SplitRaw || isempty(ImportOptions.SplitLength)
                ImportOptions.SplitLength = ImportOptions.TimeRange(2) - ImportOptions.TimeRange(1) + 1/sFile.prop.sfreq;
            end
            % Get block size in samples
            blockSmpLength = round(ImportOptions.SplitLength * sFile.prop.sfreq);
            totalSmpLength = round((ImportOptions.TimeRange(2) - ImportOptions.TimeRange(1)) * sFile.prop.sfreq) + 1;
            startSmp = round(ImportOptions.TimeRange(1) * sFile.prop.sfreq);                   
            % Get number of blocks
            nbBlocks = ceil(totalSmpLength / blockSmpLength);
            % For each block
            for iBlock = 1:nbBlocks
                % Get samples indices for this block (start ind = 0)
                smpBlock = startSmp + [(iBlock - 1) * blockSmpLength, min(iBlock * blockSmpLength - 1, totalSmpLength - 1)];
                % Import structure
                BlocksToRead(end+1).iEpoch   = 1;
                BlocksToRead(end).iTimes     = smpBlock;
                BlocksToRead(end).FileTag    = sprintf('block%03d', iBlock);
                BlocksToRead(end).TimeOffset = 0;
                % Build comment (seconds or miliseconds)
                BlocksToRead(end).ImportTime = smpBlock / sFile.prop.sfreq;
                if (BlocksToRead(end).ImportTime(2) > 2)
                    BlocksToRead(end).Comment = sprintf('Raw (%1.2fs,%1.2fs)', BlocksToRead(end).ImportTime);
                else
                    BlocksToRead(end).Comment = sprintf('Raw (%dms,%dms)', round(1000 * BlocksToRead(end).ImportTime));
                end
                % Number of averaged trials
                BlocksToRead(end).nAvg = sFile.prop.nAvg;
            end

        % ===== EVENTS =====
        case 'event'
            isExtended = false;
            % For each event
            for iEvent = 1:length(ImportOptions.events)
                nbOccur = size(ImportOptions.events(iEvent).times, 2);
                % Detect event type: simple or extended
                isExtended = (size(ImportOptions.events(iEvent).times, 1) == 2);
                % For each occurrence of this event
                for iOccur = 1:nbOccur
                    % Samples range to read
                    if isExtended
                        samplesBounds = [0, diff(round(ImportOptions.events(iEvent).times(:,iOccur) * sFile.prop.sfreq))];
                        % Disable option "Ignore shorter epochs"
                        if ImportOptions.IgnoreShortEpochs
                            ImportOptions.IgnoreShortEpochs = 0;
                            bst_report('Warning', 'process_import_data_event', [], 'Importing extended epochs: disabling option "Ignore shorter epochs".');
                        end
                    else
                        samplesBounds = round(ImportOptions.EventsTimeRange * sFile.prop.sfreq);
                    end
                    % Get epoch indices
                    samplesEpoch = round(round(ImportOptions.events(iEvent).times(1,iOccur) * sFile.prop.sfreq) + samplesBounds);
                    if (samplesEpoch(1) < round(sFile.prop.times(1) * sFile.prop.sfreq))
                        % If required time before event is not accessible: 
                        TimeOffset = (round(sFile.prop.times(1) * sFile.prop.sfreq) - samplesEpoch(1)) / sFile.prop.sfreq;
                        samplesEpoch(1) = round(sFile.prop.times(1) * sFile.prop.sfreq);
                    else
                        TimeOffset = 0;
                    end
                    % Make sure all indices are valids
                    samplesEpoch = bst_saturate(samplesEpoch, round(sFile.prop.times * sFile.prop.sfreq));
                    % Import structure
                    BlocksToRead(end+1).iEpoch   = ImportOptions.events(iEvent).epochs(iOccur);
                    BlocksToRead(end).iTimes     = samplesEpoch;
                    BlocksToRead(end).Comment    = sprintf('%s (#%d)', ImportOptions.events(iEvent).label, iOccur);
                    BlocksToRead(end).FileTag    = sprintf('%s_trial%03d', ImportOptions.events(iEvent).label, iOccur);
                    BlocksToRead(end).TimeOffset = TimeOffset;
                    BlocksToRead(end).nAvg       = 1;
                    BlocksToRead(end).ImportTime = samplesEpoch / sFile.prop.sfreq;
                    % Add condition TAG, if required in input options structure
                    if ImportOptions.CreateConditions 
                        CondName = strrep(ImportOptions.events(iEvent).label, '#', '');
                        CondName = str_remove_parenth(CondName);
                        BlocksToRead(end).FileTag = [BlocksToRead(end).FileTag, '___COND' CondName '___'];
                    end
                end
            end
            % In case of extended events: Ignore the EventsTimeRange time range field, and force time to start at 0
            if isExtended
                %ImportOptions.ImportMode = 'time';
                ImportOptions.EventsTimeRange = [0 1];
            end
    end

    % ===== UPDATE CHANNEL FILE =====
    % No CTF Compensation
    if ~ImportOptions.UseCtfComp && ~isempty(ChannelMat)
        ChannelMat.MegRefCoef = [];
        sFile.prop.destCtfComp = sFile.prop.currCtfComp;
    end
    % No SSP
    if ~ImportOptions.UseSsp && ~isempty(ChannelMat) && isfield(ChannelMat, 'Projector') && ~isempty(ChannelMat.Projector)
        % Remove projectors that are not already applied
        iProjDel = find([ChannelMat.Projector.Status] ~= 2);
        ChannelMat.Projector(iProjDel) = [];
    end

    % ===== READING AND SAVING =====
    % Get list of bad segments in file
    [badSeg, badEpochs, badTimes, badChan] = panel_record('GetBadSegments', sFile);
    % Initialize returned variables
    ImportedData = repmat(db_template('Data'), 0);

    initBaselineRange = ImportOptions.BaselineRange;
    % Prepare progress bar
    bst_progress('start', 'Import MEG/EEG recordings', 'Initializing...', 0, length(BlocksToRead));
    % Loop on each recordings block to read
    for iFile = 1:length(BlocksToRead)
        % Set progress bar
        bst_progress('text', sprintf('Importing block #%d/%d...', iFile, length(BlocksToRead)));

        % ===== READING DATA =====
        % If there is a time offset: need to apply it to the baseline range...
        if (BlocksToRead(iFile).TimeOffset ~= 0) && strcmpi(ImportOptions.RemoveBaseline, 'time')
            ImportOptions.BaselineRange = initBaselineRange - BlocksToRead(iFile).TimeOffset;
        end
        % Read data block
        [F, TimeVector] = in_fread(sFile, ChannelMat, BlocksToRead(iFile).iEpoch, BlocksToRead(iFile).iTimes, [], ImportOptions);
        % If block too small: ignore it
        if (size(F,2) < 3)
            disp(sprintf('BST> Block is too small #%03d: ignoring...', iFile));
            continue
        end
        % Add an addition time offset if defined
        if (BlocksToRead(iFile).TimeOffset ~= 0)
            TimeVector = TimeVector + BlocksToRead(iFile).TimeOffset;
        end
        % Build file structure
        DataMat = db_template('DataMat');
        DataMat.F        = F;
        DataMat.Comment  = BlocksToRead(iFile).Comment;
        DataMat.Time     = TimeVector;
        DataMat.Device   = sFile.device;
        DataMat.nAvg     = double(BlocksToRead(iFile).nAvg);
        DataMat.DataType = 'recordings';
        % Channel flag
        if ~isempty(BlocksToRead(iFile).ChannelFlag) 
            DataMat.ChannelFlag = BlocksToRead(iFile).ChannelFlag;
        else
            DataMat.ChannelFlag = sFile.channelflag;
        end

        % ===== GOOD / BAD TRIAL =====
        % By default: segment of data is good
        isBad = 0;
        % If data block has already been marked as bad at an earlier stage, keep it bad 
        if ~isempty(BlocksToRead(iFile).isBad) && BlocksToRead(iFile).isBad
            isBad = 1;
        end
        % Get the block bounds (in samples #)
        iTimes = BlocksToRead(iFile).iTimes;
        % But if there are some bad segments in the file, check that the data we are reading is not overlapping with one of these segments
        if ~isempty(iTimes) && ~isempty(badSeg)
            % Check if this segment is outside of ALL the bad segments (either entirely before or entirely after)
            iBadSeg = find((iTimes(2) >= badSeg(1,:)) & (iTimes(1) <= badSeg(2,:)));
        % For files read by epochs: check for bad epochs
        elseif isempty(iTimes) && ~isempty(badEpochs)
            iBadSeg = find(BlocksToRead(iFile).iEpoch == badEpochs);
        else
            iBadSeg = [];
        end
        % If there are bad segments
        if ~isempty(iBadSeg)
            % Mark trial as bad (if not already set)
            if (isempty(badChan) || any(cellfun(@isempty, badChan(iBadSeg))))
                isBad = 1;
            end
            % Add bad channels defined by events
            if ~isempty(badChan) && ~all(cellfun(@isempty, badChan(iBadSeg))) && ~isempty(ChannelMat)
                iBadChan = find(ismember({ChannelMat.Channel.Name}, unique(cat(2, {}, badChan{iBadSeg}))));
                if ~isempty(iBadChan)
                    DataMat.ChannelFlag(iBadChan) = -1;
                end
            end
        end
        
        % ===== ADD HISTORY FIELD =====
        % This records all the processes applied in in_fread (reset field)
        DataMat = bst_history('reset', DataMat);
        % History: File name
        DataMat = bst_history('add', DataMat, 'import', ['Import from: ' DataFile ' (' ImportOptions.ImportMode ')']);
        % History: Epoch / Time block
        DataMat = bst_history('add', DataMat, 'import_epoch', sprintf('    %d', BlocksToRead(iFile).iEpoch));
        DataMat = bst_history('add', DataMat, 'import_time',  sprintf('    [%1.6f, %1.6f]', BlocksToRead(iFile).ImportTime));
        % History: CTF compensation
        if ~isempty(ChannelMat) && ~isempty(ChannelMat.MegRefCoef) && (sFile.prop.currCtfComp ~= sFile.prop.destCtfComp)
            DataMat = bst_history('add', DataMat, 'import', '    Apply CTF compensation matrix');
        end
        % History: SSP
        if ~isempty(ChannelMat) && ~isempty(ChannelMat.Projector)
            DataMat = bst_history('add', DataMat, 'import', '    Apply SSP projectors');
        end
        % History: Baseline removal
        switch (ImportOptions.RemoveBaseline)
            case 'all'
                DataMat = bst_history('add', DataMat, 'import', '    Remove baseline (all)');
            case 'time'
                DataMat = bst_history('add', DataMat, 'import', sprintf('    Remove baseline: [%d, %d] ms', round(ImportOptions.BaselineRange * 1000)));
        end
        % History: resample
        if ImportOptions.Resample && (abs(ImportOptions.ResampleFreq - sFile.prop.sfreq) > 0.05)
            DataMat = bst_history('add', DataMat, 'import', sprintf('    Resample: from %0.2f Hz to %0.2f Hz', sFile.prop.sfreq, ImportOptions.ResampleFreq));
        end

        % ===== EVENTS =====
        OldFreq = sFile.prop.sfreq;
        NewFreq = 1 ./ (TimeVector(2) - TimeVector(1));
        % Loop on all the events types
        for iEvt = 1:length(sFile.events)
            evtSamples  = round(sFile.events(iEvt).times * sFile.prop.sfreq);
            readSamples = BlocksToRead(iFile).iTimes;
            % If there are no occurrences, or if it the event of interest: skip to next event type
            if isempty(evtSamples) || (strcmpi(ImportOptions.ImportMode, 'event') && any(strcmpi({ImportOptions.events.label}, sFile.events(iEvt).label)))
                continue;
            end
            % Set the number of read samples for epochs
            if isempty(readSamples) && strcmpi(ImportOptions.ImportMode, 'epoch')
                if isempty(sFile.epochs)
                    readSamples = round(sFile.prop.times * sFile.prop.sfreq);
                else
                    readSamples = round(sFile.epochs(BlocksToRead(iFile).iEpoch).times * sFile.prop.sfreq);
                end
            end
            % Apply resampling factor if necessary
            if (abs(OldFreq - NewFreq) > 0.05)
                evtSamples  = round(evtSamples  / OldFreq * NewFreq);
                readSamples = round(readSamples / OldFreq * NewFreq);
            end
            % Simple events
            if (size(evtSamples, 1) == 1)
                if (size(evtSamples,2) == size(sFile.events(iEvt).epochs,2))
                    iOccur = find((evtSamples >= readSamples(1)) & (evtSamples <= readSamples(2)) & (sFile.events(iEvt).epochs == BlocksToRead(iFile).iEpoch));
                else
                    iOccur = find((evtSamples >= readSamples(1)) & (evtSamples <= readSamples(2)));
                    disp(sprintf('BST> Warning: Mismatch in the events structures: size(samples)=%d, size(epochs)=%d', size(evtSamples,2), size(sFile.events(iEvt).epochs,2)));
                end
                % If no occurence found in current time block: skip to the next event
                if isempty(iOccur)
                    continue;
                end
                % Calculate the sample indices of the events in the new file
                iTimeEvt = bst_saturate(evtSamples(:,iOccur) - readSamples(1) + 1, [1, length(TimeVector)]);
                newEvtTimes = round(TimeVector(iTimeEvt) .* NewFreq) ./ NewFreq;
                    
            % Extended events: Get all the events that are not either completely before or after the time window
            else
                iOccur = find((evtSamples(2,:) >= readSamples(1)) & (evtSamples(1,:) <= readSamples(2)) & (sFile.events(iEvt).epochs(1,:) == BlocksToRead(iFile).iEpoch(1,:)));
                % If no occurence found in current time block: skip to the next event
                if isempty(iOccur)
                    continue;
                end
                % Limit to current time window
                evtSamples(evtSamples < readSamples(1)) = readSamples(1);
                evtSamples(evtSamples > readSamples(2)) = readSamples(2);
                % Calculate the sample indices of the events in the new file
                iTimeEvt1 = bst_saturate(evtSamples(1,iOccur) - readSamples(1) + 1, [1, length(TimeVector)]);
                iTimeEvt2 = bst_saturate(evtSamples(2,iOccur) - readSamples(1) + 1, [1, length(TimeVector)]);
                newEvtTimes = [round(TimeVector(iTimeEvt1) .* NewFreq); ...
                               round(TimeVector(iTimeEvt2) .* NewFreq)] ./ NewFreq;
            end
            % Add new event category in the output file
            iEvtData = length(DataMat.Events) + 1;
            DataMat.Events(iEvtData).label    = sFile.events(iEvt).label;
            DataMat.Events(iEvtData).color    = sFile.events(iEvt).color;
            DataMat.Events(iEvtData).times    = newEvtTimes;
            DataMat.Events(iEvtData).epochs   = sFile.events(iEvt).epochs(iOccur);
            DataMat.Events(iEvtData).channels = sFile.events(iEvt).channels(iOccur);
            DataMat.Events(iEvtData).notes    = sFile.events(iEvt).notes(iOccur);
            if ~isempty(sFile.events(iEvt).reactTimes)
                DataMat.Events(iEvtData).reactTimes = sFile.events(iEvt).reactTimes(iOccur);
            end
            DataMat.Events(iEvtData).select = sFile.events(iEvt).select;
        end

        % ===== SAVE FILE =====
        % Add extension, full path, and make valid and unique
        newFileName = ['data_', BlocksToRead(iFile).FileTag, '.mat'];
        newFileName = file_standardize(newFileName);
        newFileName = bst_fullfile(tmpDir, newFileName);
        newFileName = file_unique(newFileName);
        % Save new file
        bst_save(newFileName, DataMat, 'v6');
        % Information to store in database
        ImportedData(end+1).FileName = newFileName;
        ImportedData(end).Comment    = DataMat.Comment;
        ImportedData(end).DataType   = DataMat.DataType;
        ImportedData(end).BadTrial   = isBad;
        % Count number of time points
        nTime(end+1) = length(TimeVector);
        nChannels = size(DataMat.F,1);
        % Increment progress bar
        bst_progress('inc', 1);
    end

%% ===== READ FULL DATA MATRIX =====
else
    % Display ASCII import options
    if ImportOptions.DisplayMessages && (nbCall <= 1) && (ismember(FileFormat, {'EEG-ASCII', 'EEG-BRAINVISION', 'EEG-MAT'}) || (strcmp(FileFormat, 'EEG-CARTOOL') && strcmpi(DataFile(end-2:end), '.ep')))
        gui_show_dialog('Import EEG data', @panel_import_ascii, [], [], FileFormat);
        % Check that import was not aborted
        ImportEegRawOptions = bst_get('ImportEegRawOptions');
        if ImportEegRawOptions.isCanceled
            return;
        end
    end
    % Read file
    [tmp, ChannelMatData, errMsg, DataMat] = in_fopen(DataFile, FileFormat);
    if isempty(DataMat) || ~isempty(errMsg)
        return;
    end
    % If there is no channel file yet, use the one from the input file
    if isempty(ChannelMat) && ~isempty(ChannelMatData)
        ChannelMat = ChannelMatData;
    % Reorganize data to fit the existing channel mat
    elseif ~isempty(ChannelMat) && ~isempty(ChannelMatData) && ~isequal({ChannelMat.Channel.Name}, {ChannelMatData.Channel.Name})
        % Get list of channels in the format of the existing channel file 
        DataMatReorder = DataMat;
        DataMatReorder.F = zeros(length(ChannelMat.Channel), size(DataMat.F,2));
        DataMatReorder.ChannelFlag = -1 * ones(length(ChannelMat.Channel),1);
        for i = 1:length(ChannelMat.Channel)
            iCh = find(strcmpi(ChannelMat.Channel(i).Name, {ChannelMatData.Channel.Name}));
            % If the channel is not found: try a different convention if it is a bipolar channel
            if isempty(iCh) && any(ChannelMat.Channel(i).Name == '-')
                iDash = find(ChannelMat.Channel(i).Name == '-',1);
                chNameBip = [ChannelMat.Channel(i).Name(iDash+1:end), ChannelMat.Channel(i).Name(1:iDash-1)];
                iCh = find(strcmpi(chNameBip, {ChannelMatData.Channel.Name}));
            end
            if ~isempty(iCh)
                DataMatReorder.F(i,:) = DataMat.F(iCh,:);
                DataMatReorder.ChannelFlag(i) = DataMat.ChannelFlag(iCh);
            end
        end
        DataMat = DataMatReorder;
        % Empty the channel file matrix, so it is not saved in the destination folder
        ChannelMat = [];
    end
    
    % ===== SAVE DATA MATRIX IN BRAINSTORM FORMAT =====
    % Get imported base name
    importedBaseName = strrep(fileBase, 'data_', '');
    importedBaseName = strrep(importedBaseName, '_data', '');
    % Process all the DataMat structures that were created
    ImportedData = repmat(db_template('Data'), [1, length(DataMat)]);
    for iData = 1:length(DataMat)
        % If subject name and condition were specified in the low-level import function
        if isfield(DataMat, 'SubjectName') && ~isempty(DataMat(iData).SubjectName) && isfield(DataMat, 'Condition') && ~isempty(DataMat(iData).Condition)
            newFileName = [importedBaseName '___SUBJ' DataMat(iData).SubjectName '___COND' DataMat(iData).Condition, '___'];
        else
            newFileName = importedBaseName;
        end
        % Produce a default data filename          
        BstDataFile = bst_fullfile(tmpDir, ['data_' newFileName '.mat']);
        BstDataFile = file_unique(BstDataFile);
        
        % Add History: File name
        FileMat = DataMat(iData); 
        FileMat = bst_history('add', FileMat, 'import', ['Import from: ' DataFile ' (Format: ' FileFormat ')']);
        FileMat.DataType = 'recordings';
        % Save new MRI in Brainstorm format
        bst_save(BstDataFile, FileMat, 'v6');
        
        % Create returned data structure
        ImportedData(iData).FileName = BstDataFile;
        % Add a Comment field (from DataMat if possible)
        if isfield(DataMat(iData), 'Comment') && ~isempty(DataMat(iData).Comment)
            ImportedData(iData).Comment = DataMat(iData).Comment;
        else
            DataMat(iData).Comment = [fileBase ' (' FileFormat ')'];
        end
        ImportedData(iData).DataType = FileMat.DataType;
        ImportedData(iData).BadTrial = 0;
        % Count number of time points
        nTime(iData) = length(FileMat.Time);
        nChannels = size(FileMat.F,1);
    end
end


%% ===== CHANNEL FILE =====
% Add history field to channel structure
if ~isempty(ChannelMat)
    ChannelMat = bst_history('add', ChannelMat, 'import', ['Import from: ' DataFile ' (Format: ' FileFormat ')']);
end




