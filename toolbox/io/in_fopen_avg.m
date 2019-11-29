function [sFile, ChannelMat] = in_fopen_avg(DataFile)
% IN_FOPEN_AVG: Open a Neuroscan .avg file (list of epochs).
%
% USAGE:  sFile = in_fopen_avg(DataFile)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2019
        
%% ===== READ HEADER =====
% Read the header
hdr = neuroscan_read_header(DataFile, 'avg');

% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-NEUROSCAN-AVG';
sFile.prop.sfreq = double(hdr.data.rate);
sFile.device     = 'Neuroscan';
sFile.header     = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Time and samples indices
sFile.prop.times   = linspace(hdr.data.xmin, hdr.data.xmax, hdr.data.pnts + 1);
sFile.prop.times   = [sFile.prop.times(1), sFile.prop.times(end-1)];
sFile.prop.nAvg    = hdr.data.acceptcnt;
% Get bad channels
nChannels = length(hdr.electloc);
sFile.channelflag = ones(nChannels,1);
sFile.channelflag([hdr.electloc.bad] == 1) = -1;


% ===== CREATE DEFAULT CHANNEL FILE =====
% Normalize coordinates
XY = [[hdr.electloc.x_coord]', [hdr.electloc.y_coord]'];
minXY = min(XY);
maxXY = max(XY);
XY(:,1) = (XY(:,1) - (maxXY(1) + minXY(1)) / 2) ./ (maxXY(1) - minXY(1)) .* .0875;
XY(:,2) = (XY(:,2) - (maxXY(2) + minXY(2)) / 2) ./ (maxXY(2) - minXY(2)) .* .0875;
% Create channel structure
Channel = repmat(db_template('channeldesc'), [1 nChannels]);
for i = 1:nChannels
    if ~isempty(hdr.electloc(i).lab)
        Channel(i).Name = file_unique(hdr.electloc(i).lab, {Channel(1:i-1).Name});
    else
        Channel(i).Name = sprintf('E%02d', i);
    end
    Channel(i).Type    = 'EEG';
    Channel(i).Orient  = [];
    Channel(i).Weight  = 1;
    Channel(i).Comment = [];
    Channel(i).Loc = [XY(i,1); XY(i,2); 0];
end
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Neuroscan channels';
ChannelMat.Channel = Channel;


