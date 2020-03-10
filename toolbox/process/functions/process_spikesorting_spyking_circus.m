function varargout = process_spikesorting_spyking_circus( varargin )
% PROCESS_SPIKESORTING_SPYKING_CIRCUS:
% This process separates the initial raw signal to nChannels binary signals
% and performs spike sorting individually on each channel with the KiloSort
% spike-sorter. The spikes are clustered and assigned to individual
% neurons. The code ultimately produces a raw_elec(i)_spikes.mat
% for each electrode that can be used later for supervised spike-sorting.
% When all spikes on all electrodes have been clustered, all the spikes for
% each neuron is assigned to an events file in brainstorm format.
%
% USAGE: OutputFiles = process_spikesorting_spyking_circus('Run', sProcess, sInputs)

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
    sProcess.Comment     = 'Spyking Circus';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Electrophysiology','Unsupervised Spike Sorting'};
    sProcess.Index       = 1204;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/SpikeSorting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.options.spikesorter.Type   = 'text';
    sProcess.options.spikesorter.Value  = 'spykingCircus';
    sProcess.options.spikesorter.Hidden = 1;
    sProcess.options.binsize.Comment = 'Maximum RAM to use: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {2, 'GB', 1};
    % Options: Edit parameters
    sProcess.options.edit.Comment = {'panel_spikesorting_options', '<U><B>Parameters</B></U>: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % Show warning that pre-spikesorted events will be overwritten
    sProcess.options.warning.Comment = '<B><FONT color="#FF0000">Spike Events created from the acquisition system will be overwritten</FONT></B>';
    sProcess.options.warning.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    ProtocolInfo = bst_get('ProtocolInfo');

    % Not available in the compiled version
    if (exist('isdeployed', 'builtin') && isdeployed)
        error('This function is not available in the compiled version of Brainstorm.');
    end

    
    %% Compute on each raw input independently
    for i = 1:length(sInputs)
        [fPath, fBase] = bst_fileparts(sInputs(i).FileName);
        % Remove "data_0raw" or "data_" tag
        if (length(fBase) > 10 && strcmp(fBase(1:10), 'data_0raw_'))
            fBase = fBase(11:end);
        elseif (length(fBase) > 5) && strcmp(fBase(1:5), 'data_')
            fBase = fBase(6:end);
        end
        
        DataMat = in_bst_data(sInputs(i).FileName, 'F');
        ChannelMat = in_bst_channel(sInputs(i).ChannelFile);
        
        % Get the unique Montages / Shank that are present in the channel file
        Montages = unique({ChannelMat.Channel.Group});
        Montages = Montages(find(~cellfun(@isempty, Montages)));
        %% Make sure we perform the spike sorting on the channels that have spikes. IS THIS REALLY NECESSARY? it would just take longer

        numChannels = 0;
        for iChannel = 1:length(ChannelMat.Channel)
           if strcmp(ChannelMat.Channel(iChannel).Type,'EEG') || strcmp(ChannelMat.Channel(iChannel).Type,'SEEG')
              numChannels = numChannels + 1;               
           end
        end
        
        
        sFile = DataMat.F;
        events = DataMat.F.events;
        
% % % % % % % % % % % % %         %% %%%%%%%%%%%%%%%%%%% Prepare output folder %%%%%%%%%%%%%%%%%%%%%%        
% % % % % % % % % % % % %         outputPath = bst_fullfile(ProtocolInfo.STUDIES, fPath, [fBase '_kilosort_spikes']);
% % % % % % % % % % % % %         
% % % % % % % % % % % % %         % Clear if directory already exists
% % % % % % % % % % % % %         if exist(outputPath, 'dir') == 7
% % % % % % % % % % % % %             try
% % % % % % % % % % % % %                 rmdir(outputPath, 's');
% % % % % % % % % % % % %             catch
% % % % % % % % % % % % %                 error('Couldnt remove spikes folder. Make sure the current directory is not that folder.')
% % % % % % % % % % % % %             end
% % % % % % % % % % % % %         end
% % % % % % % % % % % % %         mkdir(outputPath);
        
        %% Convert the raw data to the right input for SpykingCircus
        bst_progress('start', 'SpykingCircus spike-sorting', 'Converting to SpykingCircus Input...');
        
        % Converting to int16. Using the same converter as for kilosort
        convertedRawFilename = in_spikesorting_convertforkilosort(sInputs(i), sProcess.options.binsize.Value{1} * 1e9); % This converts into int16.
        
        
        
        [convertedFilePath convertedFileBase convertedFileExtension] = fileparts(convertedRawFilename);
        
        
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Spike-sorting...');
        
        
        %% Initialize Spyking circus Parameters 
        Fs = DataMat.F.prop.sfreq;
        
        protocol = bst_get('ProtocolInfo');
        convertedFilePath = bst_fullfile(bst_get('BrainstormTmpDir'), ...
                                        'Unsupervised_Spike_Sorting', ...
                                        protocol.Comment, ...
                                        sInputs(i).FileName);
                                    
        % Create the prameters files
        deadFile = initializeDeadFile(convertedFileBase, convertedFilePath, events);
        probeFile = initializeProbeFile(convertedFileBase, convertedFilePath, ChannelMat);
        initializeSpykingCircusParameters(convertedFileBase, probeFile, deadFile, convertedFilePath, Fs)     
                
        %% ASK THE USER TO RUN SPYKING CIRCUS THROUGH A TERMINAL ON THEIR OWN ON WINDOWS MACHINES
        if ispc
            disp(' ')
            disp('########################################################')
            disp('Folder to run Spyking Circus from:')
            disp(convertedFilePath)
            disp('########################################################')
            disp(' ')

            isYes = java_dialog('confirm', ...
                ['SpykingCircus needs to be manually run on windows machines' 10 ...
                 'Please run it from the terminal outside of Matlab.' 10 10 ...
                 ['Files will be created within: ' convertedFilePath] 10 10 ...
                 'Has the Spyking Circus finished?'], 'Spyking Circus');
            
            if ~isYes
                bst_report('Error', sProcess, sInputs(i), 'Cancelled by user');
                return;
            end            
            % Check if the Spyking Circus files were created
            previousDirectory = pwd;
            cd(convertedFilePath)

        else
            previousDirectory = pwd;
            cd(convertedFilePath)
            spyking_circus_output = system(['spyking-circus ' [convertedFileBase convertedFileExtension]])
        end
        
            
        %% Now convert from SpykingCircus to Neuroscope (This is done so Klusters can be used for the supervised step)
        % Create the xml
        bst_progress('text', 'Converting to Neuroscope files...');

        createXML(ChannelMat, Fs, convertedFilePath, convertedFileBase)
        SpyCircus2Neuroscope(convertedFilePath, convertedFileBase, Fs);        
        
        %% %%%%%%%%%%%%%%%%%%%  Create Brainstorm Events %%%%%%%%%%%%%%%%%%%
        
        bst_progress('text', 'Saving events file...');
        
        % Delete existing spike events
        process_spikesorting_supervised('DeleteSpikeEvents', sInputs(i).FileName);        
        
        % Process: Import Neuroscope events
        theInput = sInputs(i).FileName;
        theInput = bst_process('CallProcess', 'process_events_import_Neuroscope', theInput, [], ...
            'neuroscopeFolder', {convertedFilePath, 'FreeSurfer'});

        %%
        
        % Fetch FET files
        spikes = [];
        if ~iscell(Montages)
            Montages = {Montages};
        end
        for iMontage = 1:length(Montages)
            fetFile = dir(bst_fullfile(convertedFilePath, ['*.fet.' num2str(iMontage)]));
            if isempty(fetFile)
                continue;
            end
            curStruct = struct();
            curStruct.Path = convertedFilePath;
            curStruct.File = fetFile.name;
            curStruct.Name = Montages{iMontage};
            curStruct.Mod  = 0;
            if isempty(spikes)
                spikes = curStruct;
            else
                spikes(end+1) = curStruct;
            end
        end
        
        % ===== SAVE LINK FILE =====
        % Build output filename
        NewBstFile = bst_fullfile(ProtocolInfo.STUDIES, fPath, ['data_0ephys_' fBase '.mat']);
        % Build output structure
        DataMat = struct();
        %DataMat.F          = sFile;
        DataMat.Comment     = 'Spyking Circus Spike Sorting';
        DataMat.DataType    = 'raw';%'ephys';
        DataMat.Device      = 'KiloSort';
        DataMat.Parent      = convertedFilePath;
        DataMat.Spikes      = spikes;
        DataMat.RawFile     = sInputs(i).FileName;
        DataMat.Name        = NewBstFile;
        % Add history field
        DataMat = bst_history('add', DataMat, 'import', ['Link to unsupervised electrophysiology files: ' convertedFilePath]);
        % Save file on hard drive
        bst_save(NewBstFile, DataMat, 'v6');
        % Add file to database
        sOutputStudy = db_add_data(sInputs(i).iStudy, NewBstFile, DataMat);
        % Return new file
        OutputFiles{end+1} = NewBstFile;

        % ===== UPDATE DATABASE =====
        % Update links
        db_links('Study', sInputs(i).iStudy);
        panel_protocols('UpdateNode', 'Study', sInputs(i).iStudy);
        
        % Go back to the previous directory
        cd(previousDirectory)

        
    end
    
end


function createXML(ChannelMat, Fs, convertedFilePath, convertedFileBase)


%% First check if any montages have been assigned
allMontages = {ChannelMat.Channel.Group};
nEmptyMontage = length(find(cellfun(@isempty,allMontages)));

if nEmptyMontage == length(ChannelMat.Channel)
    keepChannels = find(ismember({ChannelMat.Channel.Type}, 'EEG') | ismember({ChannelMat.Channel.Type}, 'SEEG'));
    
    % No montages have been assigned. Assign all EEG/SEEG channels to a
    % single montage
    for iChannel = 1:length(ChannelMat.Channel)
        if strcmp(ChannelMat.Channel(iChannel).Type, 'EEG') || strcmp(ChannelMat.Channel(iChannel).Type, 'SEEG')
            ChannelMat.Channel(iChannel).Group = 'GROUP1'; % Just adding an entry here
        end
    end
    temp_ChannelsMat = ChannelMat.Channel(keepChannels);

elseif nEmptyMontage == 0
    keepChannels = 1:length(ChannelMat.Channel);
    temp_ChannelsMat = ChannelMat.Channel(keepChannels);
else
    % ADD AN EXTRA MONTAGE FOR CHANNELS THAT HAVENT BEEN ASSIGNED TO A MONTAGE
    for iChannel = 1:length(ChannelMat.Channel)
        if isempty(ChannelMat.Channel(iChannel).Group)
            ChannelMat.Channel(iChannel).Group = 'EMPTYGROUP'; % Just adding an entry here
        end
        temp_ChannelsMat = ChannelMat.Channel;
    end
end


montages = unique({temp_ChannelsMat.Group},'stable');
montages = montages(find(~cellfun(@isempty, montages)));

NumChansPerProbe = [];

ChannelsInMontage  = cell(length(montages),2);
for iMontage = 1:length(montages)
    ChannelsInMontage{iMontage,1} = ChannelMat.Channel(strcmp({ChannelMat.Channel.Group}, montages{iMontage})); % Only the channels from the Montage should be loaded here to be used in the spike-events
    
    for iChannel = 1:length(ChannelsInMontage{iMontage})
        ChannelsInMontage{iMontage,2} = [ChannelsInMontage{iMontage,2} find(strcmp({ChannelMat.Channel.Name}, ChannelsInMontage{iMontage}(iChannel).Name))];
    end
    NumChansPerProbe = [NumChansPerProbe length(ChannelsInMontage{iMontage,2})];
end

nMontages = length(montages);



%% Define text components to assemble later
chunk1 = {'<?xml version=''1.0''?>';...
'<parameters version="1.0" creator="Brainstorm Converter">';...
' <acquisitionSystem>';...
['  <nBits> 16 </nBits>']};

channelcountlinestart = '  <nChannels>';
channelcountlineend = '</nChannels>';

chunk2 = {['  <samplingRate>' num2str(Fs) '</samplingRate>'];...
['  <voltageRange>20</voltageRange>'];...
['  <amplification>1000</amplification>'];...
'  <offset>0</offset>';...
' </acquisitionSystem>';...
' <fieldPotentials>';...
% % % % % ['  <lfpSamplingRate>' num2str(defaults.LfpSampleRate) '</lfpSamplingRate>'];...
['  <lfpSamplingRate>2500</lfpSamplingRate>'];...
' </fieldPotentials>';...
' <files>';...
'  <file>';...
'   <extension>lfp</extension>';...
% % % % % ['   <samplingRate>' num2str(defaults.LfpSampleRate) '</samplingRate>'];...
['   <samplingRate>2500</samplingRate>'];...
'  </file>';...
% '  <file>';...
% '   <extension>whl</extension>';...
% '   <samplingRate>39.0625</samplingRate>';...
% '  </file>';...
' </files>';...
' <anatomicalDescription>';...
'  <channelGroups>'};

anatomygroupstart = '   <group>';%repeats w every new anatomical group
anatomychannelnumberline_start = ['    <channel skip="0">'];%for each channel in an anatomical group - first part of entry
anatomychannelnumberline_end = ['</channel>'];%for each channel in an anatomical group - last part of entry
anatomygroupend = '   </group>';%comes at end of each anatomical group

chunk3 = {' </channelGroups>';...
  '</anatomicalDescription>';...
 '<spikeDetection>';...
  ' <channelGroups>'};%comes after anatomical groups and before spike groups

spikegroupstart = {'  <group>';...
        '   <channels>'};%repeats w every new spike group
spikechannelnumberline_start = ['    <channel>'];%for each channel in a spike group - first part of entry
spikechannelnumberline_end = ['</channel>'];%for each channel in a spike group - last part of entry
spikegroupend = {'   </channels>';...
%    ['    <nSamples>' num2str(defaults.PointsPerWaveform) '</nSamples>'];...
%    ['    <peakSampleIndex>' num2str(defaults.PeakPointInWaveform) '</peakSampleIndex>'];...
%    ['    <nFeatures>' num2str(defaults.FeaturesPerWave) '</nFeatures>'];...
   ['    <nSamples>40</nSamples>'];...
   ['    <peakSampleIndex>16</peakSampleIndex>'];...
   ['    <nFeatures>3</nFeatures>'];...
    '  </group>'};%comes at end of each spike group

chunk4 = {' </channelGroups>';...
 '</spikeDetection>';...
 '<neuroscope version="2.0.0">';...
  '<miscellaneous>';...
   '<screenGain>0.2</screenGain>';...
   '<traceBackgroundImage></traceBackgroundImage>';...
  '</miscellaneous>';...
  '<video>';...
   '<rotate>0</rotate>';...
   '<flip>0</flip>';...
   '<videoImage></videoImage>';...
   '<positionsBackground>0</positionsBackground>';...
  '</video>';...
  '<spikes>';...
  '</spikes>';...
  '<channels>'};

channelcolorstart = ' <channelColors>';...
channelcolorlinestart = '  <channel>';
channelcolorlineend = '</channel>';
channelcolorend = {'  <color>#0080ff</color>';...
    '  <anatomyColor>#0080ff</anatomyColor>';...
    '  <spikeColor>#0080ff</spikeColor>';...
   ' </channelColors>'};

channeloffsetstart = ' <channelOffset>';
channeloffsetlinestart = '  <channel>';
channeloffsetlineend = '</channel>';
channeloffsetend = {'  <defaultOffset>0</defaultOffset>';...
   ' </channelOffset>'};

chunk5 = {   '</channels>';...
 '</neuroscope>';...
'</parameters>'};


%% Make basic text 
s = chunk1;
s = cat(1,s,[channelcountlinestart, num2str(length(ChannelMat.Channel)) channelcountlineend]);
s = cat(1,s,chunk2);

%add channel count here

for iMontage = 1:nMontages%for each probe
    s = cat(1,s,anatomygroupstart);
    for iChannelWithinMontage = 1:NumChansPerProbe(iMontage)%for each spike group
        thischan = ChannelsInMontage{iMontage,2}(iChannelWithinMontage) - 1;
        s = cat(1,s,[anatomychannelnumberline_start, num2str(thischan) anatomychannelnumberline_end]);
    end
    s = cat(1,s,anatomygroupend);
end

s = cat(1,s,chunk3);

for iMontage = 1:nMontages
    s = cat(1,s,spikegroupstart);
    for iChannelWithinMontage = 1:NumChansPerProbe(iMontage)
        thischan = ChannelsInMontage{iMontage,2}(iChannelWithinMontage) - 1;
        s = cat(1,s,[spikechannelnumberline_start, num2str(thischan) spikechannelnumberline_end]);
    end
    s = cat(1,s,spikegroupend);
end

s = cat(1,s, chunk4);

for iMontage = 1:nMontages
    for iChannelWithinMontage = 1:NumChansPerProbe(iMontage)
        s = cat(1,s,channelcolorstart);
        thischan = ChannelsInMontage{iMontage,2}(iChannelWithinMontage) - 1;
        s = cat(1,s,[channelcolorlinestart, num2str(thischan) channelcolorlineend]);
        s = cat(1,s,channelcolorend);
        s = cat(1,s,channeloffsetstart);
        s = cat(1,s,[channeloffsetlinestart, num2str(thischan) channeloffsetlineend]);
        s = cat(1,s,channeloffsetend);
    end
end

s = cat(1,s, chunk5);

%% Output
charcelltotext(s,fullfile(convertedFilePath,[convertedFileBase '.xml']));
end

function charcelltotext(charcell,filename)
%based on matlab help.  Writes each row of the character cell (charcell) to a line of
%text in the filename specified by "filename".  Char should be a cell array 
%with format of a 1 column with many rows, each row with a single string of
%text.

[nrows,ncols]= size(charcell);

fid = fopen(filename, 'w');

for row=1:nrows
    fprintf(fid, '%s \n', charcell{row,:});
end

fclose(fid);
end

