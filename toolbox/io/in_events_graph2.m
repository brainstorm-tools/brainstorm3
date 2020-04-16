function events = in_events_graph2(sFile, EventFile)
% IN_EVENTS_GRAPH2: Read Neuromag Graph events files (Alternative style)
% 
% This filed is modelled after in_events_graph.m 
% Clinica Elekta-Neuromag sites have a variation of the typical *.evl 
% format for exporting time events. This function is defined to be able to
% import this variation.
% 
% Example file:
%   | (beamformer::saved-event-list 
%   |  :source-file "/path/file.fif"
%   |  :events '(
%   | ((:time  991.73) (:class "A") (:level  2.47042716145e-11))
%   | ((:time  1019.15) (:class "B") (:level  2.6210856402e-11))
%   | )) 

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
% Authors: Juan GarciaPrieto, 2020
%          Francois Tadel, 2015

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error(['Cannot open file ', EventFile]);
end
% Initialize returned structure
events = repmat(db_template('event'), 0);
evtMat = zeros(1,0);
evtLabel = {};

% Read file line by line
while 1
    % Read one line
    newLine = fgetl(fid);
    if ~ischar(newLine)
        break;
    end
    % Strip spaces
    newLine(newLine == ' ') = [];
    % Lines to skip
    if isempty(newLine)
        continue;
    end
    % If the line does not contain ":time": skip
    if ( isempty(strfind(newLine, ':time')) || ...
         isempty(strfind(newLine, '"')) ) %#ok<*STREMP>
        continue;
    end
    % Parse the line: "((:timeXXXXXX) (:class "XXX") (:levelXXXXXXXXX))"
    % 
    res = sscanf(newLine, '((:time%f)');
    if isempty(res)
        continue;
    end
    
    posQuotes = strfind(newLine,'"');
    
    evtMat(:,end+1) = res;
    evtLabel{end+1} = newLine(posQuotes(1)+1:posQuotes(2)-1);
end
% Close file
fclose(fid);
% If nothing was read: return
if isempty(evtMat)
    error('This file does not contain any Neuromag Graph events.');
end

% Find all the event types
uniqueLabel = unique(evtLabel);
% Convert to a structure matrix
for iEvt = 1:length(uniqueLabel)
    iOcc = find(strcmpi(uniqueLabel{iEvt}, evtLabel));
    events(iEvt).label       = uniqueLabel{iEvt};
    events(iEvt).epochs      = ones(1,length(iOcc));
    events(iEvt).times       = round(evtMat(1,iOcc)* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    events(iEvt).reactTimes  = [];
    events(iEvt).select      = 1;
    events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
end



