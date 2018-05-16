function [DataMat, ChannelMat] = in_data_muse_csv(DataFile, sfreq)
% IN_DATA_MUSE_CSV: Imports a Muse CSV file.
%
% USAGE: [DataMat, ChannelMat] = in_data_muse_csv(DataFile, sfreq=[ask]);

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2018


% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(sfreq)
    res = java_dialog('input', [...
        'Muse recordings may have an irregular sampling rate with missing samples,' 10 ...
        'therefore they need to be reinterpolated on a fixed time grid in order to' 10 ...
        'be imported and processed in Brainstorm.' 10 10 ...
        'Enter sampling rate:'], 'Import Muse EEG', [], '500');
    if isempty(res) || isempty(str2num(res)) || (str2num(res) <= 0)
        error('Invalid sampling rate.')
    end
    sfreq = str2num(res);
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
% Split labels
Labels = strtrim(str_split(Labels, ','));
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
% Read the rest of the file
RecMat = textscan(fid, strFormat, 'Delimiter', ',');
% Close file
fclose(fid);
% Check for errors
if isempty(RecMat) || isempty(RecMat{1})
    error('File is could not be read as CSV.');
end


% ===== CONVERT TIMESTAMPS TO TIME =====
bst_progress('text', 'Processing time stamps...');
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
iTimeEvt = find(isnan(rawF(1,:)));
% Get event timing
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


% ===== REINTERPOLATE =====
bst_progress('text', 'Inteprolating recordings...');
% Remove duplicated time points
uniqueTime = unique(rawTime);
if (length(uniqueTime) < length(rawTime))
    % Detect duplicates
    countTime = hist(rawTime, uniqueTime);
    iRepeated = find(countTime ~= 1);
    % Remove duplicates
    rawTime(iRepeated) = [];
    rawF(:,iRepeated) = [];
    % Dispay message
    disp(sprintf('BST> Muse: Removed %d time samples.', length(iRepeated)));
end
% Define time vector
Time = 0:1/sfreq:max(rawTime);
% Interpolate data
nChannels = size(rawF,1);
F = zeros(nChannels, length(Time));
for iChan = 1:nChannels
    F(iChan,:) = interp1(rawTime, rawF(iChan,:), Time);
end


% ===== BRAINSTORM DATA =====
% Get file name
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Create empty structure
DataMat = db_template('DataMat');
% Fill structure
DataMat.F           = F ./ 1000;
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
        DataMat.Events(iEvt).label   = strtrim(uniqueEvt{iEvt});
        DataMat.Events(iEvt).samples = unique(round(evtTime(iOcc) .* sfreq));
        DataMat.Events(iEvt).times   = DataMat.Events(iEvt).samples ./ sfreq;
        DataMat.Events(iEvt).epochs  = 1 + 0*DataMat.Events(iEvt).samples;
        DataMat.Events(iEvt).select  = 1;
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






