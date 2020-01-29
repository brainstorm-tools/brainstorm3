function events = in_events_graph(sFile, EventFile)
% IN_EVENTS_GRAPH: Read Neuromag Graph events files
%
% Example file:
%   | (beamformer::saved-event-list 
%   |  :source-file "/path/file.fif"
%   |  :events '(
%   |   ((:time  28.8425) (:class :manual) (:length  0.069))
%   |   ((:time  31.194) (:class :manual) (:length  0.0415))
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
% Authors: Francois Tadel, 2015

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error(['Cannot open file ', EventFile]);
end
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
    events(iEvt).times       = round(([evtMat(1,iOcc); evtMat(1,iOcc) + evtMat(2,iOcc)]) .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    events(iEvt).reactTimes  = [];
    events(iEvt).select      = 1;
    events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
end



