function [DataMat, ChannelMat] = in_data_muse_csv(DataFile, sfreq, isInteractive)
% IN_DATA_MUSE_CSV: Imports a Muse CSV file.
%
% Muse file format specification:
% http://developer.choosemuse.com/tools/windows-tools/available-data-muse-direct
%    
% USAGE: [DataMat, ChannelMat] = in_data_muse_csv(DataFile, sfreq=[ask], isInteractive=0);

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
% Authors: Francois Tadel, 2018-2021


% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 0;
end
if (nargin < 2) || isempty(sfreq)
    sfreq = [];
end

% ===== READ CSV =====
bst_progress('text', 'Reading csv file...');
% Open file
fid = fopen(DataFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Read header line
Labels = fgetl(fid);
% Detect type of separator (, or ;)
if (nnz(Labels == ';') > nnz(Labels == ','))
    disp('BST> Muse: Using ";" as a separator instead of ",".');
    colSeparator = ';';
else
    colSeparator = ',';
end
% Split labels
Labels = strtrim(str_split(Labels, colSeparator));
% Default reading pattern
cellFormat = repmat({'%f'}, 1, length(Labels));
% Find timestamp
iTimestamp = find(strcmpi(Labels, 'TimeStamp'));
if ~isempty(iTimestamp)
    cellFormat{iTimestamp} = '%s';
else
    fclose(fid);
    error('Timestamp column not found in Muse csv.');
end

% Find elements
iElements = find(strcmpi(Labels, 'Elements'));
if ~isempty(iElements)
    cellFormat{iElements} = '%s';
end
% Final reading format for the rest of the file
strFormat = sprintf('%s ', cellFormat{:});
strFormat(end) = [];
% When using the ";" as a separator, some "," might be used instead of "."
if (colSeparator == ';')
    % Read the rest of the file as plain text
    RecMat = fread(fid, [1, Inf], '*char');
    % Replace all commas "," with dots "." in the values
    RecMat(RecMat == ',') = '.';
    % Parse the fixed string
    RecMat = textscan(RecMat, strFormat, 'Delimiter', colSeparator, 'TreatAsEmpty', '#NOM?');
else
    % Read the rest of the file
    RecMat = textscan(fid, strFormat, 'Delimiter', colSeparator, 'TreatAsEmpty', '#NOM?');
end
% Close file
fclose(fid);
% Check for errors
if isempty(RecMat) || isempty(RecMat{1})
    error('File is could not be read as CSV.');
end
% If the last line is incomplete: delete it
lastFullRow = length(RecMat{end});
if (length(RecMat{1}) > lastFullRow)
    for i = 1:length(RecMat)
        if (length(RecMat{i}) > lastFullRow)
            RecMat{i} = RecMat{i}(1:lastFullRow);
        end
    end
end


% ===== CONVERT TIMESTAMPS TO TIME =====
bst_progress('text', 'Processing time stamps...');
% Remove the empty timestamps
iNoTime = find(cellfun(@isempty, RecMat{iTimestamp}));
if ~isempty(iNoTime)
    for i = 1:length(RecMat)
        RecMat{i}(iNoTime) = [];
    end
end
% Convert time stamps to datenum
rawTime = datenum(RecMat{iTimestamp})';
% Set t=0 at the first sample
rawTime = rawTime - rawTime(1);
% Convert to seconds
rawTime = rawTime * 86400;


% ===== DETECT EVENTS =====
bst_progress('text', 'Reconstructing data matrix...');
% Find a column that has non-empty values that is not a special column
iColAll = setdiff(1:length(Labels), [iTimestamp, iElements]);
iColRec = iColAll(~cellfun(@(c)all(isnan(c)), RecMat(iColAll)));
% Rebuild data matrix
rawF = [RecMat{iColRec}]';
% Find events
iTimeEvt = find(all(isnan(rawF),1));
% Event times: From the timestamps
evtTime = rawTime(iTimeEvt);
% Get event labels
if ~isempty(iElements) && ~all(cellfun(@isempty, RecMat{iElements}(iTimeEvt)))
    evtLabels = cellfun(@(c)strrep(c, '/muse/elements/', ''), RecMat{iElements}(iTimeEvt), 'UniformOutput', 0);
else
    evtLabels = repmat({'Trigger'}, length(iTimeEvt), 1);
end
% Remove events from data matrix
rawF(:,iTimeEvt) = [];
rawTime(iTimeEvt) = [];
% Remove other missing values: replacing with values
iMissing = find(any(isnan(rawF),1));
if ~isempty(iMissing)
    disp(sprintf('BST> Muse: Missing data at %d time points. Replacing with zeros...', length(iMissing)));
    rawF(isnan(rawF)) = 0;
end
nChannels = size(rawF,1);


% ===== ASK SAMPLING FREQUENCY =====
if isempty(sfreq)
    sfreq_all = 1 ./ diff(rawTime);
    sfreq_all(isinf(sfreq_all)) = [];
    sfreq_all(isnan(sfreq_all)) = [];
    sfreq_mean = mean(sfreq_all);
    sfreq_std = std(sfreq_all);
    % Regular sampling in CSV
    if (sfreq_std < 0.01)
       sfreq = sfreq_mean;
       isResample = 0;
    % If not in interactive mode: error
    elseif ~isInteractive
        errMsg = 'This dataset must be imported in interactive mode to select the sampling rate.';
        disp(['BST> Error: ' errMsg]);
        error(errMsg);
    % Irregular sampling in CSV
    else
        res = java_dialog('question', sprintf([...
            '<HTML>The timestamps are irregular (%1.3f +/- %1.3f Hz) and<BR>' ...
            'cannot be used in Brainstorm as is. Two options are available:<BR><BR>' ...
            '<B>Resample</B>:<BR>' ...
            '- Trust the timestamps from the .csv<BR>' ...
            '- Re-interpolate the signals on a regular time vector<BR>' ...
            '- Events latencies are based on their timestamps<BR><BR>' ...
            '<B>Ignore</B>:<BR>' ...
            '- Do not trust the timestamps: ignore them completely<BR>' ...
            '- Trust the Muse sampling regularity: do not re-interpolate signals<BR>' ...
            '- Events latencies are based on their positions in the data files<BR><BR>'], sfreq_mean, sfreq_std), ...
            'Import Muse EEG', [], {'Resample', 'Ignore', 'Cancel'}, 'Ignore');
        if isempty(res) || strcmpi(res, 'Cancel')
            error('Import cancelled by user.');
        end
        isResample = strcmpi(res, 'Resample');
        % Ask sampling rate
        res = java_dialog('input', 'Enter sampling rate:', 'Import Muse EEG', [], '256');
        if isempty(res)
            error('Import cancelled by user.');
        elseif isempty(str2num(res)) || (str2num(res) <= 0)
            error('Invalid sampling rate.')
        end
        sfreq = str2num(res);
    end
else
    isResample = 0;
end


% ===== REINTERPOLATE =====
if isResample
    bst_progress('text', 'Inteprolating recordings...');
    % Remove duplicated time points
    [uniqueTime,iUnique] = unique(rawTime);
    if (length(uniqueTime) < length(rawTime))
        disp(sprintf('BST> Muse: Removed %d duplicated time samples.', length(rawTime) - length(uniqueTime)));
        rawTime = rawTime(iUnique);
        rawF = rawF(:,iUnique);
    end
    % Define time vector
    Time = 0:1/sfreq:max(rawTime);
    % Interpolate data
    F = zeros(nChannels, length(Time));
    for iChan = 1:nChannels
        F(iChan,:) = interp1(rawTime, rawF(iChan,:), Time);
    end
else
    Time = (0:(length(rawTime)-1)) ./ sfreq;
    F = rawF;
    % Fix timing indices to compensate for data points that were removed
    iTimeEvt = iTimeEvt - (0:length(iTimeEvt)-1);
    % Event times: From the data matrix
    evtTime = Time(iTimeEvt);
end


% ===== BRAINSTORM DATA =====
% Get file name
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Create empty structure
DataMat = db_template('DataMat');
% Fill structure
DataMat.F           = F .* 1e-6;  % Data stored in microV: http://developer.choosemuse.com/tools/windows-tools/available-data-muse-direct
DataMat.Time        = Time;
DataMat.Comment     = fBase;
DataMat.ChannelFlag = ones(nChannels, 1);
DataMat.nAvg        = 1;
DataMat.Device      = 'Muse';
% Add events
if ~isempty(iTimeEvt)
    % Initialize events list
    DataMat.Events = repmat(db_template('event'), 0);
    % Events list
    uniqueEvt = unique(evtLabels);
    % Build events list
    for iEvt = 1:length(uniqueEvt)
        % Find all the occurrences of this event
        iOcc = find(strcmpi(uniqueEvt{iEvt}, evtLabels));
        % Set event
        DataMat.Events(iEvt).label    = strtrim(uniqueEvt{iEvt});
        DataMat.Events(iEvt).times    = unique(round(evtTime(iOcc) .* sfreq)) ./ sfreq;
        DataMat.Events(iEvt).epochs   = 1 + 0*DataMat.Events(iEvt).times;
        DataMat.Events(iEvt).select   = 1;
    end
end


% ===== CHANNEL FILE =====
ChannelMat = db_template('channelmat');
for i = 1:nChannels
    % Split type/name
    ch = Labels{iColAll(i)};
    iUnder = find(ch == '_', 1);
    if ~isempty(iUnder)
        chType = ch(1:iUnder-1);
        if strcmpi(chType, 'RAW')
            ChannelMat.Channel(i).Type = 'EEG';
            ChannelMat.Channel(i).Name = ch(iUnder+1:end);
        elseif ismember(chType, {'Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'})
            ChannelMat.Channel(i).Type = 'EEG_POW';
            ChannelMat.Channel(i).Name = ch;
        else
            ChannelMat.Channel(i).Type = chType;
            ChannelMat.Channel(i).Name = ch;
        end
    else
        ChannelMat.Channel(i).Name = ch;
        switch (ch)
            case 'Battery',    ChannelMat.Channel(i).Type = 'Battery';
            case 'HeadBandOn', ChannelMat.Channel(i).Type = 'ON';
            otherwise,         ChannelMat.Channel(i).Type = 'Other';
        end
    end
    ChannelMat.Channel(i).Loc     = [];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Comment = '';
    ChannelMat.Channel(i).Weight  = 1;
end






