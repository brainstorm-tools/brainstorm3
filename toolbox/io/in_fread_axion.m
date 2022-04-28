function F = in_fread_axion(sFile, SamplesBounds, iChannels, precision)
% IN_FREAD_AXION Read a block of recordings from a Plexon file
%
% USAGE:  F = in_fread_axion(sFile, SamplesBounds=[], iChannels=[], precision)

% This function uses the "Axion MATLAB Files" package 
% distributed by Axion Biosystems with their AxIS software 

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
% Authors: Raymundo Cassani, Francois Tadel, 2021


%% ===== INSTALL MFF LIBRARY =====
if ~exist('AxisFile', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'axion');
    if ~isInstalled
        error(errMsg);
    end
end


%% ===== PARSE INPUTS =====
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


%% ===== READ FILE =====
% Open the file again
sFile.header.FileObj.reopen();

% Read the .raw file and convert it to Brainstorm format
% The AxisFile class needs needs one extra sample in the upper bound
waveforms = sFile.header.FileObj.DataSets.LoadData((SamplesBounds + [0 1]) ./ sFile.prop.sfreq);

% Initialize Brainstorm output
F = zeros(sFile.header.ChannelCount, SamplesBounds(2)-SamplesBounds(1)+1, precision);
precFunc = str2func(precision);
% Reorder channels correctly (see in_fopen_axion.m for labelling logic)
for iChannel = 1:sFile.header.ChannelCount
    chObj = sFile.header.FileObj.DataSets.ChannelArray.Channels(sFile.header.ChannelIndices(iChannel));
    tmp = waveforms{chObj.WellRow, chObj.WellColumn, chObj.ElectrodeColumn, chObj.ElectrodeRow};       
    F(iChannel,:) = precFunc(tmp.GetVoltageVector);
end

