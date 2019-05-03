function [sFile, ChannelMat] = in_fopen_deltamed(DataFile)
% IN_FOPEN_DELTAMED: Open a Deltamed Coherence-Neurofile exported binary file.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_deltamed(DataFile)

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
% Authors: Francois Tadel, 2013-2018

%% ===== GET FILES =====
% Build header files names (.txt)
HdrFile = [DataFile(1:end-4) '.txt'];
if ~file_exist(HdrFile)
    error(['Could not find header file:' 10 HdrFile]);
end


%% ===== READ HEADER =====
hdr.event = repmat(struct('sample','name'), 0);
% Open and read file
fid = fopen(HdrFile,'r');
curBlock = '';
% Read file line by line
while 1
    % Read one line
    newLine = fgetl(fid);
    if ~ischar(newLine)
        break;
    end
    % Empty lines and comment lines: skip
    if isempty(newLine) || ismember(newLine(1), {';', char(10), char(13)})
        continue;
    end
    % Remove double-quotes
    newLine(newLine == '"') = [];
    % Read block names
    if (newLine(1) == '[')
        curBlock = newLine;
        curBlock(ismember(curBlock, '[] ')) = [];
        continue;
    end
    % Events block
    if strcmpi(curBlock, 'EVENT')
        % Split around the ','
        argLine = strtrim(str_split(newLine, ','));
        if (length(argLine) ~= 2) || isempty(argLine{1}) || isempty(argLine{2})
            continue;
        else
            iEvt = length(hdr.event)+1;
            hdr.event(iEvt).sample = str2double(argLine{1});
            hdr.event(iEvt).name   = file_standardize(argLine{2});
        end
    else
        % Skip non-attribution lines
        if ~any(newLine == '=')
            continue;
        end
        % Split around the '='
        argLine = strtrim(str_split(newLine, '='));
        if (length(argLine) ~= 2) || (length(argLine{1}) < 2) || isempty(argLine{2}) || ~isequal(argLine{1}, file_standardize(argLine{1}))
            continue;
        end
        % Parameter
        if ismember(argLine{1}, {'Sampling', 'FromSecond', 'ToSecond', 'DurationInSamples', 'DurationInSec', 'NbOfChannels', })
            hdr.(argLine{1}) = str2num(argLine{2});
        else
            hdr.(file_standardize(argLine{1})) = argLine{2};
        end
    end
end
% Close file
fclose(fid);
% Check file format
if (length(hdr.OutputFormat) < 3) || (~strcmpi(hdr.OutputFormat(1:3), 'bin') && ~strcmpi(hdr.OutputFormat(1:3), '&bi'))
    error('Only binary multiplexed files are supported, please export again your files in the appropriate format.');
end


%% ===== DECODING SOME INFORMATION =====
% Splitting channel names
hdr.chnames = str_split(hdr.Channels, ',');
strGain = str_split(hdr.Gainx1000, ',');
% Create gain vector
hdr.chgain = ones(1, hdr.NbOfChannels);
for i = 1:hdr.NbOfChannels
    if (i <= length(strGain)) && ~isempty(strGain{i})
        hdr.chgain(i) = str2double(strGain{i}) * 1e-3 .* 1e-6;
    end
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-DELTAMED';
sFile.device     = 'DELTAMED';
sFile.header     = hdr;
% Comment: short filename
[tmp__, sFile.comment, tmp__] = bst_fileparts(DataFile);
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = hdr.Sampling;
sFile.prop.samples = [0, hdr.DurationInSamples - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.NbOfChannels, 1);
% Acquisition date
sFile.acq_date = str_date(hdr.Date);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Deltamed channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.NbOfChannels]);
% For each channel
for i = 1:hdr.NbOfChannels
    if (i <= length(hdr.chnames)) && ~isempty(hdr.chnames{i})
        ChannelMat.Channel(i).Name = hdr.chnames{i};
    else
        ChannelMat.Channel(i).Name = sprintf('E%d', i);
    end
    ChannelMat.Channel(i).Loc = [0; 0; 0];
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end


%% ===== FORMAT EVENTS =====
if ~isempty(hdr.event)
    % Get list of events
    allNames = {hdr.event.name};
    [uniqueEvt, iUnique] = unique(allNames);
    uniqueEvt = allNames(sort(iUnique));
    % Initialize list of events
    events = repmat(db_template('event'), 1, length(uniqueEvt));
    % Format list
    for iEvt = 1:length(uniqueEvt)
        % Ask for a label
        events(iEvt).label      = uniqueEvt{iEvt};
        events(iEvt).color      = [];
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        % Find list of occurences of this event
        iOcc = find(strcmpi(allNames, uniqueEvt{iEvt}));
        % Get time and samples
        events(iEvt).samples = [hdr.event(iOcc).sample];
        events(iEvt).times   = events(iEvt).samples ./ sFile.prop.sfreq;
        % Epoch: set as 1 for all the occurrences
        events(iEvt).epochs = ones(1, length(events(iEvt).samples));
    end
    % Import this list
    sFile = import_events(sFile, [], events);
end


