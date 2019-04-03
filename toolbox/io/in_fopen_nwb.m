function [sFile, ChannelMat] = in_fopen_nwb(DataFile)
% IN_FOPEN_NWB: Open recordings saved in the Neurodata Without Borders format
%
% This format can save raw signals and/or LFP signals
% If both are present on the .nwb file, only the RAW signals will be loaded
%
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
% Author: Konstantinos Nasiotis 2019


%% ===== INSTALL NWB LIBRARY =====
% Check if the NWB builder has already been downloaded
NWBDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB');
% Install toolbox
if exist(bst_fullfile(NWBDir, 'generateCore.m'),'file') ~= 2
    isOk = java_dialog('confirm', ...
        ['The NWB SDK is not installed on your computer.' 10 10 ...
             'Download and install the latest version?'], 'Neurodata Without Borders');
    if ~isOk
        bst_report('Error', sProcess, sInputs, 'This process requires the Neurodata Without Borders SDK.');
        return;
    end
    downloadNWB();
% If installed: add folder to path
elseif isempty(strfind(NWBDir, path))
    addpath(genpath(NWBDir));
end


%% ===== READ DATA HEADERS =====
% Read header
nwb2 = nwbRead(DataFile);

try
    all_raw_keys = keys(nwb2.acquisition);

    for iKey = 1:length(all_raw_keys)
        if ismember(all_raw_keys{iKey}, {'ECoG','bla bla bla'})   %%%%%%%% ADD MORE HERE, DON'T KNOW WHAT THE STANDARD FORMATS ARE
            iRawDataKey = iKey;
            RawDataPresent = 1;
        else
            RawDataPresent = 0;
        end
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
end
    







%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');


if RawDataPresent
    sFile.prop.sfreq    = nwb2.acquisition.get(all_raw_keys{iRawDataKey}).starting_time_rate;
    sFile.header.RawKey = all_raw_keys{iRawDataKey};
    sFile.header.LFPKey = [];
elseif LFPDataPresent
    sFile.prop.sfreq = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(all_lfp_keys{iLFPDataKey}).starting_time_rate;
    sFile.header.LFPKey = all_lfp_keys{iLFPDataKey};
    sFile.header.RawKey = [];
end



nChannels = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(all_lfp_keys{iLFPDataKey}).data.dims(2);





%%
%% Check for epochs/trials



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CHANGES IN THE EPOCHS SECTION SHOULD ALSO BE COPIED TO
% PROCESS_NWB_CONVERT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


all_conditions   = nwb2.intervals_trials.vectordata.get('condition').data;
uniqueConditions = unique(nwb2.intervals_trials.vectordata.get('condition').data);
timeBoundsTrials = double([nwb2.intervals_trials.start_time.data.load nwb2.intervals_trials.stop_time.data.load]);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% THIS FIELD MIGHT NOT BE PRESENT ON ALL DATASETS
% I'M KEEPING IT HERE FOR REFERENCE
% % Get error trials
% badTrials = nwb2.intervals_trials.vectordata.get('error_run').data.load;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

iUniqueConditionsTrials = zeros(length(uniqueConditions),1); % This will hold the index of each trial for each condition

% Get number of epochs
nEpochs = length(nwb2.intervals_trials.start_time.data.load);
% Get number of averaged trials
nAvg = 1;

% === EPOCHS FILE ===
if (nEpochs > 1)
    % Build epochs structure
    for iEpoch = 1:nEpochs
        ii = find(strcmp(uniqueConditions, all_conditions{iEpoch}));
        iUniqueConditionsTrials(ii) =  iUniqueConditionsTrials(ii)+1;
        sFile.epochs(iEpoch).label       = [all_conditions{iEpoch} ' (#' num2str(iUniqueConditionsTrials(ii)) ')'];
        sFile.epochs(iEpoch).times       = timeBoundsTrials(iEpoch,:);
        sFile.epochs(iEpoch).samples     = round(sFile.epochs(iEpoch).times * sFile.prop.sfreq);
        sFile.epochs(iEpoch).nAvg        = nAvg;
        sFile.epochs(iEpoch).select      = 1;
        sFile.epochs(iEpoch).bad         = 0;
%         sFile.epochs(iEpoch).bad         = badTrials(iEpoch); 
        sFile.epochs(iEpoch).channelflag = [];
    end
    sFile.format    = 'NWB';
elseif (nEpochs == 1)
    sFile.prop.nAvg = nAvg;
    sFile.format    = 'NWB-CONTINUOUS';
end
    



%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NWB channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels + nAdditionalChannels]);


amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.vectordata.get('amp_channel').data.load;
group_name      = nwb2.general_extracellular_ephys_electrodes.vectordata.get('group_name').data;

% Get coordinates and set to 0 if they are not available
x = nwb2.general_extracellular_ephys_electrodes.vectordata.get('x').data.load';
y = nwb2.general_extracellular_ephys_electrodes.vectordata.get('y').data.load';
z = nwb2.general_extracellular_ephys_electrodes.vectordata.get('z').data.load';

x(isnan(x)) = 0;
y(isnan(y)) = 0;
z(isnan(z)) = 0;

ChannelType = cell(nChannels + nAdditionalChannels, 1);

for iChannel = 1:nChannels
    ChannelMat.Channel(iChannel).Name    = ['amp' num2str(amp_channel_IDs(iChannel))]; % This gives the AMP labels (it is not in order, but it seems to be the correct values - COME BACK TO THAT)
    ChannelMat.Channel(iChannel).Loc     = [x(iChannel);y(iChannel);z(iChannel)];
                                        
    ChannelMat.Channel(iChannel).Group   = group_name{iChannel};
    ChannelMat.Channel(iChannel).Type    = 'EEG';
    
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
sFile.device       = nwb2.general_devices.get('implant');   % THIS WAS NOT SET ON THE EXAMPLE DATASET
sFile.header.nwb   = nwb2;
sFile.comment      = nwb2.identifier;
sFile.prop.samples = [0, nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(all_lfp_keys{iLFPDataKey}).data.dims(1) - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
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

% Import this list
sFile = import_events(sFile, [], events);

end



function downloadNWB()

    %% Download and extract the necessary files
    NWBDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB');
    NWBTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB_tmp');
    url = 'https://github.com/NeurodataWithoutBorders/matnwb/archive/master.zip';
    % If folders exists: delete
    if isdir(NWBDir)
        file_delete(NWBDir, 1, 3);
    end
    if isdir(NWBTmpDir)
        file_delete(NWBTmpDir, 1, 3);
    end
    % Create folder
	mkdir(NWBTmpDir);
    % Download file
    zipFile = bst_fullfile(NWBTmpDir, 'NWB.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'NWB download');
    if ~isempty(errMsg)
        % Try twice before giving up
        pause(0.1);
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'NWB download');
        if ~isempty(errMsg)
            file_delete(NWBTmpDir, 1, 3);
            error(['Impossible to download NWB.' 10 errMsg]);
        end
    end
    % Unzip file
    bst_progress('start', 'NWB', 'Installing NWB...');
    unzip(zipFile, NWBTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(NWBTmpDir);
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newNWBDir = bst_fullfile(NWBTmpDir, diropen(idir).name);
    % Move NWB directory to proper location
    file_move(newNWBDir, NWBDir);
    % Delete unnecessary files
    file_delete(NWBTmpDir, 1, 3);
    
    
    % Matlab needs to restart before initialization
    NWB_initialized = 0;
    save(bst_fullfile(NWBDir,'NWB_initialized.mat'), 'NWB_initialized');
    
    
    % Once downloaded, we need to restart Matlab to refresh the java path
    java_dialog('warning', ...
        ['The NWB importer was successfully downloaded.' 10 10 ...
         'Both Brainstorm AND Matlab need to be restarted in order to load the JAR file.'], 'NWB');
    error('Please restart Matlab to reload the Java path.');
    
    
end
