function out_fwrite_brainamp(sFile, sfid, SamplesBounds, F)
% OUT_FWRITE_BRAINAMP: Write a block of recordings to a BrainVision file (.eeg)

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
% Authors: Francois Tadel, 2018

% Parse inputs
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Apply gains, if available
if isfield(sFile.header, 'chgain') && (length(sFile.header.chgain) == size(F,1))
    F = bst_bsxfun(@rdivide, F, sFile.header.chgain(:));
% Else: Convert from microVolts to Volts by default
else
    F = F ./ 1e-6;
end

% BINARY and MULTIPLEXED files
if (strcmpi(sFile.header.DataFormat, 'BINARY') && strcmpi(sFile.header.DataOrientation, 'MULTIPLEXED'))
    nChan = sFile.header.NumberOfChannels;
    % Get start and length of block to read
    offsetData = SamplesBounds(1) * nChan * sFile.header.bytesize;
    % Position file at the beginning of the data block
    fseek(sfid, offsetData, 'bof');
    % Read all values at once
    fwrite(sfid, F, sFile.header.byteformat);
else
    error('Only BINARY and MULTIPLEXED files are supported.');
end
