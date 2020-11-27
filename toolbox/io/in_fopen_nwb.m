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
% Author: Konstantinos Nasiotis 2019-2020


%% ===== INSTALL NWB LIBRARY =====
% Not available in the compiled version
if (exist('isdeployed', 'builtin') && isdeployed)
    error('Reading NWB files is not available in the compiled version of Brainstorm.');
end
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
disp(['NWB file schema version: ' util.getSchemaVersion(DataFile)])
nwb2 = nwbRead(DataFile);

all_TimeSeries_keys = keys(nwb2.searchFor('Timeseries', 'includeSubClasses'));
all_electricalSeries_keys = keys(nwb2.searchFor('electricalseries', 'includeSubClasses'));


disp('Add a check here if there are both RAW and LFP signals present - MAYBE POPUP FOR USER TO SELECT')

%% Check for channels

allChannels_keys = all_TimeSeries_keys;

% Make sure that a path is not the parent of another path
keep_module = true(1, length(allChannels_keys));
for iKey = 1:length(allChannels_keys)
    for jKey = iKey+1:length(allChannels_keys)
        if ~isempty(strfind(allChannels_keys{jKey}, allChannels_keys{iKey}))
            keep_module(iKey) = 0;
            break
        end
    end
end
allChannels_keys = allChannels_keys(keep_module);


ChannelsModuleStructure = struct;
ChannelsModuleStructure.path = [];
ChannelsModuleStructure.module = [];

for iKey = 1:length(allChannels_keys)
    ChannelsModuleStructure(iKey) = checkBehaviorSignalValidity(nwb2, allChannels_keys{iKey});
end

% Get rid of channels that should not be used
ChannelsModuleStructure = ChannelsModuleStructure(~cellfun(@isempty,{ChannelsModuleStructure.module}));





%% Perform a quality check that in case there are multiple RAW or multiple LFP keys present, they have the same sampling rate

disp('FINISH THIS')

CONTINUE BELOW












%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');

sFile.header.RawKey = {};
sFile.header.LFPKey = {};

if RawDataPresent
    nChannels = 0;
    sFile.header.RawKey = RawDataKeys;
    sFile.header.LFPKey = [];
    for iKey = 1:size(RawDataKeys,1)
        sFile.prop.sfreq = nwb2.acquisition.get(RawDataKeys{iKey}{3}).electricalseries.get(RawDataKeys{iKey}{5}).starting_time_rate;
        if isempty(sFile.prop.sfreq)
            % Some recordings just save timepoints irregularly. Cant do
            % much about this when it comes to Brainstorm that uses a fixed
            % sampling rate - Consider perhaps taking care of that on the
            % in_fread_nwb.
            time = nwb2.acquisition.get(RawDataKeys{iKey}{3}).electricalseries.get(RawDataKeys{iKey}{5}).timestamps.load;
            
            sFile.prop.sfreq = round(mean(1./(diff(time))));
        end
          
        % Do a check if we're dealing with compressed or non-compressed data
        dataType = class(nwb2.acquisition.get(RawDataKeys{iKey}{3}).electricalseries.get(RawDataKeys{iKey}{5}).data);
        if strcmp(dataType,'types.untyped.DataPipe')% Compressed data
            nChannels = nChannels + nwb2.acquisition.get(RawDataKeys{iKey}{3}).electricalseries.get(RawDataKeys{iKey}{5}).data.internal.dims(1);
            nSamples  = nwb2.acquisition.get(RawDataKeys{iKey}{3}).electricalseries.get(RawDataKeys{iKey}{5}).data.internal.dims(2);
        elseif strcmp(dataType,'types.untyped.DataStub')
            nChannels = nChannels + nwb2.acquisition.get(RawDataKeys{iKey}{3}).electricalseries.get(RawDataKeys{iKey}{5}).data.dims(1);
            nSamples  = nwb2.acquisition.get(RawDataKeys{iKey}).data.dims(2);
        end
    end

elseif LFPDataPresent
    LFPModule = nwb2.processing.get(LFPDataKeys{1}{3}).nwbdatainterface.get(LFPDataKeys{1}{5}).electricalseries.get(LFPDataKeys{1}{7});
    % Try to get the sampling rate
    sFile.prop.sfreq = LFPModule.starting_time_rate;
    % If it's not saved as rate, compute the frequency from the timestamps
    if isempty(sFile.prop.sfreq)
        time = LFPModule.timestamps.load;
        sFile.prop.sfreq = round(mean(1./(diff(time))));
    end
    
    sFile.header.LFPKey = LFPDataKeys;
    
    % Consider assigning them the opposite way
    nChannels = LFPModule.data.dims(1);
    nSamples  = LFPModule.data.dims(2);

end


%% Check for epochs/trials
% [sFile, nEpochs] = in_trials_nwb(sFile, nwb2);
[sFile, nEpochs] = in_epochs_nwb(sFile, nwb2);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NWB channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels + nAdditionalChannels]);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check which one to select here!!!
% amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.vectordata.get('amp_channel').data.load + 1;
amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.id.data.load;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% The following is weird - this should probably be stored differently in
% the NWB - change how Ben stores electrode assignements to shank
group_name = nwb2.general_extracellular_ephys_electrodes.vectordata.get('group').data;
try
    assignChannelsToShank = nwb2.general_extracellular_ephys_electrodes.vectordata.get('amp_channel').data.load+1; % Python based - first entry is 0 - maybe add condition for matlab based entries
    
    groups = cell(1,length(group_name));
    for iChannel = 1:length(group_name)
        
        ii = find(assignChannelsToShank==iChannel);
        
        temp = split(group_name(ii).path,'/');
        temp = temp{end};
        
        groups{iChannel} = temp;
    end
    
catch
    assignChannelsToShank = 1:length(group_name);
    groups = cell(1,length(group_name));
end
    
try
    % Get coordinates and set to 0 if they are not available
    x = nwb2.general_extracellular_ephys_electrodes.vectordata.get('x').data.load'./1000; % NWB saves in m ???
    y = nwb2.general_extracellular_ephys_electrodes.vectordata.get('y').data.load'./1000;
    z = nwb2.general_extracellular_ephys_electrodes.vectordata.get('z').data.load'./1000;
    
    x(isnan(x)) = 0;
    y(isnan(y)) = 0;
    z(isnan(z)) = 0;
catch
    x = zeros(1, length(group_name));
    y = zeros(1, length(group_name));
    z = zeros(1, length(group_name));
end
  



ChannelType = cell(nChannels + nAdditionalChannels, 1);

for iChannel = 1:nChannels
    ChannelMat.Channel(iChannel).Name    = ['amp' num2str(amp_channel_IDs(iChannel))];
    ChannelMat.Channel(iChannel).Loc     = [x(iChannel);y(iChannel);z(iChannel)];
    ChannelMat.Channel(iChannel).Group   = groups{iChannel};
    ChannelMat.Channel(iChannel).Type    = 'SEEG';
    
    ChannelMat.Channel(iChannel).Orient  = [];
    ChannelMat.Channel(iChannel).Weight  = 1;
    ChannelMat.Channel(iChannel).Comment = [];
    
    ChannelType{iChannel} = 'EEG';
end



if additionalChannelsPresent
    iChannel = 0;
    for iBehavior = 1:size(allBehaviorKeys,1)            
        for zChannel = 1:nwb2.processing.get('behavior').nwbdatainterface.get(allBehaviorKeys{iBehavior}).spatialseries.get(allBehaviorKeys{iBehavior,2}(jBehavior)).data.dims(2)
            iChannel = iChannel+1;

            ChannelMat.Channel(nChannels + iChannel).Name    = [allBehaviorKeys{iBehavior,2}{jBehavior} '_' num2str(zChannel)];
            ChannelMat.Channel(nChannels + iChannel).Loc     = [0;0;0];

            ChannelMat.Channel(nChannels + iChannel).Group   = allBehaviorKeys{iBehavior,1};
            ChannelMat.Channel(nChannels + iChannel).Type    = 'Behavior';

            ChannelMat.Channel(nChannels + iChannel).Orient  = [];
            ChannelMat.Channel(nChannels + iChannel).Weight  = 1;
            ChannelMat.Channel(nChannels + iChannel).Comment = [];

            ChannelType{nChannels + iChannel,1} = allBehaviorKeys{iBehavior,1}; 
            ChannelType{nChannels + iChannel,2} = allBehaviorKeys{iBehavior,2}{jBehavior};
        end
    end
end
    
    


%% Add information read from header
sFile.byteorder    = 'l';  % Not confirmed - just assigned a value
sFile.filename     = DataFile;
sFile.device       = 'NWB'; %nwb2.general_devices.get('implant');   % THIS WAS NOT SET ON THE EXAMPLE DATASET
sFile.header.nwb   = nwb2;
sFile.comment      = nwb2.identifier;
sFile.prop.times   = [time(1) time(end)];
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
    
    % Check if the download was succesful and try again if it wasn't
    time_before_entering = clock;
    updated_time = clock;
    time_out = 60;% timeout within 60 seconds of trying to download the file
    
    % Keep trying to download until a timeout is reached
    while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
        % Try to download until the timeout is reached
        pause(0.1);
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'NWB download');
        updated_time = clock;
    end
    % If the timeout is reached and there is still an error, abort
    if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
        error(['Impossible to download NWB.' 10 errMsg]);
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









function [RawDataKeyLabelParsed, isitRaw] = checkRawSignalValidity(nwb, DataKey)
    % Parse the key for Raw signal check
    RawDataKeyLabelParsed=regexp(DataKey,'/','split');
    if strcmp(RawDataKeyLabelParsed{2},'acquisition') && strcmp(RawDataKeyLabelParsed{4},'electricalseries')
        try
            nwb.acquisition.get(RawDataKeyLabelParsed{3}).electricalseries.get(RawDataKeyLabelParsed{5}).data(1,1);
            isitRaw = 1;
        catch
            disp(['Couldnt load the electricalseries for: ' DataKey])
            RawDataKeyLabelParsed = [];
            isitRaw = 0;
        end
    else
        RawDataKeyLabelParsed = [];
        isitRaw = 0;
    end
end

function [LFPDataKeyLabelParsed, isitLFP] = checkLFPSignalValidity(nwb, DataKey)
    % Parse the key for LFP signal check
    LFPDataKeyLabelParsed=regexp(DataKey,'/','split');
    if strcmp(LFPDataKeyLabelParsed{3},'ecephys') && strcmp(LFPDataKeyLabelParsed{6},'electricalseries')
        try
            nwb.processing.get(LFPDataKeyLabelParsed{3}).nwbdatainterface.get(LFPDataKeyLabelParsed{5}).electricalseries.get(LFPDataKeyLabelParsed{7}).data(1,1);
            isitLFP = 1;
        catch e
            disp(['Couldnt load the electricalseries for: ' DataKey])
            disp(e)
            LFPDataKeyLabelParsed = [];
            isitLFP = 0;
        end
    else
        LFPDataKeyLabelParsed = [];
        isitLFP = 0;
    end
end




function moduleStructure = checkBehaviorSignalValidity(nwb, DataKey)
    % Parse the key for processing signal check
    BehaviorDataKeyLabelParsed=regexp(DataKey,'/','split');      
        
    obj = get_module(nwb.(BehaviorDataKeyLabelParsed{2}), DataKey, 2);
    
    moduleStructure.path   = DataKey;
    moduleStructure.module = obj;
    
end



function obj_return = get_module(obj, DataKey, index)
    LabelParsed=regexp(DataKey,'/','split');
    index = index + 1;

    if strcmp(class(obj),'types.core.LFP')
        obj_return = get_module(obj.electricalseries, DataKey, index);
    elseif strcmp(class(obj),'types.core.ElectricalSeries')
        obj_return = obj;
    elseif strcmp(class(obj),'types.core.Position')
        obj_return = get_module(obj.spatialseries, DataKey, index);
    elseif strcmp(class(obj), 'types.core.ProcessingModule')
        obj_return = get_module(obj.nwbdatainterface, DataKey, index);
    elseif strcmp(class(obj), 'types.core.SpatialSeries')
        obj_return = obj;
    elseif strcmp(class(obj), 'types.core.BehavioralTimeSeries')
        obj_return = get_module(obj.timeseries, DataKey, index);
    elseif strcmp(class(obj), 'types.core.TimeSeries')
        obj_return = obj;
    elseif strcmp(class(obj), 'types.untyped.Set')
        obj_return = get_module(obj.get(LabelParsed(index)), DataKey, index);
    elseif strcmp(class(obj), 'types.ndx_aibs_ecephys.EcephysCSD')
        obj_return = []; % Dont really care using this - Confirm with the developers      
    else
        error('take care of this input type')
    end
%     if strcmp(class(obj), 'types.untyped.Anon')
%         obj_return = obj;
%     end
    
end









