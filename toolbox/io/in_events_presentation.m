function events = in_events_presentation(sFile, EventFile)
% IN_EVENTS_PRESENTATION: Read stimulation times from Presentation software (.log files)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Robert Oostenveld, 2017

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error('Cannot open marker file.');
end
% Inialize event list
mrkType = {};
mrkTime = [];
isHeader = 1;
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
    % The line must contain the column names (eg. "Trial") before we start reading values
    if isHeader
        if ~isempty(strfind(strLine, 'Trial'))
            isHeader = 0;
        end
        continue;
    end
    % Split line
    cellLine = str_split(strLine, sprintf(' \t'));
    % If the line contains enough entries: use it
    if (length(cellLine) >= 4) && ~isempty(str2num(cellLine{4}))
        mrkType{end+1} = cellLine{3};
        mrkTime(end+1) = str2num(cellLine{4});
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
    events(iEvt).label   = uniqueEvt{iEvt};
    events(iEvt).epochs  = ones(1, length(iMrk));
    events(iEvt).times   = double(mrkTime(iMrk)) .* 1e-4;
    events(iEvt).samples = round(events(iEvt).times .* sFile.prop.sfreq);
    events(iEvt).reactTimes  = [];
    events(iEvt).select      = 1;
end



