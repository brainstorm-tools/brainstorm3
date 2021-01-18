function events = in_events_oebin(sFile, EventFile)
% IN_EVENTS_OEBIN: Import events from a Open Ephys flat binary event file (timestamps.npy)
%
% USAGE:  events = in_events_oebin(sFile, EventFile)

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
% Authors: Francois Tadel, 2020

% Read time stamps
evtTime = reshape(readNPY(EventFile), 1, []);
if isempty(evtTime)
    events = [];
    return
end

% Find other files, indicating the type of event
[evtDir, fName] = bst_fileparts(EventFile);
TextFile = bst_fullfile(evtDir, 'text.npy');
% ChanFile = bst_fullfile(evtDir, 'channels.npy');
ChanStateFile = bst_fullfile(evtDir, 'channel_states.npy');

% Get event labels
if file_exist(TextFile)
    disp('EOBIN> ERROR: Text events are not supported yet...');
    evtGroupLabel = {'TEXT'};
    evtGroupInd = {1:length(evtTime)};
    evtChan = [];
    
%     evtLabels = readNPY(TextFile);
%     % Create event groups
%     evtGroupLabel = unique(evtLabels);
%     evtGroupInd = cell(1, length(evtGroupLabel));
%     for iUnique = 1:length(evtGroupLabel)
%         evtGroupInd{iUnique} = find(strcmpi(evtLabels, evtGroupLabel{iUnique}));
%     end
%     % Read event channel
%     if file_exist(ChanFile)
%         evtChan = readNPY(ChanFile);
%     else
%         evtChan = [];
%     end
elseif file_exist(ChanStateFile)
    evtVal = readNPY(ChanStateFile);
    % Create event groups
    uniqueVal = unique(evtVal);
    evtGroupLabel = cell(1, length(uniqueVal));
    evtGroupInd = cell(1, length(uniqueVal));
    for iUnique = 1:length(uniqueVal)
        evtGroupLabel{iUnique} = num2str(uniqueVal(iUnique));
        evtGroupInd{iUnique} = find(evtVal == uniqueVal(iUnique));
    end
    % Do not get read channels
    evtChan = [];
else
    evtGroupLabel = {'Unknown'};
    evtGroupInd = {1:length(evtTime)};
    evtChan = [];
end

% Initialize list of events
events = repmat(db_template('event'), [1, length(evtGroupLabel)]);
% Get occurrences for each event
for iEvt = 1:length(evtGroupLabel)
    events(iEvt).label      = evtGroupLabel{iEvt};
    events(iEvt).times      = double(evtTime(evtGroupInd{iEvt})) ./ sFile.prop.sfreq;
    events(iEvt).epochs     = ones(1, length(events(iEvt).times));  % Epoch: set as 1 for all the occurrences
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
%     if ~isempty(evtChan)
%         events(iEvt).channels = {num2cell({sFile.header.continuous.channels(evtChan).channel_name})};
%     else
%         events(iEvt).channels = cell(1, size(events(iEvt).times, 2));
%     end
    events(iEvt).channels = cell(1, size(events(iEvt).times, 2));
end



