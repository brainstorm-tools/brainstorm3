function [DataMat, ChannelMat] = in_data_biopac(DataFile)
% IN_DATA_BIOPAC: Read BIOPAC AcqKnowledge .acq files (version <= 4.1)
% 
% This function uses load_acq.m, which supports only versions of AcqKnowledge <= 4.1.
% For newer versions of AcqKnowledge, convert the files to .mat with bioread first.
% https://github.com/uwmadison-chm/bioread

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
% Authors: Francois Tadel, 2022

% Load file
acq = load_acq(DataFile, false);

% Get filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);

% Initialize returned structure
DataMat = db_template('DataMat');
DataMat.F        = acq.data';
DataMat.Time     = (0:size(DataMat.F,2)-1) .* acq.hdr.graph.sample_time ./ 1000;
DataMat.Comment  = fBase;
DataMat.Device   = 'BIOPAC';
DataMat.DataType = 'recordings';
DataMat.nAvg     = 1;

% No bad channels defined in those files: all good
nChannels = size(DataMat.F,1);
DataMat.ChannelFlag = ones(nChannels, 1);

% Default channel structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'BIOPAC channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% For each channel
for i = 1:nChannels
    chName = strtrim(acq.hdr.per_chan_data(i).comment_text);
    chName = chName(ismember(chName, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZ0123456789-_.'''));
    if ~isempty(chName)
        ChannelMat.Channel(i).Name = chName;
    elseif (length(ChannelMat.Channel) > 99)
        ChannelMat.Channel(i).Name = sprintf('E%03d', i);
    else
        ChannelMat.Channel(i).Name = sprintf('E%02d', i);
    end
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Loc     = [];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end






