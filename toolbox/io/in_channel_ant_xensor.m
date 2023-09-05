function ChannelMat = in_channel_ant_xensor(ChannelFile)
% IN_CHANNEL_ANT_XENSOR:  Read 3D cartesian positions for a set of electrodes from a ANT Xensor ASCII file.
%
% USAGE:  ChannelMat = in_channel_ant_xensor(ChannelFile)
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
% Authors: Francois Tadel, 2013-2014

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
iChannel = 1;
curBlock = '';
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'ANT Xensor';

% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % Empty line: go to next line
    if isempty(read_line)
        continue
    % End of file: stop reading
    elseif (read_line(1) == -1)
        break
    end
    % Strip additional spaces
    read_line = strtrim(read_line);
    % Empty line or comment: go to next line
    if isempty(read_line) || (read_line(1) == '#')
        curBlock = '';
        continue
    end     
    % Check if beginning/end of block
    if strcmpi(read_line, 'Positions')
        curBlock = 'pos';
        iChannel = 1;
    elseif strcmpi(read_line, 'Labels')
        curBlock = 'labels';
        iChannel = 1;
    elseif strcmpi(read_line, 'HeadShapePoints')
        curBlock = 'headpoints';
        iChannel = 1;
    else
        switch (curBlock)
            case 'labels'
                % If labels where not read yet: read them
                if (iChannel <= length(ChannelMat.Channel)) && isempty(ChannelMat.Channel(iChannel).Name)
                    % Remove extra spaces
                    read_line = strtrim(read_line);
                    % All channels in one line separated by tabs
                    if any(read_line == 9)
                        chNames = strtrim(str_split(read_line, char(9)));
                        if (length(chNames) == length(ChannelMat.Channel))
                            [ChannelMat.Channel.Name] = deal(chNames{:});
                        end
                    else
                        ChannelMat.Channel(iChannel).Name = strtrim(read_line);
                        iChannel = iChannel + 1;
                    end
                else
                    iChannel = iChannel + 1;
                end
                
            case 'pos'
                % If the channel names are defined at every line ("Name: X Y Z")
                if any(read_line == ':')
                    % Split line around ":"
                    splitLine = str_split(read_line, ':');
                    if (length(splitLine) ~= 2)
                        continue;
                    end
                    % Read fields
                    chName = strtrim(splitLine{1});
                    chLoc = str2num(splitLine{2});
                % Names are not defined ("X Y Z")
                else
                    chName = '';
                    chLoc = str2num(read_line);
                end
                % Error: skip
                if (length(chLoc) ~= 3)
                    continue;
                end
                % Create entry in channel fil
                ChannelMat.Channel(iChannel).Name    = chName;
                ChannelMat.Channel(iChannel).Type    = 'EEG';
                ChannelMat.Channel(iChannel).Loc     = chLoc' ./ 1000;
                ChannelMat.Channel(iChannel).Orient  = [];
                ChannelMat.Channel(iChannel).Comment = '';
                ChannelMat.Channel(iChannel).Weight  = 1;
                iChannel = iChannel + 1;
            case 'headpoints'
                % Scan line contents
                xyz = textscan(read_line, '%f %f %f', 1);
                % Error: skip
                if (length(xyz) < 3)
                    continue;
                end
                % Create entry in head points
                ChannelMat.HeadPoints.Loc(:,iChannel) = [xyz{1}; xyz{2}; xyz{3}] ./ 1000;
                ChannelMat.HeadPoints.Label{iChannel} = 'EXTRA';
                ChannelMat.HeadPoints.Type{iChannel}  = 'EXTRA';
                iChannel = iChannel + 1;
        end
    end
end
% Close file
fclose(fid);





