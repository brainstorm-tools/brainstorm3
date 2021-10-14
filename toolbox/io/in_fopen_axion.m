function [sFile, ChannelMat] = in_fopen_axion(DataFile)
% IN_FOPEN_AXION Open Axion recordings collected in AxIS.
% Open data that are saved in a single .raw file
%
% USAGE: [sFile, ChannelMat] = in_fopen_axion(DataFile)

% This function uses the "Axion MATLAB Files" package 
% distributed by Axion Biosystems with their AxIS software 

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
% Authors: Raymundo Cassani, Francois Tadel, 2021


%% ===== INSTALL MFF LIBRARY =====
if ~exist('AxisFile', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'axion');
    if ~isInstalled
        error(errMsg);
    end
end


%% ===== READ FILE HEADER =====
% Get base dataset folder
[fPath, fBase] = bst_fileparts(DataFile);
hdr.FileObj = AxisFile(DataFile);


%% ===== GET CHANNEL LABELS =====
hdr.ChannelCount = length(hdr.FileObj.DataSets.ChannelArray.Channels);
hdr.ChannelLabels = cell(1, hdr.ChannelCount);
for iChannel = 1:hdr.ChannelCount
    % Label according the Axion nomenclature, four characters, each corresponds
    % to the indices of the 4D cell array obtained with FileObj.DataSets.LoadData()
    % 1st char: WellRow         = 1st index in 4D array,  'A', 'B',...  =  1, 2,...
    % 2nd char: WellColumn      = 2nd index in 4D array,  '1', '2',...  =  1, 2,...
    % 3rd char: ElectrodeColumn = 3rd index in 4D array,  '1', '2',...  =  1, 2,...
    % 4th char: ElectrodeRow    = 4th index in 4D array,  '1', '2',...  =  1, 2,...
    chObj = hdr.FileObj.DataSets.ChannelArray.Channels(iChannel);
    hdr.ChannelLabels{iChannel} = [...
        char(uint8('A') - 1 + chObj.WellRow), ...
        num2str(chObj.WellColumn), ...
        num2str(chObj.ElectrodeColumn), ...
        num2str(chObj.ElectrodeRow)];
    % Read all the data for one channel, to get the file duration
    if (iChannel == 1)
        chData = hdr.FileObj.DataSets.LoadData(hdr.ChannelLabels{1}(1:2), hdr.ChannelLabels{1}(3:4));
        chWaveform = chData{chObj.WellRow, chObj.WellColumn, chObj.ElectrodeColumn, chObj.ElectrodeRow};
        hdr.NumSamples = length(chWaveform.Data);
    end
end
% Sort channels by label
[hdr.ChannelLabels, hdr.ChannelIndices] = sort(hdr.ChannelLabels);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.filename    = DataFile;
sFile.format      = 'EEG-AXION';
sFile.device      = 'MEA Axion';
sFile.comment     = fBase;
% Sampling frequency is considered the same for all channels
sFile.prop.sfreq  = hdr.FileObj.DataSets.Header.SamplingFrequency;
sFile.prop.times  = [0, hdr.NumSamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg   = 1;
sFile.header      = hdr;
% No info on bad channels
sFile.channelflag = ones(hdr.ChannelCount, 1);
sFile.acq_date    = datestr(hdr.FileObj.DataSets.Header.ExperimentStartTime.ToDateTimeVect);


%% ===== CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Axion channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.ChannelCount]);
for iChannel = 1:hdr.ChannelCount
    ChannelMat.Channel(iChannel).Name   = hdr.ChannelLabels{iChannel};
    ChannelMat.Channel(iChannel).Type   = 'EEG';
    ChannelMat.Channel(iChannel).Weight = 1;
end


%% ===== READ EVENTS =====
% TODO


% Close the file handle before saving the file
hdr.FileObj.close();


