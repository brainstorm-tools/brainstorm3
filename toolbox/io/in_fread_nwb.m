function F = in_fread_nwb(sFile, SamplesBounds, selectedChannels)
% IN_FREAD_INTAN Read a block of recordings from nwb files
%
% USAGE:  F = in_fread_nwb(sFile, SamplesBounds=[], iChannels=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
    SamplesBounds = sFile.prop.samples;
end

nChannels = length(selectedChannels);
nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;

timeBounds = SamplesBounds./sFile.prop.sfreq;


%% Load the nwbFile object that holds the info of the .nwb
nwb2 = sFile.header.nwb; % Having the header saved, saves a ton of time instead of reading the .nwb from scratch

%% Find the indices of the timestamps that are selected
position_timestamps =  nwb2.processing.get('behavior').nwbdatainterface.get('OpenFieldPosition_New_position').spatialseries.get('OpenFieldPosition_New_norm_spatial_series').timestamps.load;

[~, iPositionTimestamps] = histc(timeBounds, position_timestamps);

%% Get the signals

F = zeros(nChannels, nSamples);

iEEG = 0;
iAdditionalChannel = 0;
for iChannel = 1:nChannels
    if strcmp(sFile.header.ChannelType{selectedChannels(iChannel)}, 'EEG')
        iEEG = iEEG + 1;
        F(iChannel,:) = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(sFile.header.LFPKey).data.load([selectedChannels(iEEG), SamplesBounds(1)+1], [selectedChannels(iEEG), SamplesBounds(2)+1]);
    elseif strcmp(sFile.header.ChannelType{selectedChannels(iChannel)}, 'OpenFieldPosition')
        iAdditionalChannel = iAdditionalChannel + 1;
    
        if length(iPositionTimestamps) < 2 || sum(iPositionTimestamps == 0) > 0 % If not both values are within the range
            F(iChannel,:) = nan(1, nSamples);
            
            disp('selection is outside the timestamps for the additional channels')
        else
            temp = nwb2.processing.get('behavior').nwbdatainterface.get('OpenFieldPosition_New_position').spatialseries.get('OpenFieldPosition_New_norm_spatial_series').data.load([iAdditionalChannel, iPositionTimestamps(1)], [iAdditionalChannel, iPositionTimestamps(2)]);
            upsampled_position = interp(temp,ceil(nSamples/length(temp)));
        
            logical_keep = true(1,length(upsampled_position));
            random_points_to_remove = randperm(length(upsampled_position),length(upsampled_position)-nSamples);
            logical_keep(random_points_to_remove) = false;

            F(iChannel,:) = upsampled_position(logical_keep);
        end
        
    end
end
