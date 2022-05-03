function F = in_fread_plexon(sFile, SamplesBounds, iChannels, precision)
% IN_FREAD_PLEXON Read a block of recordings from a Plexon file
%
% USAGE:  F = in_fread_plexon(sFile, SamplesBounds=[], iChannels=[])

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
% Authors: Konstantinos Nasiotis, 2018-2022
%          Martin Cousineau, 2019

% ===== INSTALL PLEXON SDK =====
[isInstalled, errMsg] = bst_plugin('Install', 'plexon');
if ~isInstalled
    error(errMsg);
end

% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(precision)
    precision = 'double';
elseif ~ismember(precision, {'single', 'double'})
    error('Unsupported precision.');
end
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.ChannelCount;
end
if (nargin < 2) || isempty(SamplesBounds)
    % Read entire recording
    SamplesBounds = round((sFile.prop.times - sFile.header.FirstTimeStamp) .* sFile.prop.sfreq) + 1;
else 
    % Readjust the samples call based on the starting time value
    SamplesBounds = SamplesBounds - round(sFile.header.FirstTimeStamp* sFile.prop.sfreq) + 1;
end

   
% Read the PLX file and assign it to the Brainstorm format
iSelectedChannels = sFile.header.chan_headers;
nChannels = length(iSelectedChannels);
nSamples  = diff(SamplesBounds) + 1;

% Initialize Brainstorm output
F = zeros(nChannels, nSamples, precision);

for iChannel = 1:nChannels 
    % plx_ad_span_v returns values in mV
    [adfreq, n, data] = plx_ad_span_v(sFile.filename, iSelectedChannels(iChannel)-1, SamplesBounds(1), SamplesBounds(2));    
    F(iChannel,:) = data./1000; % Convert to V
end
end