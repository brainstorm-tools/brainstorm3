function F = in_fread_adicht(sFile, iEpoch, iChannels, SamplesBounds)
% IN_FREAD_ADICHT:  Read a block of recordings from a .adicht file (ADInstruments LabChart)

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
% Author: Francois Tadel 2021

%% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(SamplesBounds)
    if ~isempty(sFile.epochs)
        SamplesBounds = round(sFile.epochs(iEpoch).times .* sFile.prop.sfreq);
    else
        SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
    end
end
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.nChannels;
end
if (nargin < 2) || isempty(iEpoch)
    iEpoch = 1;
end


%% ===== INSTALL ADI-SDK =====
if ~exist('adi', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'adi-sdk');
    if ~isInstalled
        error(errMsg); 
    end
end


%% ===== READ HEADER =====
% Read file header
objFile = adi.readFile(sFile.filename);
% Initialize returned data matrix
nSamples = SamplesBounds(2)-SamplesBounds(1)+1;
F = zeros(length(iChannels), nSamples);
% Loop on the channels 
for iChan = 1:length(iChannels)
    % Read channel data
    Fchan = objFile.channel_specs(iChannels(iChan)).getData(iEpoch);
    % Resample the data
    if (sFile.prop.sfreq ~= objFile.channel_specs(iChannels(iChan)).fs)
        Fchan = interp1(linspace(0,1,length(Fchan)), Fchan, linspace(0,1,nSamples));
    end
    % List samples to obtain
    if ~isempty(sFile.epochs)
        iSamples = (SamplesBounds(1):SamplesBounds(2)) - round(sFile.epochs(iEpoch).times(1) .* sFile.prop.sfreq) + 1;
    else
        iSamples = (SamplesBounds(1):SamplesBounds(2)) - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1;
    end
    % Keep only the requested samples
    F(iChan,:) = reshape(Fchan(iSamples), 1, []);
end

