function F = in_fread_blackrock(sFile, SamplesBounds, iChannels, precision)
% IN_FREAD_BLACKROCK Read a block of recordings from a Blackrock NeuroPort file (.nev and .nsX)
%
% USAGE:  F = in_fread_blackrock(sFile, SamplesBounds=[], iChannels=[], precision='double')

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
% Authors: Francois Tadel, 2015-2021

% ===== INSTALL NPMK LIBRARY =====
if ~exist('openNSx', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'blackrock');
    if ~isInstalled
        error(errMsg);
    end
end

% Parse inputs
if (nargin < 4) || isempty(precision)
    precision = 'double';
elseif ~ismember(precision, {'single', 'double'})
    error('Unsupported precision.');
end
if (nargin < 3) || isempty(iChannels)
    iChannels = 1:sFile.header.ChannelCount;
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Samples string
strSamples = sprintf('t:%d:%d', SamplesBounds(1) + 1, SamplesBounds(2) + 1);

% Precision string
if strcmp(precision, 'single')
    strPrecision = 'p:short';
else
    strPrecision = 'p:double';
end

% Read the corresponding recordings
rec = openNSx('read', sFile.filename, 'channels', iChannels , 'sample', strSamples, strPrecision, 'uV');
if iscell(rec.Data)
    rec.Data = [rec.Data{:}];
end
if strcmp(precision, 'single')
    rec.Data = single(rec.Data);
end

% Get values and convert from uV to V
F = rec.Data * 1e-6;





