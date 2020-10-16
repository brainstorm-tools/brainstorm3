function events = in_events_nicolet(sFile, EventFile)
% IN_EVENTS_NICOLET: Open a text file with events exported from the Nicolet viewer.

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

% Open and read file
fid = fopen(EventFile,'r');
% Markers list
Markers = {};
isMarkerSection = 0;
% Read file line by line
while 1
    % Read one line
    newLine = fgetl(fid);
    if ~ischar(newLine)
        break;
    end
    % Lines to skip
    if isempty(newLine)
        continue;
    elseif ~isempty(strfind(newLine, 'Name')) && ~isempty(strfind(newLine, 'Time')) && ~isempty(strfind(newLine, 'Duration'))
        isMarkerSection = 1;
        continue
    elseif ~isempty(strfind(newLine, 'Exam Start')) || (nnz(newLine == 9) >= 2)    % Lines with tabs = events
        isMarkerSection = 1;
    elseif ~isMarkerSection
        continue;
    end
    % Split with tabs (ASCII #9): Name, Time, Duration
    splitLine = str_split(newLine, char(9), 0);
    if (length(splitLine) ~= 3) || any(cellfun(@isempty, splitLine))
        continue;
    end
    % Get the time and duration
    try
        vecStart = datevec(splitLine{2}, 'HH:MM:SS');
        tStart = vecStart(4)*3600 + vecStart(5)*60 + vecStart(6);
        vecDuration = datevec(splitLine{3}, 'MM:SS');
        tDuration = vecDuration(5)*60 + vecDuration(6);
    catch
        continue;
    end
    % Add markers entry: {name, type, start, length}
    Markers(end+1,:) = {splitLine{1}, tStart, tDuration};
end
% Close file
fclose(fid);

% List of events
if isempty(Markers)
    uniqueEvt = [];
else
    uniqueEvt = unique(Markers(:,1)');
end
% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueEvt)]);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(Markers(:,1)', uniqueEvt{iEvt}));
    % Add event structure
    events(iEvt).label   = uniqueEvt{iEvt};
    events(iEvt).epochs  = ones(1, length(iMrk));   
    times = [Markers{iMrk,2}];
    if any([Markers{iMrk,3}] > 0)
        times(2,:) = [Markers{iMrk,2}] + [Markers{iMrk,3}];
    end
    events(iEvt).times      = round(times .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
end



