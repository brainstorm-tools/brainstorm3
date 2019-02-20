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



% Load the nwbFile object that holds the info of the .nwb
nwb2 = sFile.header.nwb; % Having the header saved, saves a ton of time instead of reading the .nwb from scratch

if sFile.header.RawDataPresent
    
    % Sequential reading is faster
    if sum(diff(selectedChannels) == ones(1,length(selectedChannels)-1)) == length(selectedChannels)-1
        F = nwb2.acquisition.get(sFile.header.RawKey).data.load([selectedChannels(1), SamplesBounds(1) + 1], [selectedChannels(end), SamplesBounds(2)+1]);
    % If not sequential channels, read one by one
    else    
        F = zeros(length(selectedChannels), nSamples);
        for iChannel = 1:nChannels
            F(iChannel,:) = nwb2.acquisition.get(sFile.header.RawKey).data.load([selectedChannels(iChannel), SamplesBounds(1)+1], [selectedChannels(iChannel), SamplesBounds(2)+1]);
        end
    end
    
    
elseif sFile.header.LFPDataPresent
    % Sequential reading is faster
    if sum(diff(selectedChannels) == ones(1,length(selectedChannels)-1)) == length(selectedChannels)-1
        F = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(sFile.header.LFPKey).data.load([selectedChannels(1), SamplesBounds(1) + 1], [selectedChannels(end), SamplesBounds(2)+1]);
    % If not sequential channels, read one by one
    else    
        F = zeros(length(selectedChannels), nSamples);
        for iChannel = 1:nChannels
            F(iChannel,:) = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(sFile.header.LFPKey).data.load([selectedChannels(iChannel), SamplesBounds(1)+1], [selectedChannels(iChannel), SamplesBounds(2)+1]);
        end
    end
end



