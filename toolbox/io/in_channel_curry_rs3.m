function ChannelMat = in_channel_curry_rs3(ChannelFile)
% IN_CHANNEL_CURRY_RS3:  Read 3D cartesian positions for a set of electrodes from Curry .rs3 file.
%
% USAGE:  ChannelMat = in_channel_curry_res3(ChannelFile)
%
% INPUTS: 
%     - ChannelFile : Full path to the file

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
% Authors: Francois Tadel, 2009-2011

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
iChannel = 1;
curBlock = '';
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Curry rs3';

% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % Empty line: go to next line
    if isempty(read_line)
        continue
    end
    % End of file: stop reading
    if (read_line(1) == -1)
        break
    end

    % Check if beginning/end of block
     
    if ~isempty(regexp(read_line, 'SENSORS\w* START_LIST'))
        curBlock = 'pos';
        iChannel = 1;
    elseif ~isempty(regexp(read_line, 'LABELS\w* START_LIST'))
        curBlock = 'labels';
        iChannel = 1;
    elseif ~isempty(regexp(read_line, 'SENSORS\w* END_LIST')) || ~isempty(regexp(read_line, 'LABELS\w* END_LIST'))
        curBlock = '';
    else
        switch (curBlock)
            case 'labels'
                ChannelMat.Channel(iChannel).Name = read_line;
                iChannel = iChannel + 1;
            case 'pos'
                xyz = sscanf(read_line, '%f %f %f') / 1000;
                ChannelMat.Channel(iChannel).Type    = 'EEG';
                ChannelMat.Channel(iChannel).Loc     = [-xyz(2); xyz(1); xyz(3)];
                ChannelMat.Channel(iChannel).Orient  = [];
                ChannelMat.Channel(iChannel).Comment = '';
                ChannelMat.Channel(iChannel).Weight  = 1;
                iChannel = iChannel + 1;
        end
    end
end
% Close file
fclose(fid);





