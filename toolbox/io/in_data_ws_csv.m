function [DataMat, ChannelMat] = in_data_ws_csv(DataFile)
% IN_DATA_WS_CSV: Imports a Wearable Sensing CSV file.

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
% Authors: Francois Tadel, 2019

% ===== READ CSV =====
bst_progress('text', 'Reading csv file...');
% Open file
fid = fopen(DataFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Read header line with channel names
Labels = [];
while 1
    csvLine = fgetl(fid);
    % End of file
    if (csvLine == -1)
        break;
    % Empty line
    elseif isempty(csvLine)
        continue;
    % Comment line
    elseif (csvLine(1) == '#')
        continue;
    % Header line with channel names
    elseif (nnz(csvLine == ',') > 0)
        Labels = strtrim(str_split(csvLine, ','));
        break;
    end
end
% Channel names not found
if isempty(Labels)
    fclose(fid);
    error('Header line with channel names not found in CSV.');
end
% Default reading pattern
cellFormat = repmat({'%f'}, 1, length(Labels));

% Final reading format for the rest of the file
strFormat = sprintf('%s ', cellFormat{:});
strFormat(end) = [];
% Read the rest of the file
RecMat = textscan(fid, strFormat, 'Delimiter', ',');
% Close file
fclose(fid);
% Check for errors
if isempty(RecMat) || isempty(RecMat{1})
    error('File could not be read as CSV.');
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

% ===== GET TIME =====
bst_progress('text', 'Processing time stamps...');
% Find timestamp
iTimestamp = find(strcmpi(Labels, 'Time'));
if isempty(iTimestamp)
    error('Missing time column.');
end
% Convert time stamps to datenum
rawTime = RecMat{iTimestamp}';
% Set t=0 at the first sample
rawTime = rawTime - rawTime(1);
% Detect sampling frequency
sfreq = 1./mean(diff(rawTime));
sfreq = round(sfreq * 100) ./ 100;
% Reconstructed file time
Time = (0:length(rawTime)-1) ./ sfreq;

% ===== GET DATA =====
bst_progress('text', 'Reconstructing data matrix...');
% Get other useless channels
iComments = find(strcmpi(Labels, 'Comments'));
% Find a column that has non-empty values that is not a special column
iColAll = setdiff(1:length(Labels), [iTimestamp, iComments]);
iColRec = iColAll(~cellfun(@(c)all(isnan(c)), RecMat(iColAll)));
% Rebuild data matrix
rawF = [RecMat{iColRec}]';
% Remove other missing values: replacing with values
iMissing = find(any(isnan(rawF),1));
if ~isempty(iMissing)
    disp(sprintf('BST> Muse: Missing data at %d time points. Replacing with zeros...', length(iMissing)));
    rawF(isnan(rawF)) = 0;
end
nChannels = size(rawF,1);


% % ===== DETECT EVENTS =====
% % Find events
% iTimeEvt = find(all(isnan(rawF),1));
% % Get event timing
% evtTime = rawTime(iTimeEvt);
% % Get event labels
% if ~isempty(iElements) && ~all(cellfun(@isempty, RecMat{iElements}(iTimeEvt)))
%     evtLabels = cellfun(@(c)strrep(c, '/muse/elements/', ''), RecMat{iElements}(iTimeEvt), 'UniformOutput', 0);
% else
%     evtLabels = repmat({'Trigger'}, length(iTimeEvt), 1);
% end
% Remove events from data matrix
% rawF(:,iTimeEvt) = [];
% rawTime(iTimeEvt) = [];


% ===== BRAINSTORM DATA =====
% Get file name
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Create empty structure
DataMat = db_template('DataMat');
% Fill structure
DataMat.F           = rawF .* 1e-6;  % Data stored in microV
DataMat.Time        = Time;
DataMat.Comment     = fBase;
DataMat.ChannelFlag = ones(nChannels, 1);
DataMat.nAvg        = 1;
DataMat.Device      = 'Wearable Sensing';
% % Add events
% if ~isempty(iTimeEvt)
%     % Initialize events list
%     DataMat.Events = repmat(db_template('event'), 0);
%     % Events list
%     uniqueEvt = unique(evtLabels);
%     % Build events list
%     for iEvt = 1:length(uniqueEvt)
%         % Find all the occurrences of this event
%         iOcc = find(strcmpi(uniqueEvt{iEvt}, evtLabels));
%         % Set event
%         DataMat.Events(iEvt).label    = strtrim(uniqueEvt{iEvt});
%         DataMat.Events(iEvt).times    = unique(round(evtTime(iOcc) .* sfreq)) ./ sfreq;
%         DataMat.Events(iEvt).epochs   = 1 + 0*DataMat.Events(iEvt).times;
%         DataMat.Events(iEvt).select   = 1;
%         DataMat.Events(iEvt).channels = [];
%         DataMat.Events(iEvt).notes    = [];
%     end
% end


% ===== CHANNEL FILE =====
ChannelMat = db_template('channelmat');
for i = 1:nChannels
    % Split type/name
    ch = Labels{iColAll(i)};
    ChannelMat.Channel(i).Name = ch;
    switch (ch)
        case 'Trigger'
            ChannelMat.Channel(i).Type = 'Trigger';
        case 'Event'
            ChannelMat.Channel(i).Type = 'Event';
        case 'Time_Offset'
            ChannelMat.Channel(i).Type = 'Time_Offset';
        case 'CM'
            ChannelMat.Channel(i).Type = 'CM';
        case {'ADC_Status', 'ADC_Sequence'}
            ChannelMat.Channel(i).Type = 'Trigger';
        otherwise
            ChannelMat.Channel(i).Type = 'EEG';
    end
    ChannelMat.Channel(i).Loc     = [];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Comment = '';
    ChannelMat.Channel(i).Weight  = 1;
end






