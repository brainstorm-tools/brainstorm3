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
% Author: Konstantinos Nasiotis 2019-2021
%         Francois Tadel, 2020-2023


%% ===== INSTALL NWB LIBRARY =====
[isInstalled, errMsg] = bst_plugin('Install', 'nwb');
if ~isInstalled
    error(errMsg);
end


%% ===== READ DATA HEADERS =====
% Read header
schemaVersion = util.getSchemaVersion(DataFile);
disp(['NWB file schema version: ' schemaVersion])

previous_directory = pwd;

% Do everything in the NWB directory - With every call of nwbRead a +types
% folder is created in the pwd for some reason
% Go in the tmp folder so the +types can be dumped
TmpDir = bst_get('BrainstormTmpDir', 0, 'nwb');
cd(TmpDir)

% Load the metadata
nwb2 = nwbRead(DataFile);
cd(previous_directory)

%% Make sure this is an extracellular NWB.
if isempty(nwb2.general_extracellular_ephys_electrodes)
    error('This is not an extracellular ephys NWB file. Only extracellular recordings are supported')
end

%% Get the keys of every time-series that is saved within NWB
all_TimeSeries_keys = keys(nwb2.searchFor('Timeseries', 'includeSubClasses'));
all_electricalSeries_keys = keys(nwb2.searchFor('electricalseries', 'includeSubClasses'));

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
ChannelsModuleStructure.nSamples  = [];
ChannelsModuleStructure.amp_channel_IDs = [];
ChannelsModuleStructure.groupLabels = [];
ChannelsModuleStructure.FlipMatrix = [];
ChannelsModuleStructure.timeBounds = [];
ChannelsModuleStructure.time_discontinuities = [];

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
        ChannelsModuleStructure(iModule).isElectrophysiology = true;
    else
        ChannelsModuleStructure(iModule).isElectrophysiology = false;
    end
end

% I reorder the structure - I prefer to have the electrophysiological
% signals first since in_fread_nwb will follow that order as well
putOnTop = ChannelsModuleStructure([ChannelsModuleStructure.isElectrophysiology]);
ChannelsModuleStructure([ChannelsModuleStructure.isElectrophysiology]) = [];
ChannelsModuleStructure = [putOnTop ChannelsModuleStructure];

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

% Check the number of channels
if ChannelsModuleStructure.nChannels > length(ChannelsModuleStructure.amp_channel_IDs)
    warning('More channels are found in raw data than in DynamicTable. Select channels according to DynamicTable.');
    ChannelsModuleStructure.nChannels = length(ChannelsModuleStructure.amp_channel_IDs);
end
nChannels = sum([ChannelsModuleStructure.nChannels]);

%% Check for epochs/trials
% [sFile, nEpochs] = in_trials_nwb(sFile, nwb2);
[sFile, nEpochs] = in_epochs_nwb(sFile, nwb2);

%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NWB channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
iElectrophysiologyModules = find([ChannelsModuleStructure.isElectrophysiology]);

groups = [];
for iModule = iElectrophysiologyModules
    groups = [groups ChannelsModuleStructure(iModule).groupLabels];
end

% Get semantic labels. The 'label' key might be specific to the dataset that we tested.
if isKey(nwb2.general_extracellular_ephys_electrodes.vectordata, 'label')
    labels = nwb2.general_extracellular_ephys_electrodes.vectordata.get('label').data.load; 
else
    labels = arrayfun(@(x) sprintf('amp%d', x), ChannelsModuleStructure.amp_channel_IDs, 'UniformOutput', 0);
end

% Get information of Good/Bad channels. The 'good' key might be specific to the dataset that we tested.
if isKey(nwb2.general_extracellular_ephys_electrodes.vectordata, 'good')  % 1 is good, 0 is bad
    ChannelFlag = nwb2.general_extracellular_ephys_electrodes.vectordata.get('good').data.load;
    ChannelFlag = ChannelFlag * 2 - 1;  % 1 is good, -1 is bad in BST
else
    ChannelFlag = ones(nChannels, 1);
end

try
    % Get coordinates and set to 0 if they are not available
    x = nwb2.general_extracellular_ephys_electrodes.vectordata.get('x').data.load'./1000; % NWB doesn't specify in what metric it saves
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
            ChannelMat.Channel(ii).Name    = labels{iChannel};
            ChannelMat.Channel(ii).Loc     = [x(iChannel);y(iChannel);z(iChannel)];
            ChannelMat.Channel(ii).Group   = groups{iChannel};  % dtype shoud be char
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
sFile.device       = 'NWB';
sFile.header.nwb   = nwb2;
sFile.comment      = nwb2.identifier;
sFile.prop.times   = [time(1), time(end)];
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag  = ChannelFlag;
sFile.header.ChannelType = ChannelType;

%% ===== READ EVENTS =====
events = in_events_nwb(sFile, nwb2, nEpochs, ChannelMat);

if ~isempty(events)
    % Import this list
    sFile = import_events(sFile, [], events);
end

end


function moduleStructure = getDeeperModule(nwb, DataKey)
    % Parse the key for processing signal check
    BehaviorDataKeyLabelParsed=regexp(DataKey,'/','split');      
        
    [obj, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = get_module(nwb.(BehaviorDataKeyLabelParsed{2}), DataKey, 2); % Don't change the number
    
    moduleStructure.path            = DataKey;
    moduleStructure.module          = obj;
    moduleStructure.Fs              = Fs;
    moduleStructure.nChannels       = nChannels;
    moduleStructure.nSamples        = nSamples;
    moduleStructure.FlipMatrix      = FlipMatrix;
    moduleStructure.timeBounds      = timeBounds;
    moduleStructure.time_discontinuities = time_discontinuities;
    
    
    % Get the amp_channel_ID and the GroupName of each channel
    % Get the ElectrodeID and the ElectrodeGroup of each channel
    if strcmp(class(obj),'types.core.ElectricalSeries')
        amp_channel_IDs = obj.electrodes.data.load + 1; % Python starts from 0
        
        electrodes_path = obj.electrodes.table.path;
        electrodes_path = strrep(electrodes_path(2:end), '/', '_');
        
        % Check if Channel IDs are provided
        if isprop(nwb.(electrodes_path), 'id')
            amp_channel_IDs = nwb.(electrodes_path).id.data.load + 1;
        end
        
        % Check if 'group_name' exist. If not, extract group names from other
        % key. The 'group' key here might be specific to the dataset that we tested.
        if isKey(nwb.(electrodes_path).vectordata, 'group_name')   
            not_ordered_groupLabels = nwb.(electrodes_path).vectordata.get('group_name').data.load; 
        else
            not_ordered_groupLabels = {nwb.(electrodes_path).vectordata.get('group').data.path};                     
            [~, not_ordered_groupLabels] = cellfun(@(x) fileparts(x), not_ordered_groupLabels', 'UniformOutput', 0);
        end
        
        moduleStructure.amp_channel_IDs = amp_channel_IDs;
        moduleStructure.groupLabels = not_ordered_groupLabels(amp_channel_IDs,:);

    else
        moduleStructure.amp_channel_IDs = [];
        moduleStructure.groupLabels = [];
    end
    
end


function [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = get_module(obj, DataKey, index)
    LabelParsed=regexp(DataKey,'/','split');
    index = index + 1;
    
    % Recursive search for timeseries - Once you hit the level that has
    % timeseries or electricalseries or spatialseries etc. return them

    if strcmp(class(obj),'types.core.LFP')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = get_module(obj.electricalseries, DataKey, index);
    elseif strcmp(class(obj),'types.core.ElectricalSeries')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = getFsnChannels(obj);
    elseif strcmp(class(obj),'types.core.Position')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = get_module(obj.spatialseries, DataKey, index);
    elseif strcmp(class(obj), 'types.core.ProcessingModule')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = get_module(obj.nwbdatainterface, DataKey, index);
    elseif strcmp(class(obj), 'types.core.SpatialSeries')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = getFsnChannels(obj);
    elseif strcmp(class(obj), 'types.core.BehavioralTimeSeries')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = get_module(obj.timeseries, DataKey, index);
    elseif strcmp(class(obj), 'types.core.TimeSeries')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = getFsnChannels(obj);
    elseif strcmp(class(obj), 'types.untyped.Set')
        [obj_return, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = get_module(obj.get(LabelParsed(index)), DataKey, index);
    
    % Known Input types to be ignored:
    elseif strcmp(class(obj), 'types.ndx_aibs_ecephys.EcephysCSD') || strcmp(class(obj), 'types.core.SpikeEventSeries') || ...
           strcmp(class(obj), 'types.core.DecompositionSeries') || strcmp(class(obj), 'types.core.AnnotationSeries') || ...
           strcmp(class(obj), 'types.core.CurrentClampSeries') || strcmp(class(obj), 'types.core.CurrentClampStimulusSeries') || ...
           strcmp(class(obj), 'types.core.OptogeneticSeries') || strcmp(class(obj), 'types.core.OptogeneticSeries')
       
        obj_return = [];
        Fs = 0;
        nChannels = 0;
        nSamples = 0;
        FlipMatrix = 0;
        timeBounds = [0,0];
        time_discontinuities = [];
    else
        % DEV NOTE: NWB Evolves and new types are coming out. If it's not a
        % core input that really needs to be included in Brainstorm, just
        % add it on the input types to be ignored right above
        error(['Unrecognized input type: ' class(obj)])
    end
%     if strcmp(class(obj), 'types.untyped.Anon')
%         obj_return = obj;
%     end
    
end


function [obj, Fs, nChannels, nSamples, FlipMatrix, timeBounds, time_discontinuities] = getFsnChannels(obj)
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
        if length(obj.data.dims)==1 % One dimensional signal
            nChannels = 1;
            nSamples = obj.data.dims(1);
            FlipMatrix = 0;
        else
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
    end
    
    % Compute Fs, timebounds and time_discontinuities (hopefully loading the entire time vector won't lead to time_discontinuities)
    % Is it does, a potential workaround would be to get intuition from the
    % epochs' timebounds.
    % I do this here so I don't have to search for them during in_fread_nwb
    % to avoid lagging
    if ~isempty(obj.starting_time_rate)
        Fs = obj.starting_time_rate;
        timeBounds = [obj.starting_time, obj.starting_time + nSamples/Fs];
        time_discontinuities = [];
    elseif ~isempty(obj.timestamps)
        % Some recordings save timepoints irregularly. Cant do
        % much about this when it comes to Brainstorm that uses a fixed
        % sampling rate
        Fs = round(mean(1./(diff(obj.timestamps.load(1,10))))); % Just load first 10 samples (consider a different approach here - there might be non-continuous segments)
        timeBounds = [obj.timestamps.load(1),obj.timestamps.load(end)];
        
        time = obj.timestamps.load;
        time_discontinuities = find(diff(time)>10/Fs); % 10 samples threshold is abstract
        time_discontinuities = [time(time_discontinuities) time(time_discontinuities+1)];
        
        % Remove the artificial discontinuity if the recording doesn't start from 0
        time_discontinuities = time_discontinuities(~ismember(time_discontinuities,[0 0],'rows'),:);
    else
        obj = [];
        Fs = 0;
        timeBounds = [0,0];
        time_discontinuities = [];
        error('Cant determine sampling rate for this module - Ignoring it')
    end
    
end
