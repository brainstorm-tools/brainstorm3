function events = in_events_curry(sFile, EventFile)
% IN_EVENTS_CURRY: Read Curry events files

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
% Authors: Francois Tadel, 2012-2013

% Open file
fid = fopen(EventFile, 'r');
if fid < 0
    error(['Cannot open file ', EventFile]);
end
% Initialize returned structure
events = repmat(db_template('event'), 0);
curBlock = [];
evtMat = [];

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
    end
    % Identify blocks
    if ~isempty(strfind(newLine, 'NUMBER_LIST START_LIST'))
        curBlock = 'Events';
        continue;
    elseif ~isempty(strfind(newLine, 'END'))
        curBlock = [];
        continue;
    end
    % If no block is open: skip the line
    if isempty(curBlock)
        continue;
    end
    % Numeric values
    if strcmpi(curBlock, 'Events')
        % Interpret values: 3 values per line
        values = str2num(newLine);
        if (length(values) < 6)
            continue;
        end
        % Add to the list 
        evtMat = [evtMat; values(1:6)];
    end
end
% Close file
fclose(fid);
% If nothing was read: return
if isempty(evtMat)
    error('This file does not contain any Curry events.');
end

% Find all the event types
uniqueLabel = unique(evtMat(:,3));
% Convert to a structure matrix
for iEvt = 1:length(uniqueLabel)
    iOcc = find(evtMat(:,3) == uniqueLabel(iEvt));
    events(iEvt).label      = num2str(uniqueLabel(iEvt));
    events(iEvt).epochs     = ones(1,length(iOcc));
    events(iEvt).times      = evtMat(iOcc,5)' ./ sFile.prop.sfreq;
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
end

