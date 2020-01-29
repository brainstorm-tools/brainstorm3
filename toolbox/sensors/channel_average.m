function [MeanChannelMat, Message] = channel_average(ChannelMats)
% CHANNEL_AVERAGE: Averages positions of MEG/EEG sensors.
%
% INPUT:
%     - ChannelMats : Cell array of channel.mat structures
% OUPUT:
%     - MeanChannelMat : Average channel mat

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
% Authors: Francois Tadel, 2012-2018

Message = [];

% Detect device
[DeviceTag, DeviceName] = channel_detect_device(ChannelMats{1});
% CTF/4D files: take the center of the coil closer to the head
if any(strcmpi(DeviceName, {'CTF', '4D', 'KRISS'}))
    iChanInteg = [];
    for i = 1:length(ChannelMats)
        for iChan = 1:length(ChannelMats{i}.Channel)
            nCoils = size(ChannelMats{i}.Channel(iChan).Loc,2);
            % DO NOT PROCESS REF NOW, THIS WILL MAYBE HAVE TO BE CHANGED
            %if any(strcmpi(ChannelMats{i}.Channel(iChan).Type, {'MEG','MEG REF'}))
            if any(strcmpi(ChannelMats{i}.Channel(iChan).Type, {'MEG'})) && (nCoils >= 4)
                if (i == 1)
                    iChanInteg(end+1) = iChan;
                end
                ChannelMats{i}.Channel(iChan).Loc = mean(ChannelMats{i}.Channel(iChan).Loc(:,1:4), 2);
            end
        end
    end
end

% Check the coherence between all the channel files
MeanChannelMat = ChannelMats{1};
nAvg = ones(1, length(MeanChannelMat.Channel));
% Loop on all the 
for i = 2:length(ChannelMats)
    % Check number of channels
    if (length(ChannelMats{i}.Channel) ~= length(MeanChannelMat.Channel))
        Message = ['The channels files from the different studies do not have the same number of channels.' 10 ...
                   'Cannot create a common channel file.'];
        MeanChannelMat = [];
        return;
    end
    % Sum channel locations
    for iChan = 1:length(MeanChannelMat.Channel)
        % If the channel has no location in this file: skip
        if isempty(ChannelMats{i}.Channel(iChan).Loc)
            continue;
        % If the current average is empty, use the new value directly
        elseif isempty(MeanChannelMat.Channel(iChan).Loc)
            MeanChannelMat.Channel(iChan).Loc    = ChannelMats{i}.Channel(iChan).Loc;
            MeanChannelMat.Channel(iChan).Orient = ChannelMats{i}.Channel(iChan).Orient;
        % Check the size of Loc matrix and the values of Weights matrix
        elseif ~isequal(size(MeanChannelMat.Channel(iChan).Loc), size(ChannelMats{i}.Channel(iChan).Loc))
            Message = ['The channels files from the different studies do not have the same structure.' 10 ...
                       'Cannot create a common channel file.'];
            MeanChannelMat = [];
            return;
        % Sum with existing average
        else
            MeanChannelMat.Channel(iChan).Loc    = MeanChannelMat.Channel(iChan).Loc    + ChannelMats{i}.Channel(iChan).Loc;
            MeanChannelMat.Channel(iChan).Orient = MeanChannelMat.Channel(iChan).Orient + ChannelMats{i}.Channel(iChan).Orient;
            nAvg(iChan) = nAvg(iChan) + 1;
        end
    end
end
% Divide the locations of channels by the number of channel files
for iChan = 1:length(MeanChannelMat.Channel)
    if (nAvg(iChan) > 0)
        MeanChannelMat.Channel(iChan).Loc    = MeanChannelMat.Channel(iChan).Loc    / nAvg(iChan);
        MeanChannelMat.Channel(iChan).Orient = MeanChannelMat.Channel(iChan).Orient / nAvg(iChan);
    end
end

% CTF/4D files: Restore the full list of integration points
if any(strcmpi(DeviceName, {'CTF', '4D', 'KRISS'}))
    MeanChannelMat.Channel(iChanInteg) = ctf_add_coil_defs(MeanChannelMat.Channel(iChanInteg), DeviceName);
end




