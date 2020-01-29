function out_events_csv( sFile, EventsFile )
% OUT_EVENTS_CSV: Export events to a comma-separated text file (CSV): event_name, latency, duration
%
% USAGE:  out_events_csv( sFile, EventsFile )

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
% Authors: Francois Tadel, 2016-2019

% Concatenate all the events together
allTime = zeros(2,0);
allInd = [];
for i = 1:length(sFile.events)
    % Simple events
    if (size(sFile.events(i).times, 1) == 1)
        allTime = [allTime, [sFile.events(i).times; 0*sFile.events(i).times]];
    % Extented events
    elseif (size(sFile.events(i).times, 1) == 2)
        allTime = [allTime, sFile.events(i).times];
    end
    allInd = [allInd, repmat(i, 1, size(sFile.events(i).times,2))];
end
% Sort based on time
[tmp, iSort] = sort(allTime(1,:));
% Apply sorting to both arrays
allTime = allTime(:,iSort);
allInd  = allInd(iSort);

% Save file (ascii)
fout = fopen(EventsFile, 'w');
if (fout < 0)
    warning('Cannot open file.');
    return
end
% Write all the events, one by line
for i = 1:length(allInd)
    % Get event structure
    sEvt = sFile.events(allInd(i));
    % Simple events
    if (size(sEvt.times, 1) == 1)
        fprintf(fout, '%s, %g, 0\n', sEvt.label, allTime(1,i));
    % Extended events
    elseif (size(sEvt.times, 1) == 2)
        fprintf(fout, '%s, %g, %g\n', sEvt.label, allTime(1,i), allTime(2,i) - allTime(1,i));
    end
end
% Close file
fclose(fout);





