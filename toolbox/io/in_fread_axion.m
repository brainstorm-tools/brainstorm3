function F = in_fread_axion(sFile, SamplesBounds, iChannels, precision)
% IN_FREAD_AXION Read a block of recordings from a Plexon file
%
% USAGE:  F = in_fread_axion(sFile, SamplesBounds=[], iChannels=[], precision)

% This function uses the the "Axion MATLAB Files" package 
% distributed by Axion Biosystems with their AxIS software 

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
% Authors: Raymundo Cassani, 2021


% Parse inputs
if (nargin < 4) || isempty(precision)
    precision = 'double';
elseif ~ismember(precision, {'single', 'double'})
    error('Unsupported precision.');
end
if (nargin < 3) || isempty(iChannels)
    iChannels = 1 : sFile.header.ChannelCount;
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

%% The AxisFile class needs needs one extra sample in the upper bound
SamplesBounds(2) = SamplesBounds(2) + 1;


%% Read the .raw file and convert it to Brainstorm format
sChannels   = sFile.header.sChannels(iChannels);
TimesBounds = SamplesBounds ./ sFile.prop.sfreq;
FileData    = AxisFile(sFile.filename);
waveforms   = FileData.DataSets.LoadData(TimesBounds);
% Get one channel
sChannel = sChannels(1);
tmp = waveforms{sChannel.WellRow, sChannel.WellColumn, sChannel.ElectrodeColumn, sChannel.ElectrodeRow};    
nChannels = length(sChannels);
nSamples  = length(tmp.Data); 
% Initialize Brainstorm output
F = zeros(nChannels, nSamples, precision);
precFunc = str2func(precision);

for iChannel = 1 : nChannels
    sChannel = sChannels(iChannel);
    tmp = waveforms{sChannel.WellRow, sChannel.WellColumn, sChannel.ElectrodeColumn, sChannel.ElectrodeRow};       
    F(iChannel,:) = precFunc(tmp.GetVoltageVector);
end