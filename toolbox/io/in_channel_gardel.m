function ChannelMat = in_channel_gardel(ChannelFile)
% IN_CHANNEL_GARDEL: Read 3D cartesian positions for a set of points from a GARDEL .txt file
%
% USAGE:  ChannelMat = in_channel_gardel(ChannelFile)
%
% INPUT: 
%    - ChannelFile : Full path to the channel file (with .txt extension)
% OUTPUT:
%    - ChannelMat  : Brainstorm channel structure

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
% Authors: Chinmay Chinara & Medina Villalon Samuel, 2025

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end

% Skip lines until finding 'MRI_voxel'
while true
    tline = fgets(fid);
    if ~isempty(strfind(tline, 'MRI_voxel'))
        break;
    end
end

% Initialize electrode storage
Electrodes = {};
% Read lines until finding 'MRI_FS'
while true
    tline = fgets(fid);
    if ~ischar(tline) || ~isempty(strfind(tline, 'MRI_FS'))
        break;
    end
    if isempty(strfind(tline, '#'))
        parsedLine = textscan(tline, '%s %f %f %f %f %f %s %s', 'Delimiter', '\t');
        Electrodes(end + 1, :) = parsedLine;
    end
end
% Close file
fclose(fid);

% Initialize channel structure
ChannelMat = db_template('channelmat');
ChannelMat.Channel = db_template('channeldesc');
ChannelMat.Comment = 'Gardel';
% Assign parsed electrodes data to Brainstorm channel
numElectrodes = size(Electrodes, 1);
% Preallocate structure array
ChannelMat.Channel(numElectrodes).Name = ''; 
for iElectrode = 1:numElectrodes
    electrodeData = Electrodes(iElectrode,:);    
    % Set channel name and group
    electrodeName = electrodeData{1}{1};
    electrodeIndex = electrodeData{2};
    ChannelMat.Channel(iElectrode).Name = sprintf('%s%d', electrodeName, electrodeIndex);
    ChannelMat.Channel(iElectrode).Group = electrodeName;  
    % Set location coordinates
    ChannelMat.Channel(iElectrode).Loc = [electrodeData{3:5}]';    
    % Set channel type
    ChannelMat.Channel(iElectrode).Type = 'SEEG';
end





