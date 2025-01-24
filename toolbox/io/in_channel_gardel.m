function ChannelMat = in_channel_gardel(ChannelFile)
% IN_CHANNEL_GARDEL: Read 3D cartesian positions for a set of points from a GARDEL .txt file
%
% USAGE:  ChannelMat = in_channel_gardel(ChannelFile)
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
% Authors: Chinmay Chinara & Medina Villalon Samuel, 2025

% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end
% Initialize indices structure
ChannelMat = db_template('channelmat');
ChannelMat.Channel = db_template('channeldesc');
ChannelMat.Comment = 'Gardel';

tline = fgets(fid);
while isempty(strfind(tline,'MRI_voxel'))
    tline = fgets(fid);
end
tline = fgets(fid);
Electrodes = [];
i = 1;
while ischar(tline) && ~contains(tline,'MRI_FS')
    if isempty(strfind(tline,'#'))
        Electrodes = [Electrodes; textscan(tline, '%s %f %f %f %f %f %s %s', 8, 'Delimiter', '\t')];
        i = i+1;
    end
    tline = fgets(fid);
end
fclose(fid);

for ii=1:length(Electrodes)
    a = Electrodes(ii, 1);
    b = Electrodes(ii, 2);
    ChannelMat.Channel(ii).Name = [a{:}{:} num2str(b{:})];

    ChannelMat.Channel(ii).Group = a{:}{:};
    
    x = Electrodes(ii, 3);
    y = Electrodes(ii, 4);
    z = Electrodes(ii, 5);
    xx(1) = x{:};
    xx(2) = y{:};
    xx(3) = z{:};

    ChannelMat.Channel(ii).Loc = xx';
    ChannelMat.Channel(ii).Type = 'SEEG';
end





