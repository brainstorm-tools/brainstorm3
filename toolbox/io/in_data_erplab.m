function [DataMat, ChannelMat] = in_data_erplab(DataFile)
% IN_DATA_ERPLAB: Imports an ERPLab file.
%
% USAGE: [DataMat, ChannelMat] = in_data_erplab(DataFile);

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

% Load file
ErpMat = load(DataFile, '-mat');
if ~isfield(ErpMat, 'ERP')
    error('Not a valid ERPLab file: Missing .ERP field.');
end

% ===== READ ERP =====
% Initialize output matrix
nChannels = size(ErpMat.ERP.bindata, 1);
nBins     = size(ErpMat.ERP.bindata, 3);
DataMat = repmat(db_template('DataMat'), 1, nBins);
% Loop on bins
for i = 1:nBins
    % Average
    DataMat(i).F           = ErpMat.ERP.bindata(:,:,i) * 1e-6;
    DataMat(i).Time        = ErpMat.ERP.times / 1000;
    DataMat(i).Comment     = ErpMat.ERP.bindescr{i};
    DataMat(i).ChannelFlag = ones(nChannels, 1);
    DataMat(i).nAvg        = ErpMat.ERP.ntrials.accepted(i);
    DataMat(i).Device      = 'ERPLab';
    % Error
    if isfield(ErpMat.ERP, 'binerror') && ~isempty(ErpMat.ERP.binerror)
        DataMat(i).Std = ErpMat.ERP.binerror(:,:,i) * 1e-6;
    end
    % History
    DataMat(i) = bst_history('add', DataMat(i), 'erplab', ErpMat.ERP.history(:)');
end

% ===== CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, nChannels);
for i = 1:nChannels
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Name    = ErpMat.ERP.chanlocs(i).labels;
    if isfield(ErpMat.ERP.chanlocs(i), 'X') && ~isempty(ErpMat.ERP.chanlocs(i).X)
        ChannelMat.Channel(i).Loc = [ErpMat.ERP.chanlocs(i).X; ErpMat.ERP.chanlocs(i).Y; ErpMat.ERP.chanlocs(i).Z] ./ 1000;
    end
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Comment = '';
    ChannelMat.Channel(i).Weight  = 1;
end






