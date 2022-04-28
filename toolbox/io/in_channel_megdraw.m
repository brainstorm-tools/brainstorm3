function ChannelMat = in_channel_megdraw(ChannelFile)
% IN_CHANNEL_MEGDRAW:  Read 3D positions from a megDraw .eeg file.

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
% Authors: Francois Tadel, 2011


%% ===== READ FILE =====
% Open file
fid = fopen(ChannelFile, 'r');
% Initialize structures
NAS = [];
LPA = [];
RPA = [];
pos = [];
name = {};
i = 1;
% Loop to read all lines
while 1
    % Read next line
    s = fgetl(fid);
    if isempty(s)
        continue;
    end
    % Stop conditions
    if isequal(s, -1)
        break;
    end
    % Split line in blocks, to get the different values/names
    ss = str_split(s, [' ,' 9]);
    % Switch based on the number of elements
    switch length(ss)
        case {0, 1, 2}
            % Ignore
            continue;
        case 3
            % X Y Z
            newName = sprintf('%03d', i);
            i = i + 1;
            newPos = ss(1:3);
        case {4,7}
            % Name X Y Z ...
            newName = ss{1};
            newPos = ss(2:4);
        case 5
            % Indice Name X Y Z
            newName = ss{2};
            newPos = ss(3:5);
        otherwise
            disp(['IN_CHANNEL> Warning: Line with invalid number of elements: "' s '"']);
            continue;
    end
    % Convert to double
    newPos = [str2num(newPos{1}), str2num(newPos{2}), str2num(newPos{3})];
    % Scale CENTIMETERS => METERS
    newPos = newPos ./ 100;
    % Switch depending on the point name: process fiducials NZ,OG,OD separately
    switch upper(newName)
        case 'NZ'
            NAS = [NAS; newPos];
        case 'OG'
            LPA = [LPA; newPos];
        case 'OD'
            RPA = [RPA; newPos];
        otherwise
            name{end+1} = newName;
            pos = [pos; newPos];
    end
end
% Close file
fclose(fid);


%% ===== BUILD CHANNEL LIST =====
% Detect sensors (sensors have names)
iSens = find(~cellfun(@isempty, name));
Channel = repmat(db_template('channeldesc'), 0);
% Loop on all the sensors
for i = 1:length(iSens)
    Channel(i).Type    = 'EEG';
    Channel(i).Name    = name{iSens(i)};
    Channel(i).Loc     = pos(iSens(i), :)';
    Channel(i).Orient  = [];
    Channel(i).Comment = '';
    Channel(i).Weight  = 1;
end
% Build output structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'MegDraw';
ChannelMat.Channel = Channel;


%% ===== CONVERT TO CTF/BRAINSTORM CS =====
if ~isempty(NAS) && ~isempty(LPA) && ~isempty(RPA)
    % Compute average of all the fiducials positions, if there are many sample of them
    ChannelMat.SCS.NAS = mean(NAS, 1)';
    ChannelMat.SCS.LPA = mean(LPA, 1)';
    ChannelMat.SCS.RPA = mean(RPA, 1)';

    % Add to the head points
    ChannelMat.HeadPoints.Label = {'NAS', 'LPA', 'RPA'};
    ChannelMat.HeadPoints.Type  = {'CARDINAL', 'CARDINAL', 'CARDINAL'};
    ChannelMat.HeadPoints.Loc   = [ChannelMat.SCS.NAS, ChannelMat.SCS.LPA, ChannelMat.SCS.RPA];
end



