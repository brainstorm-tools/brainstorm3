function sMontages = in_montage_mne(filename)
% IN_MONTAGE_MNE:  Read sensors selections file from MNE

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
% Authors: Francois Tadel, 2009-2014

% Initialize returned structure
sMontages = repmat(db_template('Montage'), 0);
% Open file
fid = fopen(filename, 'r');
if (fid == -1)
    error('Cannot open file.');
end

% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % End of file: stop reading
    if ~isempty(read_line) && (read_line(1) == -1)
        break
    end
    % Empty line: go to next line
    if isempty(read_line) || isempty(strtrim(read_line)) || (read_line(1) == '%')
        continue
    end
    % Else: regular line, split it
    read_line = str_split(read_line, ':|');
    % Create selection from line
    sMontages(end + 1).Name = read_line{1};
    sMontages(end).Type      = 'selection';
    sMontages(end).ChanNames = read_line(2:end);
    sMontages(end).DispNames = sMontages(end).ChanNames;
    sMontages(end).Matrix    = eye(length(sMontages(end).ChanNames));
end

% Close file
fclose(fid);


