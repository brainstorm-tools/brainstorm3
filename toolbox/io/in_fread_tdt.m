function F = in_fread_tdt(sFile, SamplesBounds, selectedChannels)
% IN_FREAD_TDT Read a block of recordings from Tucker Davis Technologies files
%
% USAGE:  F = in_fread_TDT(sFile, SamplesBounds=[], iChannels=[])

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


 % Parse inputs
if (nargin < 3) || isempty(selectedChannels)
    selectedChannels = 1:length(sFile.channelflag);
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

nChannels = length(selectedChannels);
nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;

Fs = floor(max(sFile.header.several_sampling_rates));





%% The importer for TDT, imports based on timeBounds, not samplebounds
% This is a nightmare when trying to load segments of the same length
% Especially since some channels are sampled at a different sampling rate
% The code below upsamples the signals with lower Fs to match the sampling
% rate of the highest sampled signal (typically LFP or Raw)
% This might create a problem at certain datasets.


data = TDTbin2mat(sFile.filename, 'T1', SamplesBounds(1)/Fs, 'T2', SamplesBounds(2)/Fs);


F = zeros(length(selectedChannels), nSamples);
ii = 1;
for iStream = 1:length(sFile.header.total_channels)

    % DO THE EXTRAPOLATION HERE FOR THE LOW SAMPLED SIGNALS (EYE TRACES, ARM MOVEMENTS ETC.)
    if sFile.header.several_sampling_rates(iStream) ~= max(sFile.header.several_sampling_rates)
        if mod(max(sFile.header.several_sampling_rates),sFile.header.several_sampling_rates(iStream))~=0
            warning ('The sampling rate of the extra channels is not divided by the sampling rate of the EEG signals - POTENTIAL ERROR')
        end
        temp = interp(double(data.streams.(sFile.header.all_streams{iStream}).data),round(max(sFile.header.several_sampling_rates)/sFile.header.several_sampling_rates(iStream)));
    else
        temp = double(data.streams.(sFile.header.all_streams{iStream}).data);
    end

    % At the end of the signals' length, since the loading based on time is awful,
    % leave the extra samples as zeros (shouldn't create a problem)
    if nSamples > size(temp,2)
        F(ii : ii + sFile.header.total_channels(iStream) - 1,1:size(temp,2)) = temp; clear temp
    else  
        F(ii : ii + sFile.header.total_channels(iStream) - 1,:) = temp(:,1:nSamples); clear temp
    end
    ii = ii + sFile.header.total_channels(iStream);
end


% Lazy selection, Improve
F = F(selectedChannels,:);
      

end





