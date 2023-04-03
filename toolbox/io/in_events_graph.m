function events = in_events_graph(sFile, EventFile)
% IN_EVENTS_GRAPH: Read Neuromag Graph events files
%
% This file reads different variations of the .evl file in which
% Megin (Elekta) Graph users save their events.
%
% The following example shows the default evl export format from Graph.
% Example 1 of evl file:
%   | (beamformer::saved-event-list 
%   |  :source-file "/path/file.fif"
%   |  :events '(
%   |   ((:time  28.8425) (:class :manual) (:length  0.069))
%   |   ((:time  31.194) (:class :manual) (:length  0.0415))
%   | )) 
%
% The following example shows a variation of the default evl format which
% is used in some Megin (Elekta) labs.
% Example 2 of evl file:
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
% Authors: Francois Tadel, 2015
%          Juan GPC, 2020

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error(['Cannot open file ', EventFile]);
end

%list of reader functions for different formats
listOfReaders={@readDefaultFormat,...
          @readAlternativeFormat};
errorMsg = 'Unable to read the Graph events-list file.';

for i = 1:length(listOfReaders)
    try
        frewind(fid);
        events = listOfReaders{i}(fid);
    catch
        errorMsg = [errorMsg, char(10), lasterr];
        if (i < length(listOfReaders))
          continue;
        else
          error(errorMsg);
        end
    end
end
        
% Close file
fclose(fid);


function events = readDefaultFormat(fid)
% Initialize returned structure
events = repmat(db_template('event'), 0);
evtMat = zeros(2,0);
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
    if isempty(strfind(newLine, ':time'))
        continue;
    end
    % Parse the line: "((:timeXXXXXXX)(:class:manual)(:lengthYYYYYYY))"
    res = sscanf(newLine, '((:time%f)(:class:manual)(:length%f))');
    if (length(res) ~= 2)
        continue;
    end
    evtMat(:,end+1) = res(:);
    evtLabel{end+1} = 'Graph';
end

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
    events(iEvt).times       = round(([evtMat(1,iOcc); evtMat(1,iOcc) + evtMat(2,iOcc)]) .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    events(iEvt).reactTimes  = [];
    events(iEvt).select      = 1;
    events(iEvt).channels   = [];
    events(iEvt).notes      = [];
end

end

function events = readAlternativeFormat(fid)

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
    events(iEvt).channels   = [];
    events(iEvt).notes      = [];
end

end

end

