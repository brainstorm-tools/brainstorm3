function F = in_fread_blackrock(sFile, SamplesBounds, iChannels)
% IN_FREAD_BLACKROCK Read a block of recordings from a Blackrock NeuroPort file (.nev and .nsX)
%
% USAGE:  F = in_fread_blackrock(sFile, SamplesBounds=[], iChannels=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015


% Parse inputs
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.ChannelCount;
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = sFile.prop.samples;
end

% Samples string
strSamples = sprintf('t:%d:%d', SamplesBounds(1) + 1, SamplesBounds(2) + 1);
% Read the corresponding recordings
rec = openNSx('read', sFile.filename, 'sample', strSamples, 'p:double');

% Get values and convert from uV to V
F = rec.Data * 1e-6;

% Select channels
% TODO: CAN BE DONE MORE EFFICIENTLY WITH openNSx PARAMETERS
if ~isempty(iChannels)
    F = F(iChannels,:);
end


