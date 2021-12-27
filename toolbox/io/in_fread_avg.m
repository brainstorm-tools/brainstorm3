function F = in_fread_avg(sFile, sfid, SamplesBounds)
% IN_FREAD_AVG:  Read an epoch from a Neuroscan .avg file (averaged file).
%
% USAGE:  F = in_fread_eeg(sFile, sfid, SamplesBounds) : Read selected times
%         F = in_fread_eeg(sFile, sfid)                : Read all file

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
% Author: Francois Tadel, 2009-2011

%% ===== PARSE INPUTS =====
if (nargin < 3)
    SamplesBounds = [];
end
nTime = sFile.header.data.pnts;
nChannels = sFile.header.data.nchannels;


%% ===== READ DATA =====
% Initialize data structure
F = zeros(nChannels, nTime);
% Position at the beginning of the data block
fseek(sfid, double(sFile.header.data.datapos), 'bof');
% Read averaged data [nChannels x nTime]
for i = 1:nChannels   
    % Read the channel data
    unused_header = fread(sfid, 5, 'char');
    F(i,:) = fread(sfid, nTime, 'float')';
end
% Keep only specific time indices
if ~isempty(SamplesBounds)
    iTimes = (SamplesBounds(1):SamplesBounds(2)) - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1;
    F = F(:,iTimes);
end
% Calibrate data
F = neuroscan_apply_calibration(F, sFile.header);



