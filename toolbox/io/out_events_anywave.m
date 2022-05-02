function out_events_anywave( sFile, EventsFile )
% OUT_EVENTS_ANYWAVE: Export events to a AnyWave tab-separated text file (.mrk)
%
% USAGE:  out_events_anywave( sFile, EventsFile )
%
% REFERENCE: https://meg.univ-amu.fr/wiki/AnyWave:ADES#The_marker_file_.28.mrk.29

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
% Authors: Francois Tadel, 2022

% Concatenate all the events together
allTime = zeros(2,0);
allInd = [];
allChan = {};
for i = 1:length(sFile.events)
    % Simple events
    if (size(sFile.events(i).times, 1) == 1)
        allTime = [allTime, [sFile.events(i).times; 0*sFile.events(i).times]];
    % Extented events
    elseif (size(sFile.events(i).times, 1) == 2)
        allTime = [allTime, sFile.events(i).times];
    end
    allInd = [allInd, repmat(i, 1, size(sFile.events(i).times,2))];
    if iscell(sFile.events(i).channels) && (size(sFile.events(i).channels,1) == 1) && (size(sFile.events(i).channels,2) == size(sFile.events(i).times,2))
        allChan = cat(2, allChan, sFile.events(i).channels);
    elseif iscell(sFile.events(i).channels) && (size(sFile.events(i).channels,2) == 1) && (size(sFile.events(i).channels,1) == size(sFile.events(i).times,2))
        allChan = cat(2, allChan, sFile.events(i).channels');
    else
        disp(['BST> Invalid event "', sFile.events(i).label, '": Wrong dimensions for field "channels".']);
        allChan = cat(2, allChan, cell(1, size(sFile.events(i).times,2)));
    end
end
% Sort based on time
[tmp, iSort] = sort(allTime(1,:));
% Apply sorting to both arrays
allTime = allTime(:,iSort);
allInd  = allInd(iSort);
allChan = allChan(iSort);

% Save file (ascii)
fout = fopen(EventsFile, 'w');
if (fout < 0)
    warning('Cannot open file.');
    return
end
% Write header line
fprintf(fout, '// AnyWave Marker File\n');
% Write all the events, one by line
for i = 1:length(allInd)
    % Get event structure
    sEvt = sFile.events(allInd(i));
    % Print event name and start time
    fprintf(fout, '%s\t-1\t%g\t', sEvt.label, allTime(1,i));
    % Simple events
    if (size(sEvt.times, 1) == 1)
        fprintf(fout, '0\t');
    % Extended events
    elseif (size(sEvt.times, 1) == 2)
        fprintf(fout, '%g\t', allTime(2,i) - allTime(1,i));
    end
    % Print color
    fprintf(fout, '#%s%s%s', dec2hex(round(sEvt.color(1)*255),2), dec2hex(round(sEvt.color(2)*255),2), dec2hex(round(sEvt.color(3)*255),2));
    % Print channels
    if ~isempty(allChan{i})
        strChan = sprintf('%s,', allChan{i}{:});
        fprintf(fout, '\t%s', strChan(1:end-1));
    end
    % Print end of line
    fprintf(fout, '\n');
end
% Close file
fclose(fout);





