function out_montage_mne(filename, sMontages)
% OUT_MOTNAGE_MNE:  Save montages file to a MNE .sel file

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
% Authors: Francois Tadel, 2010-2014

% Open file
fid = fopen(filename, 'w');
if (fid == -1)
    error('Cannot open file.');
end

% Read file line by line
for iMon = 1:length(sMontages)
    % Write title and first channel
    fprintf(fid, '%s:%s', sMontages(iMon).Name, sMontages(iMon).ChanNames{1});
    % Write other channels
    for iChan = 2:length(sMontages(iMon).ChanNames)
        fprintf(fid, '|%s', sMontages(iMon).ChanNames{iChan});
    end
    % Write end of line
    fprintf(fid, '\n');
end

% Close file
fclose(fid);



