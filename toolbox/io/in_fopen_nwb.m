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
ChannelsModuleStructure.Fs = [];
ChannelsModuleStructure.nChannels = [];
ChannelsModuleStructure.FlipMatrix = [];
ChannelsModuleStructure.timeBounds = [];

for iKey = 1:length(allChannels_keys)
    ChannelsModuleStructure(iKey) = getDeeperModule(nwb2, allChannels_keys{iKey});
end

% Get rid of channels that should not be used
ChannelsModuleStructure = ChannelsModuleStructure(~cellfun(@isempty,{ChannelsModuleStructure.module}));




%% Perform a quality check that in case there are multiple RAW or multiple LFP keys present, they have the same sampling rate
electrophysiologicalFs = [];
electrophysiologicalTimeBounds = [];
for iModule = 1:length(ChannelsModuleStructure)
    if strcmp(class(ChannelsModuleStructure(iModule).module),'types.core.ElectricalSeries')
        electrophysiologicalFs = [electrophysiologicalFs ChannelsModuleStructure(iModule).Fs];
        electrophysiologicalTimeBounds = [electrophysiologicalTimeBounds ; ChannelsModuleStructure(iModule).timeBounds];
        ChannelsModuleStructure(iModule).isElectrophysiology = 1;
    else
        ChannelsModuleStructure(iModule).isElectrophysiology = 0;
    end
end

if length(unique(electrophysiologicalFs))>1
    error('There are electrophysiological signals with different sampling rates on this file - Aborting')
else
    Fs = unique(electrophysiologicalFs);
end

if size(unique(electrophysiologicalTimeBounds,'rows'),1)>1
    disp('There are electrophysiological signals with different timeBounds - PAY ATTENTION TO THIS')
else
    time = unique(electrophysiologicalTimeBounds,'rows');
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');

sFile.header.ChannelsModuleStructure = ChannelsModuleStructure;
sFile.prop.sfreq = Fs;

nChannels = sum([ChannelsModuleStructure.nChannels]);

%% Check for epochs/trials
% [sFile, nEpochs] = in_trials_nwb(sFile, nwb2);
[sFile, nEpochs] = in_epochs_nwb(sFile, nwb2);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NWB channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check which one to select here!!!
% amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.vectordata.get('amp_channel').data.load + 1;
amp_channel_IDs = nwb2.general_extracellular_ephys_electrodes.id.data.load;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% The following is weird - this should probably be stored differently in
% the NWB - change how Ben stores electrode assignements to shank
group_name = nwb2.general_extracellular_ephys_electrodes.vectordata.get('group_name').data;
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
    try
        groups = cellstr(nwb2.general_extracellular_ephys_electrodes.vectordata.get('group_name').data.load);
    catch
        groups = cell(1,length(group_name));
    end
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
  



ChannelType = cell(sum([ChannelsModuleStructure.nChannels]), 1);
ii = 0;

for iModule = 1:length(ChannelsModuleStructure)
    zz = 0;
    for iChannel = 1:ChannelsModuleStructure(iModule).nChannels
        ii = ii + 1;
        zz = zz + 1;
        if ChannelsModuleStructure(iModule).isElectrophysiology
            ChannelMat.Channel(ii).Name    = ['amp' num2str(amp_channel_IDs(iChannel))];
            ChannelMat.Channel(ii).Loc     = [x(iChannel);y(iChannel);z(iChannel)];
            ChannelMat.Channel(ii).Group   = groups{iChannel};
            ChannelMat.Channel(ii).Type    = 'SEEG';

            ChannelType{ii} = 'EEG';
        else
            LabelParsed=regexp(ChannelsModuleStructure(iModule).path,'/','split');

            ChannelMat.Channel(ii).Name    = [LabelParsed{end} '_' num2str(zz)];
            ChannelMat.Channel(ii).Loc     = [0;0;0];
            ChannelMat.Channel(ii).Group   = LabelParsed{end};
            ChannelMat.Channel(ii).Type    = 'Extra';

        end
        ChannelMat.Channel(ii).Orient  = [];
        ChannelMat.Channel(ii).Weight  = 1;
        ChannelMat.Channel(ii).Comment = [];
    end
end



%% Add information read from header
sFile.byteorder    = 'l';  % Not confirmed - just assigned a value
sFile.filename     = DataFile;
sFile.device       = 'NWB'; %nwb2.general_devices.get('implant');   % THIS WAS NOT SET ON THE EXAMPLE DATASET
sFile.header.nwb   = nwb2;
sFile.comment      = nwb2.identifier;
sFile.prop.times   = [time(1), time(end)];
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag  = ones(nChannels, 1);

sFile.header.ChannelType = ChannelType;


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




function moduleStructure = getDeeperModule(nwb, DataKey)
    % Parse the key for processing signal check
    BehaviorDataKeyLabelParsed=regexp(DataKey,'/','split');      
        
    [obj, Fs, nChannels, FlipMatrix, timeBounds] = get_module(nwb.(BehaviorDataKeyLabelParsed{2}), DataKey, 2); % Don't change the number
    
    moduleStructure.path       = DataKey;
    moduleStructure.module     = obj;
    moduleStructure.Fs         = Fs;
    moduleStructure.nChannels  = nChannels;
    moduleStructure.FlipMatrix = FlipMatrix;
    moduleStructure.timeBounds = timeBounds;
    
end



function [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = get_module(obj, DataKey, index)
    LabelParsed=regexp(DataKey,'/','split');
    index = index + 1;

    if strcmp(class(obj),'types.core.LFP')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = get_module(obj.electricalseries, DataKey, index);
    elseif strcmp(class(obj),'types.core.ElectricalSeries')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = getFsnChannels(obj);
    elseif strcmp(class(obj),'types.core.Position')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = get_module(obj.spatialseries, DataKey, index);
    elseif strcmp(class(obj), 'types.core.ProcessingModule')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = get_module(obj.nwbdatainterface, DataKey, index);
    elseif strcmp(class(obj), 'types.core.SpatialSeries')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = getFsnChannels(obj);
    elseif strcmp(class(obj), 'types.core.BehavioralTimeSeries')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = get_module(obj.timeseries, DataKey, index);
    elseif strcmp(class(obj), 'types.core.TimeSeries')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = getFsnChannels(obj);
    elseif strcmp(class(obj), 'types.untyped.Set')
        [obj_return, Fs, nChannels, FlipMatrix, timeBounds] = get_module(obj.get(LabelParsed(index)), DataKey, index);
    elseif strcmp(class(obj), 'types.ndx_aibs_ecephys.EcephysCSD')
        obj_return = []; % Dont really care using this - Confirm with the developers
        Fs = 0;
        nChannels = 0;
        FlipMatrix = 0;
        timeBounds = [0,0];
    else
        error('take care of this input type')
    end
%     if strcmp(class(obj), 'types.untyped.Anon')
%         obj_return = obj;
%     end
    
end

function [obj, Fs, nChannels, FlipMatrix, timeBounds] = getFsnChannels(obj)
    % This is an assumption that we will have more samples than channels
    % NWB files allow users to save the data however they want
    % The FlipMatrix flag would indicate to in_fopen_NWB to flip the
    % dimensions
    
    % Do a check if we're dealing with compressed or non-compressed data
    if strcmp(class(obj.data),'types.untyped.DataPipe') % Compressed data
        if obj.data.internal.dims(1)<obj.data.internal.dims(2)
            nChannels = obj.data.internal.dims(1);
            nSamples = obj.data.internal.dims(2);
            FlipMatrix = 0;
        else
            nChannels = obj.data.internal.dims(2);
            nSamples = obj.data.internal.dims(1);
            FlipMatrix = 1;
        end
    elseif strcmp(class(obj.data),'types.untyped.DataStub') % Uncompressed
        if obj.data.dims(1)<obj.data.dims(2)
            nChannels = obj.data.dims(1);
            nSamples = obj.data.dims(2);
            FlipMatrix = 0;
        else
            nChannels = obj.data.dims(2);
            nSamples = obj.data.dims(1);
            FlipMatrix = 1;
        end
    end
    
    
    if ~isempty(obj.starting_time_rate)
        Fs = obj.starting_time_rate;
        timeBounds = [obj.starting_time, obj.starting_time_rate*nSamples];
    elseif ~isempty(obj.timestamps)
        % Some recordings save timepoints irregularly. Cant do
        % much about this when it comes to Brainstorm that uses a fixed
        % sampling rate - Consider perhaps taking care of that on the
        % in_fread_nwb.
        Fs = round(mean(1./(diff(obj.timestamps.load(1,10))))); % Just load first 10 samples (consider a different approach here - there might be non-continuous segments)
        timeBounds = [obj.timestamps.load(1),obj.timestamps.load(end)];
    else
        obj = [];
        Fs = 0;
        timeBounds = [0,0];
        error('Cant determine sampling rate for this module - Ignoring it')
    end
end









