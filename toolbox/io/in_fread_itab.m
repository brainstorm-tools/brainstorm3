function F = in_fread_itab(sFile, sfid, SamplesBounds, iChannels)
% IN_FREAD_ITAB:  Read a block of recordings from an ITAB raw MEG file.
%
% USAGE:  F = in_fread_itab(sFile, sfid, SamplesBounds=[all], iChannels=[all])

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


% ===== PARSE INPUTS =====
nChannels  = sFile.header.nchan;
if (nargin < 4) || isempty(iChannels)
    iChannels = [];
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% ===== READ DATA =====
% Get data type
switch (sFile.header.data_type)
    case {0,3}
        bytesPerVal = 2;
        dataClass = 'int16';
    case {1,4}
        bytesPerVal = 4;
        dataClass = 'int32';
    case {2,5}
        bytesPerVal = 4;
        dataClass = 'float';
end
% Compute offsets
offsetHeader = sFile.header.start_data;
offsetTime   = SamplesBounds(1) * nChannels * bytesPerVal;
offsetTotal  = offsetHeader + offsetTime;
% Seek for data to read
fseek(sfid, offsetTotal, 'bof');
% Read data
F = fread(sfid, [nChannels, SamplesBounds(2)-SamplesBounds(1)+1], dataClass);

% ===== APPLY CALIBRATION ====
% List of channels that were recorded
ChanSel = 1:sFile.header.nchan;
% Get calibration values
Calib = [sFile.header.ch(ChanSel).calib];
Calib(Calib == 0) = 1;
% Apply to recordings
F = bst_bsxfun(@rdivide, F, Calib');
    
% Select requested channels
if ~isempty(iChannels)
    F = F(iChannels,:);
end
    




