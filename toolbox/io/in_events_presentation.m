function events = in_events_presentation(sFile, EventFile)
% IN_EVENTS_PRESENTATION: Read stimulation times from Presentation software (.log files)

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
% Authors: Francois Tadel, 2017; Martin Cousineau, 2018

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error('Cannot open marker file.');
end
% Inialize event list
mrkType = {};
mrkTime = [];
% Default column positions if we can't figure them out
iCode = 3;
iTime = 4;
numCells = max(iCode, iTime);
% Loop to skip the first comment lines
while 1
    % Read one line
    strLine = fgetl(fid);
    % Reached the end of the file: return
    if isequal(strLine, -1)
        break;
    end
    % The line is empty
    if isempty(strLine)
        continue;
    end
    % Split line
    cellLine = str_split(strLine, sprintf('\t'), 0);
    if isHeader(cellLine)
        % Figure out position of columns we need
        iCode = find(strcmpi(cellLine, 'Code'));
        iTime = find(strcmpi(cellLine, 'Time'));
        numCells = max(iCode, iTime);
        continue;
    end

    % If the line contains enough entries: use it
    if (length(cellLine) >= numCells) && ~isempty(str2num(cellLine{iTime}))
        mrkType{end+1} = cellLine{iCode};
        mrkTime(end+1) = str2num(cellLine{iTime});
    end
end
% Close file
fclose(fid);

% List of events
uniqueEvt = unique(mrkType);
% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueEvt)]);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(mrkType, uniqueEvt{iEvt}));
    % Add event structure
    events(iEvt).label      = uniqueEvt{iEvt};
    events(iEvt).times      = sort(unique(double(mrkTime(iMrk)))) .* 1e-4;
    events(iEvt).epochs     = ones(1, length(events(iEvt).times));
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).channels   = [];
    events(iEvt).notes      = [];
end

end


function res = isHeader(cellLine)
    res = length(cellLine) >= 2 && any(strcmpi(cellLine, 'Code')) && any(strcmpi(cellLine, 'Time'));
end

