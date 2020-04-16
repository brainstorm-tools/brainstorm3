function out_events_graph2(sFile, OutputFile)
% OUT_EEVENTS_GRAPH2: Export events from a file or from the raw file viewer.
%    Compatible with the Graph Alternative Event-list Style'
% USAGE:  out_events_graph2(sFile, OutputFile)
%
% INPUT: 
%     - sFile      : Brainstorm file structure that contains the events to save
%     - OutputFile : Output events file
%
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
% Authors: Juan Garcia-Prieto, 2020
%          Francois Tadel, 2020 (this file is based on out_events_csv.m)

% Concatenate all the events together
allTime = zeros(1,0);
allInd = [];
for i = 1:length(sFile.events)
    % Simple events
    if (size(sFile.events(i).times, 1) == 1)
        allTime = [allTime, [sFile.events(i).times; 0*sFile.events(i).times]];
    % Extented events
    elseif (size(sFile.events(i).times, 1) == 2)
        disp('BST> Warning: Extended events not suported');
    end
    allInd = [allInd, repmat(i, 1, size(sFile.events(i).times,2))];
end
% Sort based on time
[tmp, iSort] = sort(allTime(1,:));
% Apply sorting to both arrays
allTime = allTime(:,iSort);
allInd  = allInd(iSort);

%Save file (ascii)
fout = fopen(OutputFile, 'w');
if (fout < 0)
    warning('Cannot open file.');
    return
end

[fPath, fBase, fExt] = bst_fileparts(sFile.filename);

fprintf(fout,'(graph::saved-event-list\n');
fprintf(fout,' :source-file %s\n',fBase);
fprintf(fout,' :events ''(\n');

defaultLevel=1.1234567891e-11;
% Write all the events, one by line
for i = 1:length(allInd)
    % Get event structure
    sEvt = sFile.events(allInd(i));
    % Simple events
    %if (size(sEvt.times, 1) == 1)
        fprintf(fout, '  ((:time  %6.3f) (:class "%s") (:level  %e))\n', allTime(1,i), sEvt.label, defaultLevel );
    % Extended events
    %elseif (size(sEvt.times, 1) == 2)
    %    fprintf(fout, '%s, %g, %g\n', sEvt.label, allTime(1,i), allTime(2,i) - allTime(1,i));
    %end
end

fprintf(fout,'))\n');

% Close file
fclose(fout);





