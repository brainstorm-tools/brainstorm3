function varargout = process_events_import_Neuroscope( varargin )
% PROCESS_CHANNEL_SETSEEG: Convert Neuroscope events to Brainstorm and
% attach them to the "link to raw file"

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
% Authors: Konstantinos Nasiotis, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import Neuroscope events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Peyrache Lab', 'Ripples'};
    sProcess.Index       = 2224;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import anatomy folder...', ...    % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'AnatIn'), ... % Available file formats
        'AnatIn'};                         % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Option: Neuroscope Folder
    sProcess.options.neuroscopeFolder.Comment = 'Folder to import:';
    sProcess.options.neuroscopeFolder.Type    = 'filename';
    sProcess.options.neuroscopeFolder.Value   = SelectOptions;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    
    
    if length(sInput)>1
        error('This function can only be used on a single file. Don''t add more in the processing window');
    end
    
    % Get options
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', [sInput.iStudy]);
    iChanStudies = unique(iChanStudies);
 
    % Get channel study
    sStudy = bst_get('Study', iChanStudies);
    if isempty(sStudy.Channel)
        bst_report('Error', sProcess, [], 'No channel file available.');
        return
    end
    % Read channel file
    ChannelFile = sStudy.Channel(1).FileName;
    DataMat = in_bst_data(sInput.FileName);
    
    % Get channel file
    [sStudy, iStudy] = bst_get('ChannelFile', ChannelFile);
    
    
    
    %% Load channel file
    ChannelFile = file_fullpath(ChannelFile);
    ChannelMat = in_bst_channel(ChannelFile);        
    
    folder = sProcess.options.neuroscopeFolder.Value{1};
    
    Fs = DataMat.F.prop.sfreq;
    
    
    %% Get the unique Montages / Shank that are present in the channel file
    montages = unique({ChannelMat.Channel.Group});
    montages = montages(find(~cellfun(@isempty, montages)));

    %% Get the number of Montages that exist in the Neuroscope files
    directoryContents = dir(folder);

    iCluFiles = find(contains({directoryContents.name}, '.clu.'));
    iResFiles = find(contains({directoryContents.name}, '.res.'));
    % iFetFiles = find(contains({directoryContents.name}, '.fet'));
    nMontages = length(iCluFiles); % How many "montages exist"


    if (length(iCluFiles)~= length(iResFiles)) || length(montages) ~= length(iCluFiles)
        error('Something is off. You should have the same number of files for .res, .fet, .res filetypes and also the same number of Montages')
    elseif length(iCluFiles)==0
        error('No files found. Probably the wrong folder was selected.')
    end


    %% Start converting
    events = struct();
    index = 0;

    for iMontage = 1:nMontages

        % Information about the Neuroscope file can be found here:
        % http://neurosuite.sourceforge.net/formats.html

        %% Load necessary files
        % Extract filename from 'filename.fet.1'

        general_file = fullfile(directoryContents(1).folder, directoryContents(iCluFiles(1)).name);
        general_file = general_file(1:end-5);

        clu = load([general_file 'clu.' num2str(iMontage);]);
        res = load([general_file 'res.' num2str(iMontage);]);
        fet = dlmread([general_file 'fet.' num2str(iMontage);]);

        ChannelsInMontage = ChannelMat.Channel(strcmp({ChannelMat.Channel.Group}, montages{iMontage})); % Only the channels from the Montage should be loaded here to be used in the spike-events

        %% The combination of the .clu files and the .fet file is enough to use on the converter.

        % Brainstorm assign each spike to a SINGLE NEURON on each electrode. This
        % converter picks up the electrode that showed the strongest (absolute)
        % component on the .fet file and assigns the spike to that electrode. Consecutively, it
        % checks the .clu file to assign the spike to a specific neuron. If more
        % than one clusters are assigned to that electrode, different labels will
        % be created for each neuron.

        iChannels = zeros(size(fet,1),1);
        for iSpike = 2:size(fet,1) % The first entry will be zeros. Ignore
            [tmp,iPCA] = max(abs(fet(iSpike,1:end-3)));
            iChannels(iSpike) = ceil(iPCA/3);
        end

        % Now iChannels holds the Channel that each spike belongs to, and clu
        % holds the cluster that each spike belongs to. Assign unique labels to
        % multiple neurons on the same electrode.

        % Initialize output structure

        spikesPrefix = process_spikesorting_supervised('GetSpikesEventPrefix');

        uniqueClusters = unique(clu(2:end))'; % The first entry is just the number of clusters

        for iCluster = 1:length(uniqueClusters)
            selectedSpikes = find(clu==uniqueClusters(iCluster));

            [tmp,iMaxFeature] = max(sum(abs(fet(selectedSpikes,1:end-3))));
            iElectrode = ceil(iMaxFeature/3);

            index = index+1;
            % Write the packet to events
            if uniqueClusters(iCluster)==0
                events(index).label       = ['Spikes Noise ' montages{iMontage} ' |' num2str(uniqueClusters(iCluster)) '|'];
            elseif uniqueClusters(iCluster)==1
                events(index).label       = ['Spikes MUA ' montages{iMontage} ' |' num2str(uniqueClusters(iCluster)) '|'];
            else
                events(index).label       = [spikesPrefix ' ' ChannelsInMontage(iElectrode).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
            end
            events(index).color       = rand(1,3);
            events(index).times       = fet(selectedSpikes,end)' ./ Fs;  % The timestamps are in SAMPLES
            events(index).epochs      = ones(1,length(events(index).times));
            events(index).reactTimes  = [];
            events(index).select      = 1;
            events(index).channels    = cell(1, size(events(index).times, 2));
            events(index).notes       = cell(1, size(events(index).times, 2));
        end




    end
    
    %% Attach the events to the raw file
    % Load the raw file descriptor
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F');
        sFile = DataMat.F;
    else
        sFile = in_fopen(sInput.FileName, 'BST-DATA');
    end
    
    
    newEvents = events;

    % Fix events structure
    if ~isempty(newEvents)
        newEvents = struct_fix_events(newEvents);
    end
    if ~isempty(sFile.events)
        sFile.events = struct_fix_events(sFile.events);
    end

    
    %% ===== MERGE EVENTS LISTS =====
    % Add each new event
    for iNew = 1:length(newEvents)
        % Look for an existing event
        if ~isempty(sFile.events)
            iEvt = find(strcmpi(newEvents(iNew).label, {sFile.events.label}));
        else
            iEvt = [];
        end
        % Make sure that the sample indices are round values
        newEvents(iNew).times = round(newEvents(iNew).times * sFile.prop.sfreq) ./ sFile.prop.sfreq;
        % If event does not exist yet: add it at the end of the list
        if isempty(iEvt)
            if isempty(sFile.events)
                iEvt = 1;
                sFile.events = newEvents(iNew);
            else
                iEvt = length(sFile.events) + 1;
                sFile.events(iEvt) = newEvents(iNew);
            end
        % Event exists: merge occurrences
        else
            % Convert new event type if required
            sizeTimeWindow = size(sFile.events(iEvt).times, 1);
            sizeNewTimeWindow = size(newEvents(iNew).times, 1);
            if sizeTimeWindow ~= sizeNewTimeWindow
                if sizeTimeWindow == 1
                    % Convert to single event
                    disp(['BST> Warning: Event type of "', ...
                         sFile.events(iEvt).label, ...
                         '" inconsistent, converting to single event using start time.']);
                    newEvents(iNew).times = newEvents(iNew).times(1,:);
                else
                    % Convert to extended event
                    disp(['BST> Warning: Event type of "', ...
                         sFile.events(iEvt).label, ...
                         '" inconsistent, converting to extended event.']);
                    newEvents(iNew).times = [newEvents(iNew).times; newEvents(iNew).times + 0.001];
                end
            end
            % Merge events occurrences
            sFile.events(iEvt).times      = [sFile.events(iEvt).times, newEvents(iNew).times];
            sFile.events(iEvt).epochs     = [sFile.events(iEvt).epochs, newEvents(iNew).epochs];
            sFile.events(iEvt).reactTimes = [sFile.events(iEvt).reactTimes, newEvents(iNew).reactTimes];
            sFile.events(iEvt).channels   = [sFile.events(iEvt).channels, newEvents(iNew).channels];
            sFile.events(iEvt).notes      = [sFile.events(iEvt).notes, newEvents(iNew).notes];
            % Sort by time
            if (size(sFile.events(iEvt).times, 2) > 1)
                [tmp__, iSort] = unique(bst_round(sFile.events(iEvt).times(1,:), 9));
                sFile.events(iEvt).times   = sFile.events(iEvt).times(:,iSort);
                sFile.events(iEvt).epochs  = sFile.events(iEvt).epochs(iSort);
                if ~isempty(sFile.events(iEvt).reactTimes)
                    sFile.events(iEvt).reactTimes = sFile.events(iEvt).reactTimes(iSort);
                end
                sFile.events(iEvt).channels = sFile.events(iEvt).channels(iSort);
                sFile.events(iEvt).notes = sFile.events(iEvt).notes(iSort);
            end
        end
        % Add color if does not exist yet
        if isempty(sFile.events(iEvt).color)
            % Get the default color for this new event
            % sFile.events(iEvt).color = panel_record('GetNewEventColor', iEvt, sFile.events);

            % Same code, but without dependencies
            AllEvents = sFile.events;
            ColorTable = ...
                [0     1    0   
                .4    .4    1
                 1    .6    0
                 0     1    1
                .56   .01  .91
                 0    .5    0
                .4     0    0
                 1     0    1
                .02   .02   1
                .5    .5   .5];
            % Attribute the first color that of the colortable that is not in the existing events
            for iColor = 1:length(ColorTable)
                if isempty(AllEvents) || ~isstruct(AllEvents) || ~any(cellfun(@(c)isequal(c, ColorTable(iColor,:)), {AllEvents.color}))
                    break;
                end
            end
            % If all the colors of the color table are taken: attribute colors cyclically
            if (iColor == length(ColorTable))
                iColor = mod(iEvt-1, length(ColorTable)) + 1;
            end
            sFile.events(iEvt).color = ColorTable(iColor,:);
        end
    end

    
    %%
    
    % Only save changes if something was change
    if ~isempty(newEvents)
        % Report changes in .mat structure
        if isRaw
            DataMat.F = sFile;
        else
            DataMat.Events = sFile.events;
        end
        % Save file definition
        bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
        % Report number of detected events
        bst_report('Info', sProcess, sInput, sprintf('Added to file: %d events in %d different categories', size([newEvents.epochs],2), length(newEvents)));
    else
        bst_report('Error', sProcess, sInput, 'No events read from file.');
    end
    
    
    

    % Return all the files in input
    OutputFiles = {sInput.FileName};
end


%% ===== CONVERT =====
function Compute(ChannelFile)
    % Get channel file
    [sStudy, iStudy] = bst_get('ChannelFile', ChannelFile);
    % Load channel file
    ChannelFile = file_fullpath(ChannelFile);
    ChannelMat = in_bst_channel(ChannelFile);        
    % Get channels classified as EEG
    iEEG = channel_find(ChannelMat.Channel, 'EEG,SEEG,ECOG,ECG,EKG');
    % If there are no channels classified at EEG, take all the channels
    if isempty(iEEG)
        warning('Warning: No EEG channels identified, trying to use all the channels...');
        iEEG = 1:length(ChannelMat.Channel);
    end
    % Detect channels of interest
    [iSelEeg, iEcg] = ImaGIN_select_channels({ChannelMat.Channel(iEEG).Name}, 1);
    % Set channels as SEEG
    if ~isempty(iSelEeg)
        [ChannelMat.Channel(iEEG(iSelEeg)).Type] = deal(Modality);
    end
    if ~isempty(iEcg)
        [ChannelMat.Channel(iEEG(iEcg)).Type] = deal('ECG');
    end
    % Save modified file
    bst_save(ChannelFile, ChannelMat, 'v7');
    % Update database reference
    [sStudy.Channel.Modalities, sStudy.Channel.DisplayableSensorTypes] = channel_get_modalities(ChannelMat.Channel);
    bst_set('Study', iStudy, sStudy);
end

