function [sFile, ChannelMat] = in_fopen_eeg(DataFile)
% IN_FOPEN_EEG: Open a Neuroscan .eeg file (list of epochs).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_eeg(DataFile)

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
% Authors: Francois Tadel, 2009-2019
        
%% ===== READ HEADER =====
% Read the header
hdr = neuroscan_read_header(DataFile, 'eeg');

% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-NEUROSCAN-EEG';
sFile.prop.sfreq = double(hdr.data.rate);
sFile.device     = 'Neuroscan';
sFile.header     = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Time and samples indices
sFile.prop.times   = linspace(hdr.data.xmin, hdr.data.xmax, hdr.data.pnts + 1);
sFile.prop.times   = [sFile.prop.times(1), sFile.prop.times(end-1)];
sFile.prop.nAvg = 1;
% Get bad channels
sFile.channelflag = ones(length(hdr.electloc),1);
sFile.channelflag([hdr.electloc.bad] == 1) = -1;


%% ===== EPOCHS LIST =====
% Build epochs structure
for i = 1:length(hdr.epochs)
    sFile.epochs(i).label   = hdr.epochs(i).comment;
    sFile.epochs(i).times   = sFile.prop.times;
    sFile.epochs(i).nAvg    = 1;
    sFile.epochs(i).select  = 1;
    sFile.epochs(i).bad         = 0;
    sFile.epochs(i).channelflag = [];
end


%% ===== CHANNEL FILE =====
% Create channel file structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'CNT 2D channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, length(hdr.electloc)]);
% Center of electrodes loc
x_center = (max([hdr.electloc.x_coord]) + min([hdr.electloc.x_coord])) / 2;
y_center = (max([hdr.electloc.y_coord]) + min([hdr.electloc.y_coord])) / 2;
for i = 1:length(hdr.electloc)
    ChannelMat.Channel(i).Name    = hdr.electloc(i).lab;
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Loc     = [-hdr.electloc(i).y_coord + y_center; -hdr.electloc(i).x_coord/2 + x_center/2; 0] ./ 500;
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];    
end



