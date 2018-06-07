function [sFile, ChannelMat] = in_fopen_nicolet(DataFile)
% IN_FOPEN_NICOLET: Open a Nicolet .e file

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
% Authors: Francois Tadel, 2017-2018


%% ===== READ HEADER =====
% Read Nicolet file
hdr.obj = NicoletFile(DataFile);
% Check the number of segments
hdr.nSegments = length(hdr.obj.segments);
if (hdr.nSegments > 1)
    % Multiple segments are read as one
    if ~all(cellfun(@(c)isequal(hdr.obj.segments(1).chName, c), {hdr.obj.segments(2:end).chName})) || ~all(cellfun(@(c)isequal(hdr.obj.segments(1).samplingRate, c), {hdr.obj.segments(2:end).samplingRate}))
        error('Nicolet files with multiple segments must have a constant list of channels.');
    end
end
% Read only the channels with the maximum sampling frequency
sfreq = max(hdr.obj.segments(1).samplingRate);
hdr.selchan = find(hdr.obj.segments(1).samplingRate == sfreq);
hdr.numchan = length(hdr.selchan);
% Display message to display ignored channels
iIgnored = setdiff(1:length(hdr.obj.segments(1).samplingRate), hdr.selchan);
if ~isempty(iIgnored)
    fprintf(1, 'NICOLET> Warning: The following channels were ignored because they have a lower sampling rate: ');
    for i = 1:length(iIgnored)
        fprintf(1, '%s ', str_clean(hdr.obj.segments(1).chName{iIgnored(i)}));
    end
    fprintf(1, '\n');
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = 'n';
sFile.filename     = DataFile;
sFile.format       = 'EEG-NICOLET';
sFile.prop.sfreq   = sfreq;
sFile.channelflag  = ones(hdr.numchan,1);
sFile.device       = 'Nicolet';
sFile.header       = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Acquisition date
sFile.acq_date = datestr(datenum(hdr.obj.segments.startDate), 'dd-mmm-yyyy');

% Multiple segments
if (hdr.nSegments > 1)
    for i = 1:hdr.nSegments
        sFile.epochs(i).label   = sprintf('Segment #%d', i);
        sFile.epochs(i).samples = [0, sfreq * hdr.obj.segments(i).duration - 1];
        sFile.epochs(i).times   = sFile.epochs(i).samples ./ sfreq;
        sFile.epochs(i).nAvg    = 1;
        sFile.epochs(i).select  = 1;
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
end
sFile.prop.samples = [0, sfreq * max([hdr.obj.segments.duration]) - 1];
sFile.prop.times   = sFile.prop.samples ./ sfreq;
sFile.prop.nAvg    = 1;


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.numchan]);
% For each channel
for i = 1:length(hdr.selchan)
    ChannelMat.Channel(i).Type = 'EEG';
    ChannelMat.Channel(i).Name = strrep(str_clean(hdr.obj.segments(1).chName{hdr.selchan(i)}), ' ', '');
    ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, '-Ref', '');
    ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, '-ref', '');
    ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, '-REF', '');
    strRef = str_clean(hdr.obj.segments(1).refName{hdr.selchan(i)});
    if ~isempty(strRef)
        ChannelMat.Channel(i).Comment = ['Reference: ', strRef];
    end
end


%% ===== FORMAT EVENTS =====
% Get user and event ID
allUser = {hdr.obj.eventMarkers.user};
allId   = {hdr.obj.eventMarkers.IDStr};
allEvt  = cell(size(allUser));
% Generate event names
for i = 1:length(allEvt)
    if isempty(allUser{i}) && (strcmpi(allId{i}, 'UNKNOWN') || isempty(allId{i}))
        allEvt{i} = 'UNKNOWN';
    elseif strcmpi(allId{i}, 'UNKNOWN')
        allEvt{i} = allUser{i};
    elseif isempty(allUser{i})
        allEvt{i} = allId{i};
    else
        allEvt{i} = [allUser{i} '-' allId{i}];
    end
end
% Get all the epochs names
uniqueEvt = unique(allEvt);
% Create one category for each event
for iEvt = 1:length(uniqueEvt)
    % Create event structure
    sFile.events(iEvt).label   = uniqueEvt{iEvt};
    sFile.events(iEvt).times   = [];
    sFile.events(iEvt).samples = [];
    sFile.events(iEvt).epochs  = [];
    sFile.events(iEvt).select  = 1;
    % Get all the occurrences
    iOcc = find(strcmpi(allEvt, uniqueEvt{iEvt}));
    % Process segments sequentially
    for iEpoch = 1:hdr.nSegments
        % Get events for this segment
        if (hdr.nSegments == 1)
            iEvtEpoch = 1:length(hdr.obj.eventMarkers(iOcc));
        elseif (iEpoch < hdr.nSegments)
            iEvtEpoch = find(([hdr.obj.eventMarkers(iOcc).dateOLE] >= hdr.obj.segments(iEpoch).dateOLE) & ([hdr.obj.eventMarkers(iOcc).dateOLE] < hdr.obj.segments(iEpoch+1).dateOLE));
        else
            iEvtEpoch = find([hdr.obj.eventMarkers(iOcc).dateOLE] >= hdr.obj.segments(iEpoch).dateOLE);
        end
        if isempty(iEvtEpoch)
            continue;
        end
        % Create full list of event times
        allTime = sort(([hdr.obj.eventMarkers(iOcc(iEvtEpoch)).dateOLE] - hdr.obj.segments(iEpoch).dateOLE) * 3600 * 24 + [hdr.obj.eventMarkers(iOcc(iEvtEpoch)).dateFraction]);
        % Add to all the events
        sFile.events(iEvt).times   = [sFile.events(iEvt).times,   allTime];
        sFile.events(iEvt).samples = [sFile.events(iEvt).samples, allTime .* sFile.prop.sfreq];
        sFile.events(iEvt).epochs  = [sFile.events(iEvt).epochs,  iEpoch * ones(size(allTime))];
    end
end


end



%% ===== CLEAN STRINGS =====
function s = str_clean(s)
    % Stop string at first termination
    iNull = find(s == 0, 1);
    if ~isempty(iNull)
        s(iNull:end) = [];
    end
    % Remove weird characters
    s(~ismember(s, '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-.()[]/\_@ ')) = [];
    % Remove useless spaces
    s = strtrim(s);
end


