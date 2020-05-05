function [sFile, ChannelMat] = in_fopen_tdt(DataFile)

%% IN_FOPEN_TDT: Open recordings saved in the Tucker Davis Technologies format

% The importer needs the folder that the files are in. I selected one type
% of files to work as the "raw file" - (.Tbk)


 %% 
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
% Author: Konstantinos Nasiotis 2019


% Not available in the compiled version
if (exist('isdeployed', 'builtin') && isdeployed)
    error('Reading TDT files is not available in the compiled version of Brainstorm.');
end


 %% ===== GET FILES =====
% Get base dataset folder
[DataFolder, FileName] = bst_fileparts(DataFile);

hdr.BaseFolder = DataFolder;




 %% ===== FILE COMMENT =====
% Comment: BaseFolder
Comment = DataFolder;




 %% Check if the TDT builder has already been downloaded and properly set up
if exist('TDTbin2mat','file') ~= 2
    isOk = java_dialog('confirm', ...
        ['The Tucker Davis Technologies SDK is not installed on your computer.' 10 10 ...
             'Download and install the latest version?'], 'Tucker Davis Technologies');
    if ~isOk
        bst_report('Error', sProcess, sInputs, 'This process requires the Tucker Davis Technologies SDK.');
        return;
    end
    downloadAndInstallTDT()
end






%% ===== READ DATA HEADERS =====

% Load one second segment to see what type of signals exist in this dataset
% Use as general sampling rate the rate of the HIGHEST sampled signal
% The signals that have a lower sampling rate will be interpolated to match
% the general sampling rate

headers = TDTbin2mat(DataFolder, 'HEADERS', 1);

data = TDTbin2mat(DataFolder, 'T1', 0, 'T2', 1); % 1 second segment
all_streams = fieldnames(data.streams);

several_sampling_rates = [];
total_channels         = [];

% The sampling rates present are the weirdest numbers I have ever seen:
% e.g. Fs = 3051.7578125 Hz !!!
% Those numbers create problems when loading segments of data.
% The segment loading is in TimeBounds, not SampleBounds that makes it even
% worse with those sampling rates
for iStream = 1:length(all_streams)
    several_sampling_rates = [several_sampling_rates data.streams.(all_streams{iStream}).fs];
    total_channels         = [total_channels, size(data.streams.(all_streams{iStream}).data,1)];
end

[general_sampling_rate iHighestSampledChannel] = max(several_sampling_rates);

nChannels = sum(total_channels);

 %% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');



 % Add information read from header
sFile.prop.sfreq   =  general_sampling_rate;
sFile.byteorder    = 'l';
sFile.filename     = DataFolder;
sFile.format       = 'EEG-TDT';
sFile.device       = 'Tucker Davis Technologies';
sFile.header.tdt   = headers;
sFile.comment      = FileName;
sFile.prop.times   = [0, headers.stopTime-headers.startTime];
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag  = ones(nChannels, 1);

sFile.header.several_sampling_rates = several_sampling_rates;
sFile.header.total_channels         = total_channels;
sFile.header.all_streams            = all_streams;

 %% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'TDT channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);

ii = 0;
for iStream = 1:length(all_streams)
     for iChannel = 1:total_channels(iStream)
         ii = ii+1;
         if ~(total_channels(iStream)==1)
            ChannelMat.Channel(ii).Name = [all_streams{iStream} '_' num2str(iChannel)];
         else
             ChannelMat.Channel(ii).Name= [all_streams{iStream}];
         end
         ChannelMat.Channel(ii).Loc     = [0;0;0];

         ChannelMat.Channel(ii).Group   = all_streams{iStream};
         
         if ~(total_channels(iStream) == 1)
            ChannelMat.Channel(ii).Type = 'EEG'; % Not all are EEGs - NOT SURE WHAT TO PUT HERE - AS A STARTING POINT, I PUT WHATEVER IS ONLY ONE CHANNEL SET IT AS Misc
         else
            ChannelMat.Channel(ii).Type = 'Misc';
         end
         ChannelMat.Channel(ii).Orient  = [];
         ChannelMat.Channel(ii).Weight  = 1;
         ChannelMat.Channel(ii).Comment = [];
     end
end


%% Check for acquisition events

NO_data = TDTbin2mat(DataFolder, 'NODATA',1); % Memory Management???

are_there_events = ~isempty(NO_data.epocs);

if are_there_events
    
    all_event_Labels = fieldnames(NO_data.epocs);
    
    iindex = 0;

    for iEvent = 1:length(all_event_Labels)
        
        if sum(ismember({'Tick','Swep','Swe+'},NO_data.epocs.(all_event_Labels{iEvent}).name))~=0
            iindex = iindex + 1;
            
            events(iindex).label      = NO_data.epocs.(all_event_Labels{iEvent}).name;
            events(iindex).color      = rand(1,3);
            events(iindex).epochs     = ones(1,length(NO_data.epocs.(all_event_Labels{iEvent}).onset))  ;
            events(iindex).times      = round(NO_data.epocs.(all_event_Labels{iEvent}).onset' .* general_sampling_rate) ./ general_sampling_rate;
            events(iindex).reactTimes = [];
            events(iindex).select     = 1;
            events(iindex).channels   = cell(1, size(events(iindex).times, 2));
            events(iindex).notes      = cell(1, size(events(iindex).times, 2));
        else
            conditions_in_event = unique(NO_data.epocs.(all_event_Labels{iEvent}).data);
            
            for iCondition = 1:length(conditions_in_event)
                
                selected_Events_for_condition = find(NO_data.epocs.(all_event_Labels{iEvent}).data == conditions_in_event(iCondition));
                
                iindex = iindex+1;
                
                events(iindex).label      = [NO_data.epocs.(all_event_Labels{iEvent}).name num2str(conditions_in_event(iCondition))];
                events(iindex).color      = rand(1,3);
                events(iindex).epochs     = ones(1,length(selected_Events_for_condition))  ;
                events(iindex).times      = round(NO_data.epocs.(all_event_Labels{iEvent}).onset(selected_Events_for_condition)' .* general_sampling_rate) ./ general_sampling_rate;
                events(iindex).reactTimes = [];
                events(iindex).select     = 1;
                events(iindex).channels   = cell(1, size(events(iindex).times, 2));
                events(iindex).notes      = cell(1, size(events(iindex).times, 2));
            end
        end
    end
end
    
    
%% Check for spike events

are_there_spikes = ~isempty(NO_data.snips);

if  ~exist ('events','var')
    events = struct;
    last_event_index = 0;
else
    last_event_index = length(events);
end


if are_there_spikes
    all_spike_event_Labels = fieldnames(NO_data.snips);
    channels_are_EEG = find(strcmp({ChannelMat.Channel.Type}, 'EEG'));

    for iSpikeDetectedField = 1:length(all_spike_event_Labels)
        
        for iChannel = 1:length(channels_are_EEG)
            
            NeuronIDs = unique(NO_data.snips.(all_spike_event_Labels{iSpikeDetectedField}).sortcode(find(NO_data.snips.(all_spike_event_Labels{iSpikeDetectedField}).chan == iChannel)));
            
            if length(NeuronIDs)>1 && sum(ismember(NeuronIDs,0))~=0
                warning('There are Sorted AND Unsorted Spikes in this Dataset - Probably the selection for Online sorting was made mid-Recording - THE UNSORTED SPIKES WILL BE IGNORED')
                NeuronIDs = NeuronIDs(~ismember(NeuronIDs,[0,31]));
            else
                NeuronIDs = NeuronIDs(~ismember(NeuronIDs, 31));
            end
           
            for iNeuron = 1:length(NeuronIDs)
                
                if NeuronIDs(iNeuron) ~= 31 && (length(NeuronIDs) > 1 && NeuronIDs(iNeuron) ~= 0) % MARYSE MENTIONED THAT .DATA = 31 INDICATES ARTIFACTS - NOISE
                
                    last_event_index = last_event_index + 1;

                    if length(NeuronIDs) == 1
                        SpikesOfThatNeuronOnChannel_Indices = find(NO_data.snips.(all_spike_event_Labels{iSpikeDetectedField}).chan == iChannel & NO_data.snips.(all_spike_event_Labels{iSpikeDetectedField}).sortcode == 0); % Unsorted
                        events(last_event_index).label = ['Spikes Channel ' ChannelMat.Channel(channels_are_EEG(iChannel)).Name];
                    else
                        SpikesOfThatNeuronOnChannel_Indices = find(NO_data.snips.(all_spike_event_Labels{iSpikeDetectedField}).chan == iChannel & NO_data.snips.(all_spike_event_Labels{iSpikeDetectedField}).sortcode == iNeuron); % Sorted
                        events(last_event_index).label = ['Spikes Channel ' ChannelMat.Channel(channels_are_EEG(iChannel)).Name ' |' num2str(iNeuron) '|'];                    
                    end

                    events(last_event_index).color      = rand(1,3);
                    events(last_event_index).epochs     = ones(1,length(SpikesOfThatNeuronOnChannel_Indices));
                    events(last_event_index).times      = round(events(NO_data.snips.(all_spike_event_Labels{iSpikeDetectedField}).ts(SpikesOfThatNeuronOnChannel_Indices)' .* general_sampling_rate)) ./ general_sampling_rate;
                    events(last_event_index).reactTimes = [];
                    events(last_event_index).select     = 1;
                    events(last_event_index).channels   = cell(1, size(events(last_event_index).times, 2));
                    events(last_event_index).notes      = cell(1, size(events(last_event_index).times, 2));
                end
            end
        end
    end
end

% Import this list
sFile = import_events(sFile, [], events);
end








 function downloadAndInstallTDT()

    TDTDir = bst_fullfile(bst_get('BrainstormUserDir'), 'TDT');
    TDTTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'TDT_tmp');
    url = 'https://www.tdt.com/support/examples/TDTMatlabSDK.zip';
    % If folders exists: delete
    if isdir(TDTDir)
        file_delete(TDTDir, 1, 3);
    end
    if isdir(TDTTmpDir)
        file_delete(TDTTmpDir, 1, 3);
    end
    % Create folder
	mkdir(TDTTmpDir);
    % Download file
    zipFile = bst_fullfile(TDTTmpDir, 'TDT.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'TDT download');
    
    
    % Check if the download was succesful and try again if it wasn't
    time_before_entering = clock;
    updated_time = clock;
    time_out = 60;% timeout within 60 seconds of trying to download the file
    
    % Keep trying to download until a timeout is reached
    while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
        % Try to download until the timeout is reached
        pause(0.1);
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'TDT download');
        updated_time = clock;
    end
    % If the timeout is reached and there is still an error, abort
    if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
        error(['Impossible to download TDT.' 10 errMsg]);
    end
    
    % Unzip file
    bst_progress('start', 'TDT', 'Installing TDT...');
    unzip(zipFile, TDTTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(TDTTmpDir);
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}));
    idir = idir(find(strcmp({diropen(idir).name}, 'TDTSDK')));
    
    newTDTDir = bst_fullfile(TDTTmpDir, diropen(idir).name, 'TDTbin2mat');
    % Move TDT directory to proper location
    file_move(newTDTDir, TDTDir);
    % Delete unnecessary files
    file_delete(TDTTmpDir, 1, 3);
    % Add TDT to Matlab path
    addpath(genpath(TDTDir));

 end





