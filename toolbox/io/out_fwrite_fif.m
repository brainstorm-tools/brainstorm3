function out_fwrite_fif(sFile, sfid, iEpoch, SamplesBounds, iChannels, F)
% OUT_FWRITE_FIF: Write a block of data in a FIF file.
%
% USAGE:  out_fwrite_fif(sFile, sfid, iEpoch, SamplesBounds, iChannels, F);

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
% Authors: Francois Tadel, 2013-2014


% Epoched/continuous data
isEpoched = ~isfield(sFile.header, 'raw') || isempty(sFile.header.raw);
% Missing SampleBounds: use the entire raw file
if ~isempty(isEpoched) && isempty(SamplesBounds)
    SamplesBounds = [sFile.header.raw.first_samp, sFile.header.raw.last_samp];
end

% === CALIBRATION ===
% Build calibration matrix
if isEpoched
    Calibration = [sFile.header.info.chs.cal];
else
    Calibration = [sFile.header.info.chs.range] .* [sFile.header.info.chs.cal];
end
Calibration = Calibration(:);
% Revert calibration
if ~isempty(iChannels)
    F = bst_bsxfun(@rdivide, F, Calibration(iChannels));
else
    F = bst_bsxfun(@rdivide, F, Calibration);
end

% === WRITING ===
% Epoched data
if isEpoched
    error('Writing new epoched FIF files is not supported.');
% Raw continuous data
else
    fif_write_raw_segment(sFile, sfid, SamplesBounds, iChannels, F);
end




