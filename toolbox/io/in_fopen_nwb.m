function [sFile, ChannelMat] = in_fopen_nwb(DataFile, ImportOptions)
% IN_FOPEN_NWB: Open recordings saved in the Neurodata Without Borders format
%
% This format can save raw signals and/or LFP signals
% If both are present on the .nwb file, only the RAW signals will be loaded
%
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
% Author: Konstantinos Nasiotis, Francois Tadel, 2019-2020

error('This code is outdated, see: https://neuroimage.usc.edu/forums/t/error-opening-nwb-files/21025');

%% ===== DOWNLOAD NWB LIBRARY IF NEEDED =====
if ~exist('nwbRead', 'file')
    errMsg = bst_install_nwb(ImportOptions.DisplayMessages);
    if ~isempty(errMsg)
        error(errMsg);
    end
end


%% ===== READ DATA HEADERS =====
% Go to NWB folder (if there is a need for generating more local files)
curDir = pwd;
NWBDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB');
cd(NWBDir);
% Read header
nwb2 = nwbRead(DataFile);
% Restore current folder
cd(curDir);

try
    all_raw_keys = keys(nwb2.acquisition);

    for iKey = 1:length(all_raw_keys)
        if ismember(all_raw_keys{iKey}, {'ECoG','raw','bla bla bla'})   %%%%%%%% ADD MORE HERE, DON'T KNOW WHAT THE STANDARD FORMATS ARE
            iRawDataKey = iKey;
            RawDataPresent = 1;
            break
        else
            RawDataPresent = 0;
        end
    end
    if isempty(all_raw_keys)
        RawDataPresent = 0;
    end
catch
    RawDataPresent = 0;
end


try
    % Check if the data is in LFP format
    all_lfp_keys = keys(nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries);

    for iKey = 1:length(all_lfp_keys)
        if ismember(all_lfp_keys{iKey}, {'lfp','bla bla bla'})   %%%%%%%% ADD MORE HERE, DON'T KNOW WHAT THE STANDARD FORMATS ARE
            iLFPDataKey = iKey;
            LFPDataPresent = 1;
            break % Once you find the data don't look for other keys/trouble
        else
            LFPDataPresent = 0;
        end
    end
catch
    LFPDataPresent = 0;
end


if ~RawDataPresent && ~LFPDataPresent
    error 'There is no data in this .nwb - Maybe check if the Keys are labeled correctly'
end



%% Check for additional channels

% Check if behavior fields/channels exists in the dataset
try
    nwb2.processing.get('behavior').nwbdatainterface;
    
    
    allBehaviorKeys = keys(nwb2.processing.get('behavior').nwbdatainterface)';
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Reject states "channel" - THIS IS HARDCODED - IMPROVE
    allBehaviorKeys = allBehaviorKeys(~strcmp(allBehaviorKeys,'states'));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    behavior_exist_here = ~isempty(allBehaviorKeys);
    if ~behavior_exist_here
        disp('No behavior in this .nwb file')
    else
        disp(' ')
        disp('The following behavior types are present in this dataset')
        disp('------------------------------------------------')
        for iBehavior = 1:length(allBehaviorKeys)
            disp(allBehaviorKeys{iBehavior})
        end
        disp(' ')
    end
    
    nAdditionalChannels = 0;
    for iBehavior = 1:length(allBehaviorKeys)
        allBehaviorKeys{iBehavior,2} = keys(nwb2.processing.get('behavior').nwbdatainterface.get(allBehaviorKeys{iBehavior}).spatialseries);
        
        for jBehavior = 1:length(allBehaviorKeys{iBehavior,2})
            nAdditionalChannels = nAdditionalChannels + nwb2.processing.get('behavior').nwbdatainterface.get(allBehaviorKeys{iBehavior}).spatialseries.get(allBehaviorKeys{iBehavior,2}(jBehavior)).data.dims(2);
        end    
    end
    
    additionalChannelsPresent = 1;
catch
    disp('No behavior in this .nwb file')
    additionalChannelsPresent = 0;
    nAdditionalChannels = 0;
    allBehaviorKeys = [];
end
    







%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');


if RawDataPresent
    sFile.prop.sfreq    = nwb2.acquisition.get(all_raw_keys{iRawDataKey}).starting_time_rate;
    sFile.header.RawKey = all_raw_keys{iRawDataKey};
    sFile.header.LFPKey = [];
    
    nChannels = nwb2.acquisition.get(all_raw_keys{iRawDataKey}).data.dims(2);
    nSamples  = nwb2.acquisition.get(all_raw_keys{iRawDataKey}).data.dims(1);

elseif LFPDataPresent
    sFile.prop.sfreq = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(all_lfp_keys{iLFPDataKey}).starting_time_rate;
    sFile.header.LFPKey = all_lfp_keys{iLFPDataKey};
    sFile.header.RawKey = [];
    
    nChannels = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(all_lfp_keys{iLFPDataKey}).data.dims(2);
    nSamples  = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(all_lfp_keys{iLFPDataKey}).data.dims(1);

end


%% Check for epochs/trials
[sFile, nEpochs] = in_trials_nwb(sFile, nwb2);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NWB channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels + nAdditionalChannels]);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check which one to select here!!!
% % % % % amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.vectordata.get('amp_channel').data.load;
amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.id.data.load;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

group_name      = nwb2.general_extracellular_ephys_electrodes.vectordata.get('group_name').data;

% Get coordinates and set to 0 if they are not available
x = nwb2.general_extracellular_ephys_electrodes.vectordata.get('x').data.load'./1000; % NWB saves in m ???
y = nwb2.general_extracellular_ephys_electrodes.vectordata.get('y').data.load'./1000;
z = nwb2.general_extracellular_ephys_electrodes.vectordata.get('z').data.load'./1000;

x(isnan(x)) = 0;
y(isnan(y)) = 0;
z(isnan(z)) = 0;

ChannelType = cell(nChannels + nAdditionalChannels, 1);

for iChannel = 1:nChannels
    ChannelMat.Channel(iChannel).Name    = ['amp' num2str(amp_channel_IDs(iChannel))]; % This gives the AMP labels (it is not in order, but it seems to be the correct values - COME BACK TO THAT)
    ChannelMat.Channel(iChannel).Loc     = [x(iChannel);y(iChannel);z(iChannel)];
                                        
    ChannelMat.Channel(iChannel).Group   = group_name{iChannel};
    ChannelMat.Channel(iChannel).Type    = 'SEEG';
    
    ChannelMat.Channel(iChannel).Orient  = [];
    ChannelMat.Channel(iChannel).Weight  = 1;
    ChannelMat.Channel(iChannel).Comment = [];
    
    ChannelType{iChannel} = 'EEG';
end


if additionalChannelsPresent
    
    iChannel = 0;
    for iBehavior = 1:size(allBehaviorKeys,1)
        
        for jBehavior = 1:size(allBehaviorKeys{iBehavior,2},2)
            
            for zChannel = 1:nwb2.processing.get('behavior').nwbdatainterface.get(allBehaviorKeys{iBehavior}).spatialseries.get(allBehaviorKeys{iBehavior,2}(jBehavior)).data.dims(2)
                iChannel = iChannel+1;

                ChannelMat.Channel(nChannels + iChannel).Name    = [allBehaviorKeys{iBehavior,2}{jBehavior} '_' num2str(zChannel)];
                ChannelMat.Channel(nChannels + iChannel).Loc     = [0;0;0];

                ChannelMat.Channel(nChannels + iChannel).Group   = allBehaviorKeys{iBehavior,1};
                ChannelMat.Channel(nChannels + iChannel).Type    = 'Misc';

                ChannelMat.Channel(nChannels + iChannel).Orient  = [];
                ChannelMat.Channel(nChannels + iChannel).Weight  = 1;
                ChannelMat.Channel(nChannels + iChannel).Comment = [];

                ChannelType{nChannels + iChannel,1} = allBehaviorKeys{iBehavior,1}; 
                ChannelType{nChannels + iChannel,2} = allBehaviorKeys{iBehavior,2}{jBehavior};
            end
        end
    end
end
    
    


%% Add information read from header
sFile.byteorder    = 'l';  % Not confirmed - just assigned a value
sFile.filename     = DataFile;
sFile.device       = 'NWB'; %nwb2.general_devices.get('implant');   % THIS WAS NOT SET ON THE EXAMPLE DATASET
sFile.header.nwb   = nwb2;
sFile.comment      = nwb2.identifier;
sFile.prop.times   = [0, nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(all_lfp_keys{iLFPDataKey}).data.dims(1) - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag  = ones(nChannels + nAdditionalChannels, 1);

sFile.header.LFPDataPresent            = LFPDataPresent;
sFile.header.RawDataPresent            = RawDataPresent;
sFile.header.additionalChannelsPresent = additionalChannelsPresent;
sFile.header.ChannelType               = ChannelType;
sFile.header.allBehaviorKeys           = allBehaviorKeys;


%% ===== READ EVENTS =====

events = in_events_nwb(sFile, nwb2, nEpochs, ChannelMat);

if ~isempty(events)
    % Import this list
    sFile = import_events(sFile, [], events);
end



