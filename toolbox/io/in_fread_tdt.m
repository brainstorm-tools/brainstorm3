function F = in_fread_tdt(sFile, SamplesBounds, selectedChannels)
% IN_FREAD_TDT Read recordings saved in the Tucker Davis Technologies format

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

% Install/load TDT-SDK library
if ~exist('TDTbin2mat', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'tdt-sdk');
    if ~isInstalled
        error(errMsg);
    end
end

% Parse inputs
if (nargin < 3) || isempty(selectedChannels)
    selectedChannels = 1:length(sFile.channelflag);
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;

%% Just get the LFP sampling rate and work on that 
% This is assigned at the importer

Fs = sFile.prop.sfreq;

%% The importer for TDT, imports based on timeBounds, not samplebounds
% This is a nightmare when trying to load segments of the same length
% Especially since some channels are sampled at a different sampling rate
% The code below upsamples the signals with lower Fs to match the sampling
% rate of the highest sampled signal (typically LFP or Raw)
% This might create a problem at certain datasets.

stream_info = sFile.header.stream_info;



%% Get the different types of streams that are needed based on the indices of the selected channels

all_stream_labels = {stream_info.label};
streams_needed = [];
selected_channels_from_stream = {};

iSelectedStreams = [];
% if all channels are selected (I assume here that the same channel can't be selected multiple times)
if length(selectedChannels) == length(length(sFile.channelflag)) 
    streams_to_load = all_stream_labels;
    iSelectedStreams = 1:length(all_stream_labels);
else
    ii = 0;
    for iStream = 1:length(stream_info)
        
        if any(ismember(stream_info(iStream).channelIndices, [selectedChannels]))
            ii = ii+1;
            iSelectedStreams = [iSelectedStreams iStream];
            disp(['Will load Stream: ' stream_info(iStream).label])
            selected_channels_from_stream{ii}= find(ismember(stream_info(iStream).channelIndices, [selectedChannels]));

            streams_needed = [streams_needed iStream];
        end
    end

    streams_to_load = all_stream_labels(streams_needed);
end


ii = 1;
F = zeros(length(selectedChannels), nSamples);
for iStream = 1:length(streams_to_load)
    
    data = TDTbin2mat(sFile.filename, 'TYPE', 4, 'STORE', streams_to_load{iStream}, 'T1', SamplesBounds(1)/Fs, 'T2', SamplesBounds(2)/Fs);
    data = data.streams.(streams_to_load{iStream});
    

    % DO THE EXTRAPOLATION HERE FOR THE LOW SAMPLED SIGNALS (EYE TRACES ETC.)
    if stream_info(iStream).fs < Fs
        
        low_sampled_signal = double(data.data(selected_channels_from_stream{iStream},:));
        
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
        
        
    % DROP SAMPLES HERE FOR THE HIGH SAMPLED SIGNALS (LED, EMG ETC.)
    elseif stream_info(iStream).fs > Fs
        
        
       high_sampled_signal = double(data.data(selected_channels_from_stream{iStream},:));
       
       % Make sure the signal has all the samples we expect
       nExpectedSamples = floor(nSamples / Fs * stream_info(iStream).fs);
       nGottenSamples = size(high_sampled_signal,2);
       high_sampled_signal2 = zeros(size(high_sampled_signal,1), nExpectedSamples);
       high_sampled_signal2(:,1:min(nGottenSamples,nExpectedSamples)) = high_sampled_signal;
       high_sampled_signal = high_sampled_signal2;
        
        
%         high_sampled_signal = double(data.data(selected_channels_from_stream{iStream},:));        
        
        nSamplesToDrop =  size(high_sampled_signal,2) - nSamples;
        
        keep_these_samples = true(1,size(high_sampled_signal,2));
        remove_these_samples = round(linspace(1, size(high_sampled_signal,2), nSamplesToDrop));
        
        keep_these_samples(remove_these_samples) = false;
        
        
        temp = high_sampled_signal(:,keep_these_samples);
        
    elseif stream_info(iStream).fs == Fs
        temp = double(data.data(selected_channels_from_stream{iStream},:));
    end

    % At the end of the signals' length, since the loading based on time is awful,
    % leave the extra samples as zeros (shouldn't create a problem)
    if nSamples > size(temp,2)
%         F(stream_info(iSelectedStreams(iStream)).channelIndices(selected_channels_from_stream{iStream}),1:size(temp,2)) = temp; clear temp
        F(ii : ii + length(selected_channels_from_stream{iStream}) - 1,1:size(temp,2)) = temp; clear temp
    else  
%         F(stream_info(iSelectedStreams(iStream)).channelIndices(selected_channels_from_stream{iStream}),:) = temp(:,1:nSamples); clear temp
        F(ii : ii + length(selected_channels_from_stream{iStream}) - 1,:) = temp(:,1:nSamples); clear temp
    end
     ii = ii + length(selected_channels_from_stream{iStream});
end

end





