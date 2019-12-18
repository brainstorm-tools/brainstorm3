function [sFile, ChannelMat] = in_fopen_eeglab(DataFile, ImportOptions)
% IN_FOPEN_EEGLAB: Open an EEGLAB .set file (continuous recordings).
%
% FORMAT:
%     EEGLAB datasets can have two forms : one file (.SET) or two files (.SET/.DAT).
%     In both cases, .SET file is a Matlab matrix with the dataset header in 'EEG' field.
%         1) .SET      : Recordings are stored in the 'EEGDATA' field of the .SET matrix
%         2) .SET/.DAT : Recordings are stored in binary mode in a separate .DAT file,
%                        whose file name is stored in field 'EEG.datfile' of the .SET matrix.
%                        Format : [nbChan, nbTime*nbTrials] float32 binary matrix (Little-Endian)
%     Channel locations may be stored in the .SET file, in field 'EEG.chanlocs'

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
% Authors: Francois Tadel, 2008-2017

% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end


%% ===== READER HEADER =====
% Load .set file
if isstruct(DataFile)
    hdr = DataFile;
    DataFile = hdr.filename;
else
    hdr = load(DataFile, '-mat');
end
% Add some information
hdr.isRaw = isempty(hdr.EEG.epoch) && ~isempty(hdr.EEG.data);
nChannels = hdr.EEG.nbchan;
nTime     = hdr.EEG.pnts;
nEpochs   = hdr.EEG.trials;

% === GET TIME ===
if isfield(hdr.EEG, 'times') && ~isempty(hdr.EEG.times)
    hdr.Time = hdr.EEG.times ./ 1000;
elseif isfield(hdr.EEG, 'srate') && ~isempty(hdr.EEG.srate)
    hdr.Time = hdr.EEG.xmin + (0:nTime-1) ./ hdr.EEG.srate;
else
    hdr.Time = linspace(hdr.EEG.xmin, hdr.EEG.xmax, nTime);
end

% ===== LIST BAD TRIALS =====
if ~hdr.isRaw
    % Get accepted/rejected trials (with methods ICA, SIG, ELEC)
    iRejectedTrials = [];
    if isfield(hdr.EEG, 'reject')
        % Epochs rejected by ICA criteria
        if isfield(hdr.EEG.reject, 'icareject')
            iRejectedTrials = [iRejectedTrials, hdr.EEG.reject.icareject];
        end
        % Epochs rejected by single-channel criteria
        if isfield(hdr.EEG.reject, 'sigreject')
            iRejectedTrials = [iRejectedTrials, hdr.EEG.reject.sigreject];
        end
        % Epochs rejected by single-channel criteria
        if isfield(hdr.EEG.reject, 'elecreject')
            iRejectedTrials = [iRejectedTrials, hdr.EEG.reject.elecreject];
        end
    end
    iGoodTrials = setdiff(1:nEpochs, iRejectedTrials);

    % Remove trials that have at least one 'bad' value in its events list
    iBadTrials = [];
    if isfield(hdr.EEG.epoch(1), 'eventbad')
        for iTrial = 1:length(hdr.EEG.epoch)
            if (iscell(hdr.EEG.epoch(iTrial).eventbad) && any([hdr.EEG.epoch(iTrial).eventbad{:}])) || ...
               (~iscell(hdr.EEG.epoch(iTrial).eventbad) && hdr.EEG.epoch(iTrial).eventbad) 
                iBadTrials(end+1) = iTrial;
            end
        end
        iGoodTrials = setdiff(iGoodTrials, iBadTrials);
    end
else
    iGoodTrials = 1;
end


% ===== GET RELEVANT CONDITIONS =====
epochNames = [];
isAllEmpty = 1;
if ~hdr.isRaw && isfield(hdr.EEG, 'event') && ~isempty(hdr.EEG.event)
    % Each trial is classified with many criteria
    % Need to ask the user along which creteria the trials should be classified
    % Get all fields of the 'event' structure
    listParam = fieldnames(hdr.EEG.event(1));
    % Remove entries that are not conditions of the events
    %listParam = setdiff(listParam, {'type','latency','urevent','obs','bad','badChan','epoch'});
    listParam = setdiff(listParam, {'urevent','obs','bad','badChan','epoch'});
    % Convert all the events to strings
    for iParam = 1:length(listParam)
        hdr.EEG.event = ConvertEventToStr(hdr.EEG.event, listParam{iParam});
        hdr.EEG.epoch = ConvertEventToStr(hdr.EEG.epoch, ['event' listParam{iParam}]);
    end
    % Keep only parameters for which the value varies in the valid trials
    iParam = 1;
    paramValues = {};
    while (iParam <= length(listParam))
        % Get all the unique values
        tmpValues = {hdr.EEG.event.(listParam{iParam})};
        % If char and not all the values are the same
%         if ~iscell(tmpValues{1}) && ~all(cellfun(@(c)isequal(c,tmpValues{1}), tmpValues))
        if ischar(tmpValues{1}) && ~all(cellfun(@(c)isequal(c,tmpValues{1}), tmpValues))
            % Latency: keep the native order
            if isequal(listParam{iParam}, 'latency')
                [tmp,I,J] = unique(tmpValues);
                paramValues{end + 1} = tmpValues(sort(I));
            % Else: sort in alphabetical/numerical order
            else
                paramValues{end + 1} = unique(tmpValues);
            end
            iParam = iParam + 1;
        % Else remove parameter 
        else
            listParam(iParam) = [];
        end
    end

    % If there are different types of events that can be used to classify the epochs
    if (length(listParam) >= 1) && (ImportOptions.DisplayMessages || ~isempty(ImportOptions.EventsTypes))
        % Ask the user to select the parameters to be compared
        if ImportOptions.DisplayMessages
            ParamSelected = gui_show_dialog('Conditions selection', @panel_eeglab_cond, 1, [], listParam, paramValues);
        % Use the list of event types passed in input
        else
            % Get the list of parameters in input
            evtSplit = strtrim(str_split(ImportOptions.EventsTypes, ','));
            % Check that the types are available in the file
            iNotFound = find(~ismember(evtSplit, listParam));
            if ~isempty(iNotFound)
                disp(['BST> Error: Some of the event types in input where not found in the file: ', sprintf('%s ', evtSplit{iNotFound})]);
                evtSplit(iNotFound) = [];
            end
            % Get the condition name for each epoch
            ParamSelected = [];
            if ~isempty(evtSplit)
                % Find the selected event types
                [tmp, I, J] = intersect(evtSplit, listParam);
                % Get the possible combinations of values
                ParamSelected = panel_eeglab_cond('GetConditionCombinations', listParam(J), paramValues(J));
                params = listParam(J);
                % Build the condition name for each epoch (see panel_eeglab_cond.m)
                for iCond = 1:length(ParamSelected)
                    strCondName = '';
                    for iParam = 1:length(params)
                        if (iParam ~= 1)
                            strCondName = [strCondName '_'];
                        end
                        if ischar(ParamSelected(iCond).(params{iParam}))
                            tmpStr = strrep(file_standardize(ParamSelected(iCond).(params{iParam})), '_', '-');
                            strCondName  = [strCondName, params{iParam}, tmpStr];
                        else
                            strCondName  = [strCondName, params{iParam}, sprintf('%d', ParamSelected(iCond).(params{iParam}))];
                        end
                    end
                    ParamSelected(iCond).Name = file_standardize(strCondName);
                end
            end
        end
        % Build the epochs names
        epochNames = cell(1, nEpochs);
        % Process parameters selection
        if ~isempty(ParamSelected)
            paramsList = setdiff(fieldnames(ParamSelected), 'Name');
            % Create FileName in which this file should be saved
            for iTrial = 1:nEpochs
                epoch = hdr.EEG.epoch(iTrial);
                % Find in which condition should be classified this epoch
                isCondFound = 0;
                iCond = 1;
                while ~isCondFound && (iCond <= length(ParamSelected))
                    isOk = 1;
                    iParam = 1;
                    while (isOk && (iParam <= length(paramsList)))
                        % If value for targ parameter does not match
                        if isequal(paramsList{iParam}, 'latency')
                            isMatch = isequal(hdr.EEG.event(epoch.event(1)).latency, ParamSelected(iCond).(paramsList{iParam}));
                        elseif iscell(epoch.(['event', paramsList{iParam}]))
                            isMatch = any(cellfun(@(c)isequal(c,ParamSelected(iCond).(paramsList{iParam})), epoch.(['event', paramsList{iParam}])));
                        else
                            isMatch = isequal(epoch.(['event', paramsList{iParam}]), ParamSelected(iCond).(paramsList{iParam}));
                        end
                        if isMatch
                            iParam = iParam + 1;
                        else
                            isOk = 0;
                        end
                    end
                    if isOk
                        isCondFound = 1;
                    else
                        iCond = iCond + 1;
                    end
                end
                % Build new filename with the found condition
                if isCondFound
                    epochNames{iTrial} = ParamSelected(iCond).Name;
                else
                    epochNames{iTrial} = '';
                end
            end
            isAllEmpty = all(cellfun(@isempty, epochNames));
        % If no parameters were selected
        else
            epochNames = repmat({''}, 1, nEpochs);
            isAllEmpty = 1;
        end
    end
end


%% ===== GET DATA SOURCE =====
% EEG.data
if isfield(hdr.EEG, 'data') && ~isempty(hdr.EEG.data)
    if isfield(hdr, hdr.EEG.data)
        EEGDATA = hdr.(hdr.EEG.data);
    else
        EEGDATA = hdr.EEG.data;
    end
% EEGDATA
elseif isfield(hdr, 'EEGDATA') && ~isempty(hdr.EEGDATA)
    EEGDATA = hdr.EEGDATA;
% EEGDATA.datfile
elseif isfield(hdr.EEG, 'datfile') && ~isempty(hdr.EEG.datfile)
    EEGDATA = hdr.EEG.datfile;
% Default data file: use the same file name than for .SET file, with .DAT/.FDT extension
else
    [fPath, fBase, fExt] = bst_fileparts(DataFile);
    EEGDATA = bst_fullfile(fPath, [fBase, '.dat']);
    if ~file_exist(EEGDATA)
        EEGDATA = bst_fullfile(fPath, [fBase, '.fdt']);
    end
end
% In case of attached binary file
if ischar(EEGDATA) 
    % Check binary file existence
    if ~file_exist(EEGDATA)
        % Try with the same name as the .set file
        if file_exist(strrep(DataFile, '.set', '.fdt'))
            EEGDATA = strrep(DataFile, '.set', '.fdt');
        else
            % Try with adding a full path
            [fPath, fBase, fExt] = bst_fileparts(EEGDATA);
            EEGDATA = bst_fullfile(bst_fileparts(DataFile), [fBase, fExt]);
            % File is not accessible
            if ~file_exist(EEGDATA)
                error(['EEGLAB binary file does not exist: ', EEGDATA]);
            end
        end
    end
    % Save correct filename
    hdr.EEG.data = EEGDATA;
    % Remove EEGDATA field
    if isfield(hdr, 'EEGDATA')
        hdr = rmfield(hdr, 'EEGDATA');
    end
else
    hdr.EEGDATA = EEGDATA;
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure                    
sFile = db_template('sfile');                     
% Add information read from header
sFile.filename   = DataFile;
sFile.fid        = [];  
sFile.format     = 'EEG-EEGLAB';
sFile.device     = 'EEGLAB';
sFile.byteorder  = 'l';
% Properties of the recordings
sFile.prop.times = [hdr.Time(1), hdr.Time(end)];
sFile.prop.sfreq = 1 ./ (hdr.Time(2) - hdr.Time(1));
sFile.prop.nAvg  = 1;
sFile.header = hdr;
% Channel file
if ImportOptions.DisplayMessages
    isFixUnits = [];
elseif (ImportOptions.ChannelAlign >= 1)
    isFixUnits = 1;
else
    isFixUnits = 0;
end
ChannelMat = in_channel_eeglab_set(hdr, isFixUnits);

% === EPOCHS ===
for i = 1:nEpochs
    if ~isempty(epochNames) && ~isempty(epochNames{i})
        sFile.epochs(i).label = epochNames{i};
        sFile.epochs(i).select  = 1;
    elseif isAllEmpty
        sFile.epochs(i).label = sprintf('%s (#%d)', hdr.EEG.setname, i);
        sFile.epochs(i).select  = 1;
    else
        sFile.epochs(i).select  = 0;
    end
    sFile.epochs(i).times   = sFile.prop.times;
    sFile.epochs(i).nAvg    = 1;
    sFile.epochs(i).bad     = ~ismember(i, iGoodTrials);
    % Bad channels
    sFile.epochs(i).channelflag = ones(nChannels, 1);
    if ~hdr.isRaw && isfield(hdr.EEG, 'epoch') && ~isempty(hdr.EEG.epoch) && isfield(hdr.EEG.epoch(1), 'eventbadChan')
        % Get all the bad channels for that epoch
        eventbadChan = hdr.EEG.epoch(iTrial).eventbadChan;
        if iscell(eventbadChan)
            iBadChan = [];
            for j = 1:length(eventbadChan)
                if ~isempty(eventbadChan{j})
                    iBadChan = [iBadChan, str2num(eventbadChan{j})];
                end
            end
        else
            iBadChan = str2num(eventbadChan);
        end
        % Report the bad channels in the ChannelFlag array
        sFile.epochs(i).channelflag(iBadChan) = -1;
    end
end
% Global channel flag
if (nEpochs == 1)
    sFile.channelflag = sFile.epochs(1).channelflag;
    sFile.epochs = [];
else
    sFile.channelflag = ones(nChannels, 1);
end

% === EVENTS ====
if isfield(hdr.EEG, 'event') && ~isempty(hdr.EEG.event) && isfield(hdr.EEG.event, 'type') % && hdr.isRaw
    % Get event types
    intTypes = [];
    if ischar(hdr.EEG.event(1).type)
        listTypes = unique({hdr.EEG.event.type});
    elseif isnumeric(hdr.EEG.event(1).type)
        intTypes = unique([hdr.EEG.event.type]);
        listTypes = cell(1, length(intTypes));
        for iType = 1:length(intTypes)
            listTypes{iType} = num2str(intTypes(iType));
        end
    else
        return;
    end
    % Initialize structure
    events = repmat(db_template('event'), [1, length(listTypes)]);
    % Process each event type
    for iEvt = 1:length(listTypes)       
        % Get all the event occurrences
        if ~isempty(intTypes)
            listOcc = find([hdr.EEG.event.type] == intTypes(iEvt));
        else
            listOcc = find(strcmpi({hdr.EEG.event.type}, listTypes{iEvt}));
        end
        % Get event label 
        events(iEvt).label = listTypes{iEvt};
        % If no occurrences: skip
        if isempty(listOcc)
            continue;
        end
        % Get epochs indices
        if ~hdr.isRaw && (isfield(hdr.EEG.event(listOcc(1)), 'epoch') && ~isempty(hdr.EEG.event(listOcc(1)).epoch))
            events(iEvt).epochs = [hdr.EEG.event(listOcc).epoch];
        else
            events(iEvt).epochs = ones(1, length(listOcc));
        end
        % Get samples
        if isfield(hdr.EEG.event(listOcc(1)), 'latency')
            allSmp = {hdr.EEG.event(listOcc).latency};
        elseif isfield(hdr.EEG.event(listOcc(1)), 'sample')
            allSmp = {hdr.EEG.event(listOcc).sample};
        else
            disp(['EEGLAB> Missing fields "latency" or "sample" in event "', hdr.EEG.event(listOcc(1)).type, '".']);
        end
        % Convert to values if available as strings
        iChar = find(cellfun(@ischar, allSmp));
        if ~isempty(iChar)
            allSmp(iChar) = cellfun(@str2num, allSmp(iChar), 'UniformOutput', 0);
        end
        % Remove empty latencies
        iEmpty = find(cellfun(@isempty, allSmp));
        if ~isempty(iEmpty)
            [allSmp{iEmpty}] = deal(1);
        end
        samples = round([allSmp{:}]);
        % Add durations if there are more than one sample
        if isfield(hdr.EEG.event(listOcc), 'duration') && ~ischar(hdr.EEG.event(listOcc(1)).duration)
            allDur = [hdr.EEG.event(listOcc).duration];
            if any(allDur > 1) && (length(samples) == length(allDur))
                samples(2,:) = samples + allDur; 
            end
        end
        % For epoched files: convert events to samples local to each epoch 
        if ~hdr.isRaw
            nSamples = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq) + 1;
            samples = samples - (events(iEvt).epochs - 1) * nSamples + sFile.prop.times(1) * sFile.prop.sfreq - 1;
        end
        % Compute times
        events(iEvt).times = samples ./ sFile.prop.sfreq;
        % Additional fields
        events(iEvt).channels = cell(1, size(events(iEvt).times, 2));
        events(iEvt).notes    = cell(1, size(events(iEvt).times, 2));
    end
    % Save structure
    sFile.events = events;
end

end


%% ===== CONVERT EVENTS TO STRING =====
function s = ConvertEventToStr(s, param)
    % For each event
    for i = 1:length(s)
        % Double values: convert to strings
        if isnumeric(s(i).(param))
            s(i).(param) = val2str(s(i).(param));
        % Cell array of doubles
        elseif iscell(s(i).(param))
            for iCell = 1:length(s(i).(param))
                if isnumeric(s(i).(param){iCell})
                    s(i).(param){iCell} = val2str(s(i).(param){iCell});
                end
            end
        end
    end
end

function str = val2str(val)
    str = '';
    for iVal = 1:length(val)
        if (str > 1)
            str = [str ' '];
        end
        str = [str, num2str(val(iVal))];
    end
end




