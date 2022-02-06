function iChannelFinal = good_channel(Channel, ChannelFlag, channelTypes)
% GOOD_CHANNEL: Extract channels of a given type.
%
% USAGE: iChannel = good_channel(Channel, ChannelFlag, channelTypes);
%        iChannel = good_channel(Channel, [], channelType);
%
% INPUT:
%    - Channel     : Brainstorm Channel.mat structure, of importance here is Channel.Type
%    - ChannelFlag : vector of -1 (bad), 0(indifferent), and 1(good) data flags of length 
%                    the number of channels in the Channel structure.
%                    If left empty, assumes all channels are GOOD
%    - channelTypes: Types of channel that is looked for ('EEG', 'MEG', ...)
%
% OUTPUT:
%    - iChannel : the index to the good channels for desired sensor type 

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
% Authors: Sylvain Baillet, John C. Mosher, January 1999
%          Francois Tadel, 2008-2010

iChannelFinal = [];
if isempty(channelTypes)
    return;
elseif ~iscell(channelTypes)
    channelTypes = {channelTypes};
end

for iType = 1:length(channelTypes)
    channelType = deblank(channelTypes{iType}); 

    % === CHECK CHANNEL TYPE ===
    iEegRef = [];
    switch lower(channelType)
        % MEG: all sensors
        case {'meg', 'vectorview306', 'ctf', '4d', 'kit', 'kriss', 'babymeg', 'ricoh'}
            iChannelType = find(ismember({Channel.Type}, {'MEG','MEG MAG','MEG GRAD'}));
            
        % EEG/MEG combined reconstruction
        case 'fusion'
            iChannelType = find(ismember({Channel.Type}, {'EEG', 'MEG','MEG MAG','MEG GRAD'}));
            
        % MEG: First or second gradiometer only (for Neuromag systems)
        case {'meg grad2', 'meg grad3', 'meg gradnorm'}
            % Get all gradiometers
            iGrad = find(ismember({Channel.Type}, 'MEG GRAD'));
            iGrad2 = [];
            iGrad3 = [];
            % Constrain to channel flag
            if (length(ChannelFlag) == length(Channel))
                iGrad = iGrad(ChannelFlag(iGrad) >= 0);
            end
            % Get the list of channels ending in 2 and 3
            iChan2 = iGrad(cellfun(@(c)isequal(c(end),'2'), {Channel(iGrad).Name}));
            iChan3 = iGrad(cellfun(@(c)isequal(c(end),'3'), {Channel(iGrad).Name}));
            % If all the sensors are of the same type: do not try to get pairs
            if ~isempty(iChan2) && isempty(iChan3)
                iGrad2 = iChan2;
                iGrad3 = [];
            elseif ~isempty(iChan3) && isempty(iChan2)
                iGrad2 = [];
                iGrad3 = iChan3;
            else
                % Get all the names of the sensors without the '2' or '3' at the end
                shortNames = unique(cellfun(@(c)c(1:end-1), {Channel(iGrad).Name}, 'UniformOutput', 0));
                % Loop through all these names, and keep only the ones that have the two gradiometers available
                for iName = 1:length(shortNames)
                    i2 = find(strcmpi({Channel(iGrad).Name}, [shortNames{iName}, '2']));
                    i3 = find(strcmpi({Channel(iGrad).Name}, [shortNames{iName}, '3']));
                    if ~isempty(i2) && ~isempty(i3)
                        iGrad2(end+1) = iGrad(i2);
                        iGrad3(end+1) = iGrad(i3);
                    end
                end
            end
            % Report the gradiometers found, according to the required type
            switch lower(channelType)
                case {'meg grad2', 'meg gradnorm'}
                    iChannelType = iGrad2;
                case 'meg grad3'
                    iChannelType = iGrad3;
            end           
            
        % EEG: Get EEG REF channel
        case 'eeg'
            iEegRef      = find(strcmpi({Channel.Type}, 'EEG REF'));
            iChannelType = find(strcmpi({Channel.Type}, 'EEG'));
            
        % iEEG: ECOG+SEEG
        case 'ecog+seeg'
            iChannelType = find(ismember({Channel.Type}, {'ECOG+SEEG','ECOG','SEEG'}));
            
        % NIRS
        case {'nirs', 'nirs-brs'}
            iChannelType = find(strcmpi({Channel.Type}, 'NIRS'));
            
        % Fixed channel type
        otherwise
            iChannelType = find(strcmpi({Channel.Type}, channelType));
    end

    % === CHECK CHANNEL FLAG ===
    % If ChannelFlag matches the whole set of channels
    if (length(ChannelFlag) == length(Channel))
        iChannel = iChannelType(ChannelFlag(iChannelType) >= 0);
        %iChannel = iChannelType;
    % If channel flag is not defined : returned all the channels that have the right type
    elseif isempty(ChannelFlag)
        iChannel = iChannelType;
    % If ChannelFlag matches only the channels of the good type
    elseif (length(ChannelFlag) == length(iChannelType))
        iChannel = iChannelType(ChannelFlag >= 0);
    % If ChannelFlag matches only the channels of the good type (INCLUDING REFERENCE)
    elseif (length(ChannelFlag) == length(iChannelType)+length(iEegRef))
        iChannelType = [iChannelType iEegRef];
        iChannel = iChannelType(ChannelFlag >= 0);
    % Error
    else
        return;
    end
    
    iChannelFinal = [iChannelFinal, iChannel];
end

iChannelFinal = unique(iChannelFinal);
