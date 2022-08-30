function F = in_fread_nwb(sFile, iEpoch, SamplesBounds, selectedChannels, isContinuous)
% IN_FREAD_NWB Read a block of recordings from nwb files
%
% USAGE:  F = in_fread_nwb(sFile, SamplesBounds=[], iChannels=[])

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
% Author: Konstantinos Nasiotis 2019-2020


% Parse inputs
if (nargin < 3) || isempty(selectedChannels)
    selectedChannels = 1:length(sFile.channelflag);
end
nTotalChannels = length(selectedChannels);

% Install/load NWB library
[isInstalled, errMsg, PlugDesc] = bst_plugin('Install', 'nwb');
if ~isInstalled
    error(errMsg);
end
NWBDir = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder);


%% Load everything from the NWB directory

previous_directory = pwd;
cd(NWBDir);

%% Load the nwbFile object that holds the info of the .nwb
nwb2 = sFile.header.nwb; % Having the header saved, saves a ton of time instead of reading the .nwb from scratch

ChannelsModuleStructure = sFile.header.ChannelsModuleStructure;

% % If time for the ephys signals doesnt start from 0, adjust
% samples_adjustment = 0;
% for iModule = 1:length(ChannelsModuleStructure)
%     if ChannelsModuleStructure(iModule).isElectrophysiology
%         samples_adjustment = round(ChannelsModuleStructure(iModule).timeBounds(1)*ChannelsModuleStructure(iModule).Fs) - 1;
%     end
% end
% SamplesBounds = SamplesBounds - samples_adjustment;


%% Assign the bounds based on the trials or the continuous selection
if isempty(SamplesBounds) && isContinuous
    SamplesBounds = round(sFile.prop.times.* sFile.prop.sfreq);
    timeBounds    = SamplesBounds./sFile.prop.sfreq;
elseif (~isempty(SamplesBounds) && isContinuous) || (~isempty(SamplesBounds) && ~isContinuous)
    timeBounds    = SamplesBounds./sFile.prop.sfreq;
elseif isempty(SamplesBounds) && ~isContinuous
    iEpoch = double(iEpoch);
    % Get sample bounds
    all_TrialsTimeBounds = double([nwb2.intervals_epochs.start_time.data.load nwb2.intervals_epochs.stop_time.data.load]);
    timeBounds = all_TrialsTimeBounds(iEpoch,:);
    SamplesBounds = round(timeBounds.* sFile.prop.sfreq);    
end

nSamples = SamplesBounds(2) - SamplesBounds(1);

Fs = sFile.prop.sfreq;
timeBounds = SamplesBounds./Fs;

%% Get the signals

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% HERE THE ASSUMPTION IS THAT THE LABELING OF THE CHANNELS HAS NOT CHANGED
% FROM WHAT THE IMPORTER POPULATED
% This could lead to problems
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

F = zeros(nTotalChannels, nSamples+1);

iiCh = 0;
for iModule = 1:length(ChannelsModuleStructure)
    nModuleChannels = ChannelsModuleStructure(iModule).nChannels;
    
    % First check if the segment requested is within the
    % discontinuities of the signal. If it is, fill the F matrix with
    % NaNs - Maybe Consider zeros
    time_discontinuities = ChannelsModuleStructure(iModule).time_discontinuities;

    entireRequestedSegmentWithinDiscontinuity  = false;
    partialRequestedSegmentWithinDiscontinuity = false;

    if ~isempty(time_discontinuities)
        for iDiscontinuity = 1:size(time_discontinuities,1)
            if time_discontinuities(iDiscontinuity,1)<timeBounds(1) && time_discontinuities(iDiscontinuity,2)>timeBounds(2)
                entireRequestedSegmentWithinDiscontinuity = true;
                F(iiCh+1:iiCh + nModuleChannels,:) = nan(nModuleChannels, nSamples+1);
                break
            elseif (time_discontinuities(iDiscontinuity,1)<timeBounds(1) && timeBounds(2)>time_discontinuities(iDiscontinuity,1) && timeBounds(2)<time_discontinuities(iDiscontinuity,2))...
                || (time_discontinuities(iDiscontinuity,1)<timeBounds(1) && timeBounds(1)<time_discontinuities(iDiscontinuity,2) && timeBounds(2)>time_discontinuities(iDiscontinuity,2))

                % The following can potentially be improved by assigning
                % part of the signal to NaNs and keeping the rest. Ignoring
                % for now
                partialRequestedSegmentWithinDiscontinuity = true;
                F(iiCh+1:iiCh + nModuleChannels,:) = nan(nModuleChannels, nSamples+1);
                break
            end
        end
    end
    
    if ~entireRequestedSegmentWithinDiscontinuity && ~partialRequestedSegmentWithinDiscontinuity

        % The following code takes into account annoying discontinuities
        % that can occur even during the electrophysiological recordings (examples are the neuropixel Dandi recordings)
        % The sampleBounds are different
        if ~isempty(ChannelsModuleStructure(iModule).module.timestamps)
            actual_timestamps = ChannelsModuleStructure(iModule).module.timestamps.load;
        elseif ~isempty(ChannelsModuleStructure(iModule).module.starting_time_rate)
            actual_timestamps = linspace(ChannelsModuleStructure(iModule).module.starting_time, ChannelsModuleStructure(iModule).module.starting_time+ ChannelsModuleStructure(iModule).nSamples/ChannelsModuleStructure(iModule).Fs,ChannelsModuleStructure(iModule).nSamples);
        end

        selectedTimestampsIndices = find(actual_timestamps>=timeBounds(1) & actual_timestamps<=timeBounds(2));
        if ~isempty(selectedTimestampsIndices)
            SampleBoundsModule = [selectedTimestampsIndices(1) selectedTimestampsIndices(end)];
        else
            SampleBoundsModule = [0, 0];
        end
        
        % In case I reach the edge of the recording - adjust
        reached_edge = false;
        if SampleBoundsModule(2) == ChannelsModuleStructure(iModule).nSamples
            SampleBoundsModule(2) = SampleBoundsModule(2)-1;
            reached_edge = true;
        end
                
        
        % Assign the Electrophysiological signals - these will not be resampled
        if ChannelsModuleStructure(iModule).isElectrophysiology && sum(SampleBoundsModule)~=0

            % Do a check if we're dealing with compressed or non-compressed data
            if strcmp(class(ChannelsModuleStructure(iModule).module.data),'types.untyped.DataPipe') % Compressed data
                if ~ChannelsModuleStructure(iModule).FlipMatrix
                    loadedSignal = ChannelsModuleStructure(iModule).module.data.internal.load([1, SampleBoundsModule(1)], [ChannelsModuleStructure(iModule).nChannels, SampleBoundsModule(2)+1]);
                else
                    loadedSignal = ChannelsModuleStructure(iModule).module.data.internal.load([SampleBoundsModule(1), 1], [SampleBoundsModule(2)+1, ChannelsModuleStructure(iModule).nChannels])';
                end
            else % Uncompressed data
                if ~ChannelsModuleStructure(iModule).FlipMatrix
                    loadedSignal = ChannelsModuleStructure(iModule).module.data.load([1, SampleBoundsModule(1)], [ChannelsModuleStructure(iModule).nChannels, SampleBoundsModule(2)+1]);
                else
                    loadedSignal = ChannelsModuleStructure(iModule).module.data.load([SampleBoundsModule(1), 1], [SampleBoundsModule(2)+1, ChannelsModuleStructure(iModule).nChannels])';
                end
            end
            loadedSignal = double(loadedSignal);
            
            if reached_edge
                F(iiCh+1:iiCh + nModuleChannels,1:end-1) = loadedSignal;
            else
                F(iiCh+1:iiCh + nModuleChannels,:) = loadedSignal;
            end
            
        elseif sum(SampleBoundsModule)~=0 % Take care of the other signals
            
            % Load the corresponding signal to the requested timebounds
            if ~ChannelsModuleStructure(iModule).FlipMatrix
                if ChannelsModuleStructure(iModule).nChannels>1
                    loadedSignal = ChannelsModuleStructure(iModule).module.data.load([1, SampleBoundsModule(1)+1], [ChannelsModuleStructure(iModule).nChannels, SampleBoundsModule(2)+1]);
                else
                    loadedSignal = ChannelsModuleStructure(iModule).module.data.load(SampleBoundsModule(1)+1, SampleBoundsModule(2)+1)';
                end
            else
                loadedSignal = ChannelsModuleStructure(iModule).module.data.load([SampleBoundsModule(1)+1, 1], [SampleBoundsModule(2)+1, ChannelsModuleStructure(iModule).nChannels])';
            end
            loadedSignal = double(loadedSignal);        


            % If the sampling rate of the signal is less than the
            % electrophysiological, perform upsampling
            if ChannelsModuleStructure(iModule).Fs < Fs

                low_sampled_signal = loadedSignal;
                temp = zeros(size(low_sampled_signal,1),nSamples+1);
                for iChannel = 1:size(low_sampled_signal,1)

                    %1. UPSAMPLE AND DROP RANDOM ENTRIES
                    % Upsampling the lower sampled behavioral signals
                    upsampled_signal = repelem(low_sampled_signal(iChannel,:),ceil(nSamples/size(low_sampled_signal,2)));
                    nSamplesToDrop = size(upsampled_signal,2) - nSamples-1;
                    keep_these_samples = true(1,length(upsampled_signal));
                    remove_these_samples = round(linspace(2, size(upsampled_signal,2)-1, nSamplesToDrop)); % Keeping the edges

                    keep_these_samples(remove_these_samples) = false;
                    temp(iChannel,:) = upsampled_signal(keep_these_samples);

    %             %2. INTERPOLATION
    %             temp(iChannel,:) = interp(double(data.streams.(stream_info(iStream).label).data),round(Fs/stream_info(iStream).fs));
                end
                F(iiCh+1:iiCh + nModuleChannels,:) = temp;


            elseif ChannelsModuleStructure(iModule).Fs > Fs % Higher sampled signals - Similar code is used in TDT importer
                % Make sure the signal has all the samples we expect
                high_sampled_signal = loadedSignal;

                nSamplesToDrop = size(high_sampled_signal,2) - nSamples-1;
                keep_these_samples = true(1,size(high_sampled_signal,2));
                remove_these_samples = round(linspace(2, size(high_sampled_signal,2)-1, nSamplesToDrop)); % Keeping the edges

                keep_these_samples(remove_these_samples) = false;
                temp = high_sampled_signal(:,keep_these_samples);

                F(iiCh+1:iiCh + nModuleChannels,:) = temp;
            end
        else % In case there are no signals within the selected timebounds, assign NaNs to it
            F(iiCh+1:iiCh + nModuleChannels,:) = NaN(size(F(iiCh+1:iiCh + nModuleChannels,:)));
        end
    end
    iiCh = iiCh + nModuleChannels;
end

cd(previous_directory)

end
