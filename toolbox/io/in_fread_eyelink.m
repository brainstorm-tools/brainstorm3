function [F, TimeVector] = in_fread_eyelink(sFile, iEpoch, SamplesBounds, iChannels)
% IN_FREAD_EYELINK:  Read a block of recordings from a EyeLink eye tracker file (.edf).
%
% USAGE:  [F, TimeVector] = in_fread_eyelink(sFile, iEpoch=1, SamplesBounds=[all], iChannels=[all])

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
% Authors: Francois Tadel, 2015

% Windows only
if ~ispc
    error('This format is only supported on Windows systems.');
end
% Parse inputs
if (nargin < 2) || isempty(iEpoch)
    iEpoch = 1;
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.epochs(iEpoch).times .* sFile.prop.sfreq);
end
if (nargin < 4) || isempty(iChannels)
    iChannels = 1:length(sFile.header.chnames);
    SampleFields = [];
else
    SampleFields = sprintf('%s ', sFile.header.chnames{iChannels});
    SampleFields(end) = [];
end

% Read data
Trials = edfImport(sFile.filename, [0 0 1], SampleFields);
% Selected times
Samples = round(double(Trials(iEpoch).Samples.time) ./ 1000 .* sFile.prop.sfreq);
iSamples = find((Samples <= SamplesBounds(2)) & (Samples >= SamplesBounds(1)));
% Initialize returned variable
F = zeros(length(iChannels), length(iSamples));
% Format data
for i = 1:length(iChannels)
    chname = sFile.header.chnames{i};
    % Channel #1
    if ~isempty(strfind(chname, '_l'))
        F(i,:) = double(Trials(iEpoch).Samples.(chname(1:end-2))(1,iSamples));
    % Channel #2
    elseif ~isempty(strfind(chname, '_r'))
        F(i,:) = double(Trials(iEpoch).Samples.(chname(1:end-2))(2,iSamples));
    % Only one channel available
    else
        F(i,:) = double(Trials(iEpoch).Samples.(chname)(1,iSamples));
    end
%     % Apply gain
%     F(i,:) = F(i,:) .* sFile.header.chgain(i);
end
% Return time vector
TimeVector = double(Trials(iEpoch).Samples.time(iSamples)) ./ 1000;

