function events = in_events_csv(sFile, EventFile)
% IN_EVENTS_CSV: Import events from to a comma-separated text file (CSV): event_name, latency, duration
%
% USAGE:  events = in_events_csv(sFile, EventFile)

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
% Authors: Francois Tadel, 2019

% Intialize returned variable
events = [];
% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    disp(['Error: Cannot open file: ' EventFile]);
    return;
end
% Read file
csvValues = textscan(fid, '%s %f %f', 'Delimiter', ',');
% Close file
fclose(fid);

% If no values were read
if isempty(csvValues) || isempty(csvValues{1})
    disp(['Error: No values read from file: ' EventFile]);
    return;
end
  
% Get list of events
uniqueEvents = unique(csvValues{1});
% Initialize list of events
events = repmat(db_template('event'), [1, length(uniqueEvents)]);
% Get occurrences for each event
for iEvt = 1:length(uniqueEvents)
    % Skip empty events
    if isempty(uniqueEvents{iEvt})
        continue;
    end
    % Get occurrence for this event
    iSmp = find(strcmpi(csvValues{1}, uniqueEvents{iEvt}));
    if isempty(iSmp)
        continue;
    end
    % Simple events
    if (length(csvValues) < 3) || any(isnan(csvValues{3}))
        evtTimes = csvValues{2}(iSmp)';
    else
    % Extended events
        evtTimes = [csvValues{2}(iSmp)'; csvValues{2}(iSmp)' + csvValues{3}(iSmp)'];
    end
    % Build events structure
    events(iEvt).label      = uniqueEvents{iEvt};
    events(iEvt).times      = round(evtTimes .* sFile.prop.sfreq) ./ sFile.prop.sfreq;  % Round to closest sample
    events(iEvt).epochs     = ones(1, length(iSmp));  % Epoch: set as 1 for all the occurrences
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
end



