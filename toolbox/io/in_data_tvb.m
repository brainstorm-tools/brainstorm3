function [DataMat, ChannelMat] = in_data_tvb(DataFile, ChannelFile)
% IN_DATA_TVB: Read TVB HDF5 files (The Virtual Brain): *_TimeSeriesEEG.h5 (and optionnally *_SensorsEEG.h5)
%
% USAGE:  [DataMat, ChannelMat] = in_data_tvb(DataFile, ChannelFile)
% 
% DESCRIPTION:
%     The Virtual Brain export files are documented here:
%     https://www.thevirtualbrain.org/tvb/zwei/brainsimulator-data

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

% Parse inputs
if (nargin < 2) || isempty(ChannelFile)
    ChannelFile = [];
end

% Read data from .h5
h5ts = loadh5(DataFile);
% Check data format
if ~isfield(h5ts, 'data') || isempty(h5ts.data) || ~isfield(h5ts, 'time') || isempty(h5ts.time)
    error('Invalid TVB TimeSeriesEEG.h5 file: missing fields "data" or "time".');
end

% Get file name
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Fill returned structure
nEpochs = size(h5ts.data, 3);
DataMat = repmat(db_template('DataMat'), nEpochs, 1);
for iEpoch = 1:length(DataMat)
    DataMat(iEpoch).F           = permute(h5ts.data(:,:,iEpoch,:), [2,4,3,1]);
    DataMat(iEpoch).ChannelFlag = ones(size(DataMat(iEpoch).F,1), 1);
    DataMat(iEpoch).Time        = h5ts.time ./ 1000;
    DataMat(iEpoch).Device      = 'TVB-EEG';
    DataMat(iEpoch).DataType    = 'recordings';
    DataMat(iEpoch).nAvg        = 1;
    % Add comment tag for multiple epochs
    if (nEpochs > 1)
        DataMat(iEpoch).Comment = sprintf('%s (#%d)', fBase, iEpoch);
    else
        DataMat(iEpoch).Comment = fBase;
    end
end

% Look for channel file in the same folder
if isempty(ChannelFile)
    % Look for a sensor file with the same name
    dirSens = dir(bst_fullfile(fPath, strrep(DataFile, '_TimeSeriesEEG.h5', '_SensorsEEG.h5')));
    if ~isempty(dirSens)
        ChannelFile = bst_fullfile(fPath, dirSens(1).name);
    % Look for a single sensor file in this folder
    else
        dirSens = dir(bst_fullfile(fPath, '*_SensorsEEG.h5'));
        if isempty(dirSens)
            disp(['BST> TVB error: No sensor file found in folder: ' fPath]);
        elseif (length(dirSens) > 1)
            disp(['BST> TVB error: Multiple sensor files found in folder: ' fPath]);
        else
            ChannelFile = bst_fullfile(fPath, dirSens(1).name);
        end
    end
end
% Read channel file
if ~isempty(ChannelFile)
    disp(['BST> TVB: Reading sensor file: ' ChannelFile]);
    ChannelMat = in_channel_tvb(ChannelFile);
else
    ChannelMat = [];
end

