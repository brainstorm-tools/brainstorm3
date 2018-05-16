function events = in_events_xltek(sFile, EventFile)
% IN_EVENTS_XLTEK: Open an XLTEK exported events file (.txt)

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
% Authors: Olivier David, Francois Tadel, 2017

% Open and read file
fid = fopen(EventFile,'r');
% Skip 6 header lines
tmp = fgetl(fid);
tmp = fgetl(fid);
tmp = fgetl(fid);
tmp = fgetl(fid);
tmp = fgetl(fid);
tmp = fgetl(fid);

% Read start time
strLine = fgetl(fid);
[tmp,tmp2] = strtok(strLine);
starttime = strtok(tmp2);
starttime = sum(sscanf(starttime, '%d:%d:%d') .* [3600;60;1]);

% Loop to read all the events
evtLabel = {};
evtTime  = [];
while 1
    % Get line
    strLine = fgetl(fid);
    if (strLine == -1)
        break;
    end
    % Get label and timing
    [tmp1,tmp2] = strtok(strLine);
    [tmp1,tmp2] = strtok(tmp2);
    evtTime(end+1) = sum(sscanf(tmp1, '%d:%d:%d') .* [3600;60;1]) - starttime;
    evtLabel{end+1} = strtrim(tmp2);
end
% Close file
fclose(fid);

   
% ===== CONVERT TO BRAINSTORM FORMAT =====
% List of events (keep original order)
[uniqueEvt, I] = unique(evtLabel);
uniqueEvt = evtLabel(sort(I));
% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueEvt)]);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(evtLabel, uniqueEvt{iEvt}));
    % Add event structure
    events(iEvt).label      = uniqueEvt{iEvt};
    events(iEvt).samples    = unique(round(evtTime(iMrk) .* sFile.prop.sfreq));
    events(iEvt).times      = events(iEvt).samples ./ sFile.prop.sfreq;
    events(iEvt).epochs     = ones(1, length(events(iEvt).samples));   
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
end



