function ChannelMat = in_channel_emse_elp(ChannelFile)
% IN_CHANNEL_EMSE_ELP:  Read 3D cartesian positions for a set of electrodes from a .elp file.
%
% USAGE:  ChannelMat = in_channel_emse_elp(ChannelFile)
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
% Authors: Francois Tadel, 2009-2021

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
iChannel = 0;
iFiducial = 1;
isReadingSensor = 0;
isReadingHeadpoint = 0;
% Initialize returned structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'EMSE channels';

% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % End of file: stop reading
    if (read_line(1) == -1)
        break
    % Empty line: ignore
    elseif isempty(read_line) || (length(read_line) < 2)
        continue;
    % Start digitized head shape
    elseif ~isempty(strfind(read_line, 'position of digitized'))
        isReadingHeadpoint = 1;
        continue
    % Other comments: ignore
    elseif (read_line(1) == '/')
        continue;
    end

    % Fiducial
    if strcmpi(read_line(1:2), '%F')
        % Try to read 3 positions
        FidPos = sscanf(read_line(4:end), '%f %f %f');
        if (length(FidPos) == 3)
            switch iFiducial
                case 1,  FidName = 'NAS';
                case 2,  FidName = 'LPA';
                case 3,  FidName = 'RPA';
                otherwise,  continue
            end
            iFiducial = iFiducial + 1;
            iChannel = iChannel + 1;
            ChannelMat.Channel(iChannel).Name    = FidName;
            ChannelMat.Channel(iChannel).Type    = 'Fiducial';
            ChannelMat.Channel(iChannel).Loc     = FidPos;
            ChannelMat.Channel(iChannel).Orient  = [];
            ChannelMat.Channel(iChannel).Comment = '';
            ChannelMat.Channel(iChannel).Weight  = 1;
        end
        isReadingHeadpoint = 0;
    % Start sensor
    elseif strcmpi(read_line(1:2), '%S')
        SensorType = sscanf(read_line(4:end), '%d');
        isReadingSensor = 1;
        % Create new channel entry
        iChannel = iChannel + 1;
        ChannelMat.Channel(iChannel).Orient  = [];
        ChannelMat.Channel(iChannel).Comment = '';
        ChannelMat.Channel(iChannel).Weight  = 1;
        ChannelMat.Channel(iChannel).Type    = 'EEG';
        isReadingHeadpoint = 0;
    % Sensor name
    elseif strcmpi(read_line(1:2), '%N') && isReadingSensor
        SensorName = deblank(strtrim(read_line(4:end)));
        ChannelMat.Channel(iChannel).Name = SensorName;
        isReadingHeadpoint = 0;
    % Sensor position
    elseif isReadingSensor
        % Try to read 3 positions
        SensorPos = sscanf(read_line, '%f %f %f');
        if (length(SensorPos) == 3)
            ChannelMat.Channel(iChannel).Loc = SensorPos;
        end
        isReadingSensor = 0;
        isReadingHeadpoint = 0;
    % Reading digitized head shape
    elseif isReadingHeadpoint
        % Try to read 3 positions
        SensorPos = sscanf(read_line, '%f %f %f');
        if (length(SensorPos) == 3)
            iPoint = size(ChannelMat.HeadPoints.Loc, 2) + 1;
            ChannelMat.HeadPoints.Loc(:,iPoint) = SensorPos;
            ChannelMat.HeadPoints.Label{iPoint} = 'EXTRA';
            ChannelMat.HeadPoints.Type{iPoint}  = 'EXTRA';
        elseif (length(SensorPos) ~= 2)
            isReadingHeadpoint = 0;
        end
    end
end

% Close file
fclose(fid);

% Ensure that the variable ChannelMat was created
if ~exist('ChannelMat', 'var')
    ChannelMat = [];
end




