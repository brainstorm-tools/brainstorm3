function F = in_fread_nwb(sFile, iEpoch, SamplesBounds, selectedChannels, isContinuous)
% IN_FREAD_NWB Read a block of recordings from nwb files
%
% USAGE:  F = in_fread_nwb(sFile, SamplesBounds=[], iChannels=[])

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


% Parse inputs
if (nargin < 3) || isempty(selectedChannels)
    selectedChannels = 1:length(sFile.channelflag);
end

nTotalChannels = length(selectedChannels);

%% Load the nwbFile object that holds the info of the .nwb
nwb2 = sFile.header.nwb; % Having the header saved, saves a ton of time instead of reading the .nwb from scratch

%% Assign the bounds based on the trials or the continuous selection
if isempty(SamplesBounds) && isContinuous
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
    timeBounds    = SamplesBounds./sFile.prop.sfreq;
elseif (~isempty(SamplesBounds) && isContinuous) || (~isempty(SamplesBounds) && ~isContinuous)
    timeBounds    = SamplesBounds./sFile.prop.sfreq;
elseif isempty(SamplesBounds) && ~isContinuous
    iEpoch = double(iEpoch);
    % Get sample bounds
    all_TrialsTimeBounds = double([nwb2.intervals_trials.start_time.data.load nwb2.intervals_trials.stop_time.data.load]);
    timeBounds = all_TrialsTimeBounds(iEpoch,:);
    SamplesBounds = round(timeBounds.* sFile.prop.sfreq);    
end

nSamples = SamplesBounds(2) - SamplesBounds(1)+1;
Fs = sFile.prop.sfreq;

%% Get the signals
ChannelsModuleStructure = sFile.header.ChannelsModuleStructure;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% HERE THE ASSUMPTION IS THAT THE LABELING OF THE CHANNELS HAS NOT CHANGED
% FROM WHAT THE IMPORTER POPULATED
% This could lead to problems
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

F = zeros(nTotalChannels, nSamples);

iiCh = 0;
for iModule = 1:length(ChannelsModuleStructure)
    nModuleChannels = ChannelsModuleStructure(iModule).nChannels;
    
    % Assign the Electrophysiological signals - these will not be resampled
    if ChannelsModuleStructure(iModule).isElectrophysiology
        
        % Do a check if we're dealing with compressed or non-compressed data
        if strcmp(class(ChannelsModuleStructure(iModule).module.data),'types.untyped.DataPipe') % Compressed data
            if ~ChannelsModuleStructure(iModule).FlipMatrix
                loadedSignal = ChannelsModuleStructure(iModule).module.data.internal.load([1, SamplesBounds(1)+1], [ChannelsModuleStructure(iModule).nChannels, SamplesBounds(2)+1]);
            else
                loadedSignal = ChannelsModuleStructure(iModule).module.data.internal.load([SamplesBounds(1)+1, 1], [SamplesBounds(2)+1, ChannelsModuleStructure(iModule).nChannels])';
            end
        else % Uncompressed data
            if ~ChannelsModuleStructure(iModule).FlipMatrix
                loadedSignal = ChannelsModuleStructure(iModule).module.data.load([1, SamplesBounds(1)+1], [ChannelsModuleStructure(iModule).nChannels, SamplesBounds(2)+1]);
            else
                loadedSignal = ChannelsModuleStructure(iModule).module.data.load([SamplesBounds(1)+1, 1], [SamplesBounds(2)+1, ChannelsModuleStructure(iModule).nChannels])';
            end
        end
        loadedSignal = double(loadedSignal);        
        
        F(iiCh+1:iiCh + nModuleChannels,:) = loadedSignal;
    else
        
        % Check which sampleBounds with the different sampling rate
        % correspond to the sampleBounds of the Electrophysiological signal
        
        timeBounds = SamplesBounds./Fs;
        SampleBoundsModule = round(timeBounds.*ChannelsModuleStructure(iModule).Fs);
        
        % Load the corresponding signal to the selecting timebounds
        if ~ChannelsModuleStructure(iModule).FlipMatrix
            loadedSignal = ChannelsModuleStructure(iModule).module.data.load([1, SampleBoundsModule(1)+1], [ChannelsModuleStructure(iModule).nChannels, SampleBoundsModule(2)+1]);
        else
            loadedSignal = ChannelsModuleStructure(iModule).module.data.load([SampleBoundsModule(1)+1, 1], [SampleBoundsModule(2)+1, ChannelsModuleStructure(iModule).nChannels])';
        end
        loadedSignal = double(loadedSignal);        

        
        % If the sampling rate of the signal is less than the
        % electrophysiological, perform upsampling
        if ChannelsModuleStructure(iModule).Fs < Fs
            
            low_sampled_signal = loadedSignal;
            temp = zeros(size(low_sampled_signal,1),nSamples);
            for iChannel = 1:size(low_sampled_signal,1)

                %1. UPSAMPLE AND DROP RANDOM ENTRIES
                % Upsampling the lower sampled behavioral signals
                upsampled_position = repelem(low_sampled_signal(iChannel,:),ceil(nSamples/size(low_sampled_signal,2)));
                logical_keep = true(1,length(upsampled_position));
                random_points_to_remove = randperm(length(upsampled_position),length(upsampled_position)-nSamples);
                logical_keep(random_points_to_remove) = false;
                temp(iChannel,:) = upsampled_position(logical_keep);

%             %2. INTERPOLATION
%             temp(iChannel,:) = interp(double(data.streams.(stream_info(iStream).label).data),round(Fs/stream_info(iStream).fs));
            end
            F(iiCh+1:iiCh + nModuleChannels,:) = temp;
            
            
        else % Higher sampled signals - Same code is used in TDT importer
            % Make sure the signal has all the samples we expect
            high_sampled_signal = loadedSignal;

            % Make sure the signal has all the samples we expect
            nExpectedSamples = floor(nSamples / Fs * ChannelsModuleStructure(iModule).Fs);
            nGottenSamples = size(high_sampled_signal,2);
            high_sampled_signal2 = zeros(size(high_sampled_signal,1), nExpectedSamples);
            high_sampled_signal2(:,1:min(nGottenSamples,nExpectedSamples)) = high_sampled_signal;
            high_sampled_signal = high_sampled_signal2;
            nSamplesToDrop =  size(high_sampled_signal,2) - nSamples;

            keep_these_samples = true(1,size(high_sampled_signal,2));
            remove_these_samples = round(linspace(1, size(high_sampled_signal,2), nSamplesToDrop));

            keep_these_samples(remove_these_samples) = false;
            temp = high_sampled_signal(:,keep_these_samples);
            
            F(iiCh+1:iiCh + nModuleChannels,:) = temp;
        end
        
        
    end
    iiCh = iiCh + nModuleChannels;
end


end
