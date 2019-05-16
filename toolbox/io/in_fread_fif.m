function [F,TimeVector] = in_fread_fif(sFile, sfid, iEpoch, SamplesBounds, iChannels)
% IN_READ_FIF:  Read a block of recordings from a FIF file
%
% USAGE:  [F,TimeVector] = in_fread_fif(sFile, sfid, iEpoch, SamplesBounds, iChannels)
%         [F,TimeVector] = in_fread_fif(sFile, sfid, iEpoch, SamplesBounds)            : Read all the channels

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
% Authors: Francois Tadel, 2009-2014

if (nargin < 5)
    iChannels = [];
end

% Epoched data
% if isempty(SamplesBounds) || ~isfield(sFile.header, 'raw') || isempty(sFile.header.raw)
if ~isfield(sFile.header, 'raw') || isempty(sFile.header.raw)
    [F, TimeVector] = fif_read_evoked(sFile, sfid, iEpoch);
    % Specific selection of channels
    if ~isempty(iChannels)
        F = F(iChannels, :);
    end
    % Specific time selection
    if ~isempty(SamplesBounds)
        iTime = SamplesBounds - round(sFile.epochs(iEpoch).times(1) .* sFile.prop.sfreq) + 1;
        F = F(:, iTime(1):iTime(2));
        TimeVector = TimeVector(iTime(1):iTime(2));
    end
    % Calibration matrix
    Calibration = diag([sFile.header.info.chs.cal]);
% Raw data
else
    % If time not specified, read the entire file
    if isempty(SamplesBounds)
        SamplesBounds = [sFile.header.raw.first_samp, sFile.header.raw.last_samp];
    end
    % Read block of data
    [F, TimeVector] = fif_read_raw_segment(sFile, sfid, SamplesBounds, iChannels);
    % Calibration matrix
    Calibration = diag([sFile.header.info.chs.range] .* [sFile.header.info.chs.cal]);
end

% Apply calibration
if ~isempty(iChannels)
    F = Calibration(iChannels,iChannels) * F;
else
    F = Calibration * F;
end




