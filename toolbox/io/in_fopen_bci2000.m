function [sFile, ChannelMat] = in_fopen_bci2000(DataFile)
% IN_FOPEN_BCI2000: Open a BCI2000 .dat file
%
% Uses library: https://www.bci2000.org/mediawiki/index.php/User_Reference:Matlab_MEX_Files

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


%% ===== INSTALL PLUGIN BCI2000 =====
if ~exist('load_bcidat', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'bci2000');
    if ~isInstalled
        error(errMsg); 
    end
end


%% ===== READ HEADER =====
% Read file header
[signal, states, parameters, total_samples] = load_bcidat(DataFile);
hdr.paramters = parameters;
% Get channel number
hdr.nChannels = size(signal, 2);
% Get channel names
if isfield(parameters, 'ChannelNames') && isfield(parameters.ChannelNames, 'Value') && ~isempty(parameters.ChannelNames.Value)
    chLabels = parameters.ChannelNames.Value;
elseif isfield(parameters, 'ChannelNames') && isfield(parameters.ChannelNames, 'Values') && ~isempty(parameters.ChannelNames.Values)
    chLabels = parameters.ChannelNames.Values;
else
    chLabels = cell(1, hdr.nChannels);
    for i = 1:hdr.nChannels
        chLabels{i} = sprintf('E%d', i);
    end
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-BCI2000';
sFile.prop.sfreq = double(parameters.SamplingRate.NumericValue);
sFile.prop.times = [0, total_samples-1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
sFile.channelflag= ones(hdr.nChannels,1);
sFile.device     = 'BCI2000';
sFile.header     = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;


%% ===== CREATE CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'BCI2000 channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nChannels]);
% For each channel
for i = 1:hdr.nChannels
    ChannelMat.Channel(i).Name = chLabels{i};
    ChannelMat.Channel(i).Type = 'EEG';
end


%% ===== EVENTS =====
trigNames = fieldnames(states);
for iTrig = 1:length(trigNames)
    trig = double(states.(trigNames{iTrig}));
    % Find triggers on the various state channels
    for j = find(diff([trig(1), trig(:)']) > 0)
        iSmp = j - 1;
        Value = trig(j);
    end
    if isempty(iSmp)
        continue;
    end
    % Create event for each values
    uniqueVal = unique(Value);
    for iVal = 1:length(uniqueVal)
        iEvt = length(sFile.events) + 1;
        sFile.events(iEvt).label = trigNames{iTrig};
        if (length(uniqueVal) > 1)
            sFile.events(iEvt).label = [sFile.events(iEvt).label, num2str(uniqueVal(iVal))];
        end
        iOcc = iSmp(Value == uniqueVal(iVal));
        sFile.events(iEvt).epochs   = ones(length(iOcc), 1);
        sFile.events(iEvt).times    = iOcc ./ sFile.prop.sfreq;
        sFile.events(iEvt).channels = [];
        sFile.events(iEvt).notes    = [];
    end
end
