function ChannelMat = in_channel_curry_pom(ChannelFile)
% IN_CHANNEL_CURRY_POM:  Read 3D cartesian positions for a set of points from a Curry .pom file.
%
% USAGE:  ChannelMat = in_channel_curry_pom(ChannelFile)
%
% INPUTS: 
%     - ChannelFile : Full path to the file

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
% Authors: Francois Tadel, 2017

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
iChannel = 1;
curBlock = '';
ChannelMat = db_template('channelmat');
ChannelMat.Channel = db_template('channeldesc');
ChannelMat.Comment = 'Curry pom';

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
    if ~isempty(strfind(read_line, 'LOCATION_LIST START_LIST'))
        curBlock = 'pos';
        iChannel = 1;
    elseif ~isempty(strfind(read_line, 'REMARK_LIST START_LIST'))
        curBlock = 'labels';
        iChannel = 1;
    elseif ~isempty(strfind(read_line, ' END_LIST'))
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
                if isempty(ChannelMat.Channel(iChannel).Name)
                    ChannelMat.Channel(iChannel).Name = sprintf('e%03d', iChannel);
                end
                iChannel = iChannel + 1;
        end
    end
end
% Close file
fclose(fid);





