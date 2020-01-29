function F = in_fread_smr(sFile, sfid, SamplesBounds, iChannels)
% IN_FREAD_SMR:  Read a block of recordings from a Cambridge Electronic Design Spike2 file (.smr/.son)
%
% USAGE:  F = in_fread_smr(sFile, sfid, SamplesBounds=[], iChannels=[])

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
% Authors: Francois Tadel, 2017

% Parse inputs
if (nargin < 4) || isempty(iChannels)
    iChannels = 1:sFile.header.num_channels;
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Initialize returned matrix
nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;
F = zeros(length(iChannels), nSamples);

% Loop to read all the channels
for i = 1:length(iChannels)
    % Get sample bounds for a specific channel: No change in sampling rate
    if (sFile.prop.sfreq == sFile.header.chaninfo(iChannels(i)).idealRate)
        chSampleBounds = SamplesBounds;
    % Sampling rate is different
    else
        chSampleBounds = [ceil(SamplesBounds(1) ./ sFile.prop.sfreq .* sFile.header.chaninfo(iChannels(i)).idealRate), ...
                          floor(SamplesBounds(2) ./ sFile.prop.sfreq .* sFile.header.chaninfo(iChannels(i)).idealRate)];
        disp(sprintf('BST> Warning: Channel "%s" reinterpolated from %dHz to %dHz', sFile.header.chaninfo(iChannels(i)).title, round(sFile.header.chaninfo(iChannels(i)).idealRate), round(sFile.prop.sfreq)));
    end
    % Rebuild the samples indices for the blocks in the file
    blockSamples = [0, cumsum(sFile.header.chaninfo(iChannels(i)).blocks(5,:)) - 1];
    blockStart = find((chSampleBounds(1) >= blockSamples(1:end-1)) & (chSampleBounds(1) <= blockSamples(2:end)));
    blockStop  = find((chSampleBounds(2) >= blockSamples(1:end-1)) & (chSampleBounds(2) <= blockSamples(2:end)));
    % Read channel
    [d,header] = SONGetChannel(sfid, sFile.header.chaninfo(iChannels(i)).number, blockStart, blockStop, 'scale');
    % Get corresponding indices from the read channels
    iSamples = (chSampleBounds(1) - blockSamples(blockStart) + 1) : (chSampleBounds(2) - blockSamples(blockStart) + 1);
    % Copy output in returned matrix
    switch (header.kind)
        case {1,9}
            chData = d(iSamples)';
        case 6
            chData = d.adc(iSamples)';
    end
    % Same sampling rate
    if (sFile.prop.sfreq == sFile.header.chaninfo(iChannels(i)).idealRate)
        F(i,:) = chData;
    % Resample the data
    else
        F(i,:) = interp1(linspace(0,1,length(chData)), chData, linspace(0,1,nSamples));
    end
end

