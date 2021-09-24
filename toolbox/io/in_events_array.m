function events = in_events_array(sFile, EventFile, format, EventName)
% IN_EVENTS_ARRAY: Read events information from a .mat or text file 
%
% USAGE:  events = in_events_array(sFile, EventFile, format, 'times')
%         events = in_events_array(sFile, EventFile, format, 'samples')
%         events = in_events_array(sFile, EventMat, ...)  

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
% Authors: Francois Tadel, Elizabeth Bock, 2012-2014

% Parse inputs
if (nargin < 4) || isempty(EventName)
    EventName = [];
end

% ===== READ FILE =====
if ischar(EventFile)
    % Can read ASCII or .mat
    EventsMat = load(EventFile);
    if isstruct(EventsMat)
        fields = fieldnames(EventsMat);
        EventsMat = EventsMat.(fields{1});
        if isstruct(EventsMat)
            fields = fieldnames(EventsMat);
            EventsMat = EventsMat.(fields{1});
        end
    end
    isInteractive = 1;
else
    EventsMat = EventFile;
    isInteractive = 0;
end
% Force to be double
EventsMat = double(EventsMat);
% Check orientation
if (size(EventsMat,2) < size(EventsMat,1))
    EventsMat = EventsMat';
end

% ===== FORMAT EVENTS =====
% Create [samples; times] array
switch (format)
    case 'times'
        evtTimes = round(EventsMat .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    case 'samples'
        evtTimes = round(EventsMat) ./ sFile.prop.sfreq;
end

% ===== TIME OFFSET =====
if isInteractive
    % Check for offset (typical of FIF files)
    isAddOffset = 0;
    if (sFile.prop.times(1) > 0)
        res = java_dialog('question', ['The raw data file starts at ' num2str(sFile.prop.times(1)) ' sec.' 10 10 ...
                                      'Is this offset already added to these events?' 10 10],...
                                      'Import events', [], {'Yes', 'Add Offset','Cancel'},'Yes');
        if isempty(res) || strcmpi(res, 'Cancel')
            bst_progress('stop');
            return;
        elseif strcmpi(res, 'Add Offset')
            isAddOffset = 1;
        end
    end
    % Add a column for time
    if isAddOffset
        evtTimes = evtTimes + sFile.prop.times(1);
    end
end

% ===== CONVERT TO BRAINSTORM STRUCTURE =====
% Initialize list of events
events = db_template('event');
% Ask for a label
if ~isempty(EventName)
    events.label = EventName;
else
    res = java_dialog('input', 'Please enter a label for this event:', 'Event Label');
    if isempty(res)
        events.label = '1';
    else
        events.label = res;
    end
end
events.color      = [];
events.reactTimes = [];
events.select     = 1;
events.times      = evtTimes;
events.epochs     = ones(1, length(evtTimes));  % Epoch: set as 1 for all the occurrences
events.channels   = cell(1, size(events.times, 2));
events.notes      = cell(1, size(events.times, 2));




