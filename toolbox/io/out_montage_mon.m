function strFile = out_montage_mon(filename, sMontage)
% OUT_MOTNAGE_MON:  Save a montage file to a .mon file

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
% Authors: Francois Tadel, 2014

% First line: Montage name
strFile = [sMontage.Name, 10];
% Process display line by display line
for iDisp = 1:length(sMontage.DispNames)
    % Write title and first channel
    strFile = [strFile, sMontage.DispNames{iDisp}, ' : '];
    % Write list of channels
    iEntry = find(sMontage.Matrix(iDisp,:));
    for i = 1:length(iEntry)
        iChan = iEntry(i);
        fchan = sMontage.Matrix(iDisp,iChan);
        % Write factor
        if (fchan == 1)
            % Nothing to add
        elseif (fchan == -1)
            strFile = [strFile, '-'];
        else
            strFile = [strFile, num2str(fchan), '*'];
        end
        % Add channel name
        strFile = [strFile, sMontage.ChanNames{iChan}];
        % Add ','
        if (i ~= length(iEntry))
            strFile = [strFile, ', '];
        end
    end
    % Write end of line
    strFile = [strFile, 10];
end

% Save file
if ~isempty(filename)
    % Open file
    fid = fopen(filename, 'w');
    if (fid == -1)
        error('Cannot open file.');
    end
    % Write file
    fprintf(fid, '%s', strFile);
    % Close file
    fclose(fid);
end



