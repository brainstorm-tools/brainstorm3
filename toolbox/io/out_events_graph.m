function out_events_graph(sFile, OutputFile, strFormat)
% OUT_EEVENTS_GRAPH: Export events from a file or from the raw file viewer.
%    Compatible with the Graph Alternative Event-list Style'
% USAGE:  out_events_graph(sFile, OutputFile,strFormat)
%
% INPUT: 
%     - sFile      : Brainstorm file structure that contains the events to save
%     - OutputFile : Output events file
%     - strFormat  : String specifying the desired output format.
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

if (strcmp(strFormat,'defaultStyle'))
    %todo
    error('Export function for default events list file for Megin (Elekta) Graph files is not implemented yet.');
elseif (strcmp(strFormat,'alternativeStyle'))
    saveAlternativeStyle(fout,sFile,allInd,allTime);
end

% Close file
fclose(fout);


function saveAlternativeStyle(fid,sFile,allInd,allTime)
  
[fPath, fBase, fExt] = bst_fileparts(sFile.filename);

fprintf(fid,'(graph::saved-event-list\n');
fprintf(fid,' :source-file %s\n',fBase);
fprintf(fid,' :events ''(\n');

defaultLevel=1.1234567891e-11;
% Write all the events, one by line
for ev_i = 1:length(allInd)
    % Get event structure
    sEvt = sFile.events(allInd(ev_i));
    % Simple events
    %if (size(sEvt.times, 1) == 1)
        fprintf(fid, '  ((:time  %6.3f) (:class "%s") (:level  %e))\n', allTime(1,ev_i), sEvt.label, defaultLevel );
    % Extended events
    %elseif (size(sEvt.times, 1) == 2)
    %    fprintf(fid, '%s, %g, %g\n', sEvt.label, allTime(1,ev_i), allTime(2,ev_i) - allTime(1,ev_i));
    %end
end

fprintf(fid,'))\n');

end

end

