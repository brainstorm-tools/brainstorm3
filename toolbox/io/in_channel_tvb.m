function ChannelMat = in_channel_tvb(ChannelFile)
% IN_CHANNEL_TVB: Read 3D cartesian positions from a TVB HDF5 SensorsEEG.h5 file (The Virtual Brain)
%
% USAGE:  ChannelMat = in_channel_tvb(ChannelFile)
            
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
% Authors: Francois Tadel, 2020

% Install/load EasyH5 Toolbox (https://github.com/NeuroJSON/easyh5) as plugin
if ~exist('loadh5', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'easyh5');
    if ~isInstalled
        error(errMsg);
    end
end

% Read data from .h5
h5 = loadh5(ChannelFile);
% Check data format
if ~isfield(h5, 'labels') || isempty(h5.labels) || ~isfield(h5, 'locations') || isempty(h5.locations)
    error('Invalid TVB SensorsEEG.h5 file: missing fields "locations" or "locations".');
end

% Get number of channels
nChannels = length(h5.labels);
% Default channel structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'TVB channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% For each channel
for i = 1:nChannels
    chName = strtrim(h5.labels(:,i)');
    chName(chName == 0) = [];
    if ~isempty(chName)
        ChannelMat.Channel(i).Name = chName;
    elseif (nChannels > 99)
        ChannelMat.Channel(i).Name = sprintf('E%03d', i);
    else
        ChannelMat.Channel(i).Name = sprintf('E%02d', i);
    end
    ChannelMat.Channel(i).Type = 'EEG';
    if ~isempty(h5.locations)
        ChannelMat.Channel(i).Loc = h5.locations(:,i) ./ 1000;
    else
        ChannelMat.Channel(i).Loc = [0; 0; 0];
    end
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end

