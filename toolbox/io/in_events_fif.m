function events = in_events_fif(sFile, EventFile)
% IN_EVENTS_FIF: Read events information from a .fif or a .eve file
%
% USAGE:  events = in_events_fif(sFile, EventFile)

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
% Authors: Francois Tadel, 2010


%% ===== READ FILE =====
% Detect file format
[fPath, fBase, fExt] = bst_fileparts(EventFile);
% Can read ASCII or .FIF
switch (fExt)
    case {'.eve','.txt'}
        EventsMat = dlmread(EventFile);
    case '.fif'
        try
            EventsMat = mne_read_events(EventFile);
        catch
            % -eve.fif file might be empty and events might be stored in a
            % separate, ASCII file: prompt user for a possible alternative event file 
        end
    otherwise
        error('Unknown FIF events file format.');
end
% Force to be double
EventsMat = double(EventsMat);


%% ===== CONVERT TO BRAINSTORM STRUCTURE =====
% Is there a time column (second column of four)
isNoTime = (size(EventsMat, 2) < 4);
if isNoTime
    % Add a column for time
    EventsMat = [EventsMat(:,1), EventsMat(:,1) ./ sFile.prop.sfreq, EventsMat(:,[2 3])];
end
% Remove the rows for which the value does not change
iNoChange = find(EventsMat(:,3) == EventsMat(:,4));
if ~isempty(iNoChange)
    EventsMat(iNoChange, :) = [];
end
% Get the events beginnings
EventsMat = EventsMat(:, [1 2 4]);
% Get list of events
uniqueEvents = unique(EventsMat(:,3));

% Initialize list of events
events = repmat(db_template('event'), [1, length(uniqueEvents)]);
% Get occurrences for each event
for i = 1:length(uniqueEvents)
    % Get occurrence for this event
    iSmp = (EventsMat(:,3) == uniqueEvents(i));
    if isempty(iSmp)
        continue;
    end
    % Build events structure
    events(i).label      = sprintf('Event #%d', uniqueEvents(i));
    events(i).times      = EventsMat(iSmp, 2)';
    events(i).epochs     = ones(1, length(iSmp));  % Epoch: set as 1 for all the occurrences
    events(i).reactTimes = [];
    events(i).select     = 1;
    events(i).channels   = [];
    events(i).notes      = [];
end




