function events = in_events_micromed(sFile, EventFile)
% IN_EVENTS_MICROMED: Open a Micromed .EVT file.
%
% OUTPUT:
%    - events(i): array of structures with following fields (one structure per event type) 

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
% Authors: Francois Tadel, 2021

% Initialize returned value
events = [];
% Read XML file
sXml = in_xml(EventFile);
if ~isfield(sXml, 'EventFile') || ~isfield(sXml.EventFile, 'Events') || ~isfield(sXml.EventFile.Events, 'Event') || isempty(sXml.EventFile.Events.Event)
    return;
end

% Get recordings start date (timestamp)
acq = sFile.header.acquisition;
start_time = posixtime(datetime(acq.year, acq.month, acq.day, acq.hour, acq.min, acq.sec, 0));

% Parse structure
sEvents = sXml.EventFile.Events.Event;
Markers = cell(length(sEvents), 3);
for iMrk = 1:length(sEvents)
    % Get time from the beginning of the file
    Markers{iMrk,1} = [posixtime(datetime(sEvents(iMrk).Begin.text, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS')) - start_time; ...
                       posixtime(datetime(sEvents(iMrk).End.text, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS')) - start_time];
    % TEXT: Interpret as event ename if the string is short
    if (length(sEvents(iMrk).Text.text) < 50)
        Markers{iMrk,2} = sEvents(iMrk).Text.text;
        if isfield(sEvents(iMrk), 'ExtraText') && isfield(sEvents(iMrk).ExtraText, 'text') && ~isempty(sEvents(iMrk).ExtraText.text)
            Markers{iMrk,3} = sEvents(iMrk).ExtraText.text;
        end
    % Otherwise, consider it as a note for an event EVT
    else
        Markers{iMrk,2} = 'EVT';
        Markers{iMrk,3} = sEvents(iMrk).Text.text;
    end
end

% List of events
uniqueEvt = unique(Markers(:,2)');
% Initialize returned structure
events = repmat(db_template('event'), 0);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iOcc = find(strcmpi(Markers(:,2)', uniqueEvt{iEvt}));
    % Compute samples from the file start
    samples = round([Markers{iOcc,1}] .* sFile.prop.sfreq);
    notes = Markers(iOcc,3)';
    % Detect if simple events (duration <= 2 samples)
    if ~any(samples(2,:) - samples(1,:) > 2)
        samples(2,:) = [];
    end
    % Adjust if there are segments in the file
    if isfield(sFile.header, 'segment') && ~isempty(sFile.header.segment)
        for iOcc = 1:size(samples,2)
            iSeg = find(samples(1,iOcc) >= [sFile.header.segment.time], 1, 'last');
            if ~isempty(iSeg)
                samples(:,iOcc) = ...
                    samples(:,iOcc) - sFile.header.segment(iSeg).time ...                    % Offset from beginning of segment (in samples)
                    + sFile.header.segment(iSeg).sample - sFile.header.segment(1).sample ... % Offset from beginning of file
                    + round(sFile.prop.times(1) .* sFile.prop.sfreq);                        % Start of the file
            end
        end
    end
    % Detect events outside of the file definition
    iOut = find((samples(end,:) < sFile.prop.times(1) .* sFile.prop.sfreq) | (samples(1,:) > sFile.prop.times(2) .* sFile.prop.sfreq));
    if ~isempty(iOut)
        disp([sprintf('BST> Event "%s": %d occurrences outside of the recordings [%1.3fs,%1.3fs]:   ', uniqueEvt{iEvt}, length(iOut), sFile.prop.times(1), sFile.prop.times(2)), ...
              sprintf('%1.3fs ', samples(1,iOut) ./ sFile.prop.sfreq)]);
        samples(:,iOut) = [];
        notes(iOut) = [];
    end
    if isempty(samples)
        continue;
    end
    % Add event structure
    iNew = length(events) + 1;
    events(iNew).label      = uniqueEvt{iEvt};
    events(iNew).epochs     = ones(1, size(samples,2));
    events(iNew).times      = samples ./ sFile.prop.sfreq;
    events(iNew).reactTimes = [];
    events(iNew).select     = 1;
    events(iNew).channels   = [];
    events(iNew).notes      = notes;
end



