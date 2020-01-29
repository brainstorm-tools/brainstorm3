function [sFile, ChannelMat] = in_fopen_cnt(DataFile, ImportOptions)
% IN_FOPEN_CNT: Open a Neuroscan .cnt file (continuous recordings).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_cnt(DataFile, ImportOptions)
%         [sFile, ChannelMat] = in_fopen_cnt(DataFile)
%
% INPUTS:
%     - ImportOptions : Structure that describes how to import the recordings.
%       => Fields used: DisplayMessages

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
% Authors: Francois Tadel, 2009-2018
        
%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

%% ===== READ HEADER =====
% Read the header
hdr = neuroscan_read_header(DataFile, 'cnt');

% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-NEUROSCAN-CNT';
sFile.prop.sfreq = double(hdr.data.rate);
sFile.device     = 'Neuroscan';
sFile.header     = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Time and samples indices
sFile.prop.times = [0, hdr.data.numsamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
% Get bad channels
sFile.channelflag = ones(length(hdr.electloc),1);
sFile.channelflag([hdr.electloc.bad] == 1) = -1;
% Acquisition date
sFile.acq_date = str_date(char(hdr.data.date(:)'));


%% ===== EVENTS LIST =====   
% Convert events structure to Brainstorm format (grouped by type)
if ~isempty(hdr.events)
    % lastStim = 'Unknown';
    lastStim = '';
    lastStimTime = 0;
    
    % === SELECT EVENTS / RESPONSES ===
    selEvt = [];
    selResp = [];
    % Get the available events and responses
    availStim = setdiff(unique([hdr.events.stimtype]), 0);
    availResp = setdiff(unique([hdr.events.keyPad]), 0);
    availKey  = setdiff(unique([hdr.events.keyboard]), 0);
    % If some events AND some responses are available
    if ~ImportOptions.DisplayMessages
        % Keep everything
        selEvt = availStim;
        selResp = availResp;
    elseif ~isempty(availStim) && ~isempty(availResp) 
        % Ask the events and responses number to read
        res = java_dialog('input', {'Please enter stimulus events to import:', ...
                                    'Please enter responses to import:'}, ...
                                   'Select events', [], ...
                                   {deblank(sprintf('%d ', availStim)), ...
                                    deblank(sprintf('%d ', availResp))});
        % If user canceled: exit
        if isempty(res)
            sFile = [];
            ChannelMat = [];
            return;
        elseif (~isempty(res{1}) && isempty(str2num(res{1}))) || (~isempty(res{2}) && isempty(str2num(res{2})))
            error('Invalid selection.');
        end
        % Get selected events/responses
        selEvt  = str2num(res{1});
        selResp = str2num(res{2});
    % If some events are available but NO responses
    elseif ~isempty(availStim)
        % Select by default all events
        selEvt = availStim;
    % If some responses are available but NO events
    elseif ~isempty(availResp)
        % Select by default all events
        selResp = availResp;
    end
    % Get the selected events
    iSelEvt = ismember([hdr.events.stimtype], selEvt) | ismember([hdr.events.keyPad], selResp) | ismember([hdr.events.keyboard], availKey);
    Events = hdr.events(iSelEvt);

    % === MULTIPLE RESPONSES ===
    % Get the multiple responses
    iMultiResp = find((diff([1,Events.keyPad] ~= 0) == 0) & ([Events.keyPad] ~= 0));
    if ~isempty(iMultiResp)
        iMultiResp = unique([iMultiResp, iMultiResp - 1]);
        % Get stim with multiple responses
        iEvtMultiResp = intersect(iMultiResp - 1, find([Events.stimtype] ~= 0));
        % Get all the events that should be classified in "Multiple responses" category
        iMulti = unique([iMultiResp, iEvtMultiResp]);
    else
        iMulti = [];
    end
    % Defined comment tag for the multiple responses
    strTagMulti = 'Multi resp';
    iEvtGroupMulti = [];
    
    % === LOOP ON ALL EVENTS ===
    for i = 1:length(Events)
        select = 0;
        reactTime = 0;
        % Compute event time
        evtTime  = Events(i).iTime / sFile.prop.sfreq;
        stimType = Events(i).stimtype;
        keyPad   = Events(i).keyPad;
        % Build event name
        if (stimType ~= 0)
            evtLabel = sprintf('Stim %d', stimType);
            lastStim = evtLabel;     
            lastStimTime = evtTime;
            select = 1;
        elseif (keyPad ~= 0)
            evtLabel = sprintf('Response %d', keyPad);
            % Add previous stimulus name
            if ~isempty(lastStim)
                evtLabel = [lastStim ': ' evtLabel];
                reactTime = evtTime - lastStimTime;
            end
        elseif (Events(i).keyboard ~= 0)
            evtLabel = sprintf('Key %d', Events(i).keyboard);
            % Add previous stimulus name
            if ~isempty(lastStim)
                evtLabel = [lastStim ': ' evtLabel];
                reactTime = evtTime - lastStimTime;
            end
        else
            continue;
        end
        % Add "Multiple responses" comment
        isMulti = ismember(i, iMulti);
        if isMulti && ~isempty(lastStim)
            evtLabel = [strTagMulti ': ' evtLabel];
            select = 0;
        end
        % Look for event name in events list
        iEvtGroup = find(strcmpi({sFile.events.label}, evtLabel));
        % If event does not exist yet, create new event
        if isempty(iEvtGroup)
            iEvtGroup = length(sFile.events) + 1;
            sFile.events(iEvtGroup).label = evtLabel;
            if isMulti
                iEvtGroupMulti(end+1) = iEvtGroup;
            end
        end
        % Get a color for the event
        ColorTable = panel_record('GetEventColorTable');
        iColor = mod(iEvtGroup - 1, length(ColorTable)) + 1;
        newColor = ColorTable(iColor,:);
        
        % Add events occurrence
        iEvt = length(sFile.events(iEvtGroup).times) + 1;
        sFile.events(iEvtGroup).color            = newColor;
        sFile.events(iEvtGroup).epochs(iEvt)     = 1;
        sFile.events(iEvtGroup).times(iEvt)      = evtTime;
        sFile.events(iEvtGroup).reactTimes(iEvt) = reactTime;
        sFile.events(iEvtGroup).select           = select;
        if (iEvt == 1)
            sFile.events(iEvtGroup).channels = {{}};
            sFile.events(iEvtGroup).notes    = {[]};
        else
            sFile.events(iEvtGroup).channels{iEvt} = {};
            sFile.events(iEvtGroup).notes{iEvt}    = [];
        end
    end
    
    % Get events groups that have no multiple responses
    iEvtGroupNoMulti = setdiff(1:length(sFile.events), iEvtGroupMulti);
    % Sort event names (no-multi and then multi)
    [sortedNames, iSortMulti] = sort({sFile.events(iEvtGroupMulti).label});
    [sortedNames, iSortNoMulti] = sort({sFile.events(iEvtGroupNoMulti).label});
    sFile.events = [sFile.events(iEvtGroupNoMulti(iSortNoMulti)), ...
                    sFile.events(iEvtGroupMulti(iSortMulti))];
end


%% ===== REJECTED SEGMENTS =====
% New behavior: Bad segments of data are now converted into extended events called "BAD"
if ~isempty(hdr.rejected_segments)
    % Look for event name in events list
    evtLabel = 'BAD_CNT';
    iEvtGroup = find(strcmpi({sFile.events.label}, evtLabel)); 
    % If event doesnt exist yet: create one
    if isempty(iEvtGroup)
        iEvtGroup = length(sFile.events) + 1;
    end
    % Create new event
    badEvt = db_template('event');
    badEvt.label    = evtLabel;
    badEvt.color    = [1 0 0];
    badEvt.epochs   = ones(1, size(hdr.rejected_segments,1));
    badEvt.times    = hdr.rejected_segments' ./ sFile.prop.sfreq;
    badEvt.select   = 0;
    badEvt.channels = cell(1, size(badEvt.times, 2));
    badEvt.notes    = cell(1, size(badEvt.times, 2));
    sFile.events(iEvtGroup) = badEvt;
end

%% ===== CHANNEL FILE =====
% Create channel file structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'CNT 2D channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, length(hdr.electloc)]);
% Center of electrodes loc
x_center = (max([hdr.electloc.x_coord]) + min([hdr.electloc.x_coord])) / 2;
y_center = (max([hdr.electloc.y_coord]) + min([hdr.electloc.y_coord])) / 2;
for i = 1:length(hdr.electloc)
    ChannelMat.Channel(i).Name    = hdr.electloc(i).lab;
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Loc     = [-hdr.electloc(i).y_coord + y_center; -hdr.electloc(i).x_coord/2 + x_center/2; 0] ./ 500;
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];    
end


     

