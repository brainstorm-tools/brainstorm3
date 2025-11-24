function events = in_events_bids(sFile, EventFile)
% IN_EVENTS_BIDS: Read a BIDS _events.tsv file (columns "onset", "duration", "trial_type").
%
% OUTPUT:
%    - events(i): array of structures with following fields (one structure per event type) 
%        |- label   : Identifier of event #i
%        |- samples : Array of unique time indices for event #i in the corresponding raw file
%        |- times   : Array of unique time latencies (in seconds) for event #i in the corresponding raw file

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
% Authors: Francois Tadel, 2019-2022

% Read tsv file
% https://bids-specification.readthedocs.io/en/stable/04-modality-specific-files/05-task-events.html
% trial_type would be a subset of possible events that identify trial category.
% value can be numbers or strings identifying the event.
% Only 'onset' and 'duration' are required.
Markers = in_tsv(EventFile, {'onset', 'duration', 'trial_type', 'channel', 'value'}, 0);
if isempty(Markers) || isempty(Markers{1,1})
    events = [];
    return;
end
% Standardize empty/missing values to empty char.
Markers(cellfun(@(c) (isequal(c,'n/a') || isequal(c,'N/A') || isempty(c)), Markers(:))) = {''};
% If there is no trial_type and no value information: use the filename as the event name
if all(cellfun(@isempty, Markers(:,3)) & cellfun(@isempty, Markers(:,5)))
    [fPath, fbase, fExt] = bst_fileparts(EventFile);
    Markers(:,3) = repmat({fbase}, size(Markers(:,3)));
elseif all(cellfun(@isempty, Markers(:,3)))
    Markers(:,3) = Markers(:,5);
elseif ~all(cellfun(@isempty, Markers(:,5)))
    % Both columns contain data
    for iM = 1:size(Markers, 1)
        if isempty(Markers{iM,3})
            Markers{iM,3} = Markers{iM,5};
        elseif ~isempty(Markers{iM,5})
            % Merge
            Markers{iM,3} = [Markers{iM,3} '-' Markers{iM,5}];
        end
    end
end
% List of events from trial_type and/or value
uniqueEvt = unique(Markers(:,3)');

% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueEvt)]);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(Markers(:,3)', uniqueEvt{iEvt}));
    % Get event onsets and durations
    onsets = cellfun(@(c)sscanf(c,'%f',1), Markers(iMrk,1), 'UniformOutput', 0);
    durations = cellfun(@(c)sscanf(c,'%f',1), Markers(iMrk,2), 'UniformOutput', 0);
    channels = Markers(iMrk,4)';
    % Find and reject events with no latency
    iEmpty = find(cellfun(@isempty, onsets));
    if ~isempty(iEmpty)
        iMrk(iEmpty) = [];
        onsets(iEmpty) = [];
        durations(iEmpty) = [];
        channels(iEmpty) = [];
    end
    % Channel names
    for iOcc = 1:length(channels)
        if (isempty(channels{iOcc}) || strcmpi(channels{iOcc}, 'n/a'))
            channels{iOcc} = [];
        else
            channels{iOcc} = {channels{iOcc}};
        end
    end
    % Add event structure
    events(iEvt).label  = uniqueEvt{iEvt};
    events(iEvt).epochs = ones(1, length(iMrk));
    events(iEvt).times  = [onsets{:}];
    % Convert latencies from the first sample in the file to the real timing 
    % See specs: https://bids-specification.readthedocs.io/en/stable/04-modality-specific-files/05-task-events.html
    events(iEvt).times = events(iEvt).times + sFile.prop.times(1);
    % Extended events if durations are defined for all the markers
    if all(~cellfun(@isempty, durations)) && all(~cellfun(@(c)isequal(c,0), durations))
        events(iEvt).times(2,:) = events(iEvt).times + [durations{:}];
    end
    % Make the function independent of sFile
    if ~isempty(sFile)
        events(iEvt).times  = round(events(iEvt).times .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    end
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).channels   = channels;
    events(iEvt).notes      = [];
end





