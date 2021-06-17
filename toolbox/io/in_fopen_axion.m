function [sFile, ChannelMat] = in_fopen_axion(DataFile)
% IN_FOPEN_AXION Open Axion recordings collected in AxIS.
% Open data that are saved in a single .raw file
%
% USAGE: [sFile, ChannelMat] = in_fopen_axion(DataFile)

% This function uses the the "Axion MATLAB Files" package 
% distributed by Axion Biosystems with their AxIS software 

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2021 University of Southern California & McGill University
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
% Authors: Raymundo Cassani, 2021


%% ===== GET FILE =====
% Get base dataset folder
[~, ~, axisFormat] = bst_fileparts(DataFile);
FileData = AxisFile(DataFile);


%% ===== FILE COMMENT =====
comment = FileData.Notes.RecordingName;


%% ===== READ DATA HEADERS =====
hdr.AxisVersion = FileData.AXIS_VERSION;
hdr.PlateType = FileData.Notes.Description;
hdr.Extension = axisFormat;
hdr.Description = FileData.Notes.Description;
hdr.SamplingFrequency = FileData.DataSets.Header.SamplingFrequency;
hdr.VoltageScale = FileData.DataSets.Header.VoltageScale;
hdr.RecordingSetup = FileData.DataSets.HeaderExtension.Description;
hdr.AcqDate = datestr(FileData.DataSets.Header.ExperimentStartTime.ToDateTimeVect);


%% Get all channels
sChannel = struct('WellRow',         [], ...
                  'WellColumn',      [], ... 
                  'ElectrodeColumn', [], ...
                  'ElectrodeRow',    []);
channelFields = fields(sChannel);
sChannel.Label = '';
hdr.ChannelCount = length(FileData.DataSets.ChannelArray.Channels);
sChannels = repmat(sChannel, 1, hdr.ChannelCount);
for iChannel = 1 : hdr.ChannelCount
    for iField = 1 : length(channelFields)
        sChannels(iChannel).(channelFields{iField}) = ...
            FileData.DataSets.ChannelArray.Channels(iChannel).(channelFields{iField});
    end
    % Assign label according the Axion nomenclature
    sChannels(iChannel) = axionChannelLabel(sChannels(iChannel)); 
end
% Sort channels by label
[~,idx] = sort({sChannels.Label});
hdr.sChannels = sChannels(idx);

% Read one channel to get number of samples
sChannel = hdr.sChannels(1);
tmpAll = FileData.DataSets.LoadData(sChannel.Label(1:2), sChannel.Label(3:4));
tmp = tmpAll{sChannel.WellRow, sChannel.WellColumn, sChannel.ElectrodeColumn, sChannel.ElectrodeRow};
hdr.NumSamples = length(tmp.Data);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.filename    = DataFile;
sFile.format      = 'EEG-AXION';
sFile.device      = 'MEA Axion';
sFile.comment     = comment;
% Sampling frequency is considered the same for all channels
sFile.prop.sfreq  = hdr.SamplingFrequency;
sFile.prop.times  = [0, hdr.NumSamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg   = 1;
sFile.header      = hdr;
% No info on bad channels
sFile.channelflag = ones(hdr.ChannelCount, 1);
sFile.acq_date    = hdr.AcqDate;


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Axion channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.ChannelCount]);

for iChannel = 1 : hdr.ChannelCount
    ChannelMat.Channel(iChannel).Name = hdr.sChannels(iChannel).Label;
    ChannelMat.Channel(iChannel).Loc     = [0; 0; 0];
    ChannelMat.Channel(iChannel).Type    = 'EEG';
    ChannelMat.Channel(iChannel).Orient  = [];
    ChannelMat.Channel(iChannel).Weight  = 1;
    ChannelMat.Channel(iChannel).Comment = [];
end


%% ===== READ EVENTS =====
% TODO

end


function sChannel = axionChannelLabel(sChannel)
% Label according the Axion nomenclature, four characters, each corresponds
% to the indices of the 4D cell array obtained with FileData.DataSets.LoadData()
% 1st char: WellRow         = 1st index in 4D array,  'A', 'B',...  =  1, 2,...
% 2nd char: WellColumn      = 2nd index in 4D array,  '1', '2',...  =  1, 2,...
% 3rd char: ElectrodeColumn = 3rd index in 4D array,  '1', '2',...  =  1, 2,...
% 4th char: ElectrodeRow    = 4th index in 4D array,  '1', '2',...  =  1, 2,...
    sChannel.Label = [char(uint8('A') - 1 + sChannel.WellRow), ...
                      num2str(sChannel.WellColumn), ...
                      num2str(sChannel.ElectrodeColumn), ...
                      num2str(sChannel.ElectrodeRow)];    
end