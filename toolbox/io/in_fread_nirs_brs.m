function F = in_fread_nirs_brs(sFile,SamplesBounds)
% IN_FREAD_NIRS_BRS:  Read a block of recordings from nirs data .nirs file
%
% USAGE:  F = in_fread_nirs_brs(sFile, SamplesBounds) : Read all channels
%         F = in_fread_nirs_brs(sFile)                : Read all channels, all the times

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
% Authors: Thomas Vincent (2015), Alexis Machado (2012)

% Use the full file if samples not specified
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Convert to 1-based samples in the Matlab matrix
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1; 
% Check start and stop samples
if (SamplesBounds(1) < 1) || (SamplesBounds(1) > SamplesBounds(2)) || (SamplesBounds(2) > round(sFile.prop.times(2) .* sFile.prop.sfreq) + 1)
    error('Invalid samples range.');
end
    
% Load file
nirs = load(sFile.filename, '-mat');
if isfield(nirs, 'aux')
    channel_data = [nirs.d nirs.aux];
else
    channel_data = nirs.d;
end

% Select only a given time window
if ~isempty(SamplesBounds)
    % data | dimension nSamples by nChannels:
    F = channel_data(SamplesBounds(1):SamplesBounds(2), :)'; 
else
    F = channel_data';
end

